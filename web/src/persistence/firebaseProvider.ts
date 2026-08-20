// FirebaseProvider : persistance cloud multi-appareils (Auth Google + Firestore).
// Chargé dynamiquement (import()) pour ne pas alourdir le bundle initial ni
// charger Firebase quand la synchro cloud n'est pas utilisée.
import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import {
  getAuth, GoogleAuthProvider, signInWithPopup, signOut, onAuthStateChanged,
  createUserWithEmailAndPassword, signInWithEmailAndPassword, sendPasswordResetEmail,
  type Auth, type User,
} from 'firebase/auth';
import { getFirestore, doc, getDoc, setDoc, onSnapshot, type Firestore, type DocumentReference } from 'firebase/firestore';
import type { AppData } from '../app/model';
import { deserializeAppData, serializeAppData } from '../app/serialization';
import type { SyncProvider } from './syncProvider';
import { firebaseConfig } from './firebaseConfig';

export interface CloudUser {
  uid: string;
  email: string | null;
  name: string | null;
}

let app: FirebaseApp | null = null;
let auth: Auth | null = null;
let db: Firestore | null = null;

function ensureInit(): { auth: Auth; db: Firestore } {
  const cfg = firebaseConfig();
  if (!cfg) throw new Error('Firebase non configuré (variables VITE_FIREBASE_*).');
  if (!app) {
    app = getApps().length ? getApp() : initializeApp(cfg);
    auth = getAuth(app);
    db = getFirestore(app);
  }
  return { auth: auth!, db: db! };
}

/** Provider Firestore pour un utilisateur donné : un document users/{uid}. */
export class FirebaseProvider implements SyncProvider {
  readonly id = 'firebase';
  readonly displayName = 'Firebase (cloud)';
  private ref: DocumentReference;
  /** Dernier JSON écrit, pour ignorer les échos de nos propres écritures. */
  private lastJson = '';

  constructor(db: Firestore, uid: string) {
    this.ref = doc(db, 'users', uid);
  }

  async load(): Promise<AppData | null> {
    const snap = await getDoc(this.ref);
    if (!snap.exists()) return null;
    const json = (snap.data() as { json?: string }).json;
    if (!json) return null;
    this.lastJson = json;
    return deserializeAppData(json);
  }

  async save(data: AppData): Promise<void> {
    const json = serializeAppData(data);
    this.lastJson = json;
    await setDoc(this.ref, { json, updatedAt: Date.now() });
  }

  subscribe(onChange: (data: AppData) => void): () => void {
    return onSnapshot(this.ref, (snap) => {
      if (!snap.exists()) return;
      const json = (snap.data() as { json?: string }).json;
      if (!json || json === this.lastJson) return; // ignore nos propres écritures
      this.lastJson = json;
      try {
        onChange(deserializeAppData(json));
      } catch {
        /* données distantes illisibles */
      }
    });
  }
}

/** Connexion Google (popup) → renvoie le provider cloud prêt + l'utilisateur. */
export async function signInWithGoogle(): Promise<{ provider: FirebaseProvider; user: CloudUser; db: Firestore }> {
  const { auth, db } = ensureInit();
  let cred;
  try {
    cred = await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
  const u = cred.user;
  return {
    provider: new FirebaseProvider(db, u.uid),
    user: { uid: u.uid, email: u.email, name: u.displayName },
    db,
  };
}

export async function signOutFirebase(): Promise<void> {
  if (auth) await signOut(auth);
}

/** Message d'erreur d'authentification en français. */
function authErrorMessage(e: unknown): string {
  const code = (e as { code?: string })?.code ?? '';
  switch (code) {
    case 'auth/email-already-in-use': return 'Un compte existe déjà avec cet e-mail — connecte-toi.';
    case 'auth/invalid-email': return 'Adresse e-mail invalide.';
    case 'auth/weak-password': return 'Mot de passe trop faible (6 caractères minimum).';
    case 'auth/wrong-password':
    case 'auth/invalid-credential': return 'E-mail ou mot de passe incorrect.';
    case 'auth/user-not-found': return 'Aucun compte pour cet e-mail.';
    case 'auth/too-many-requests': return 'Trop de tentatives, réessaie dans un moment.';
    case 'auth/popup-closed-by-user': return 'Fenêtre fermée avant la fin.';
    case 'auth/operation-not-allowed': return 'Ce mode de connexion n\'est pas activé dans Firebase.';
    default: return 'Échec de la connexion. Réessaie.';
  }
}

/** Crée un compte e-mail/mot de passe (l'observeAuth branche ensuite la synchro). */
export async function signUpEmail(email: string, password: string): Promise<void> {
  const { auth } = ensureInit();
  try {
    await createUserWithEmailAndPassword(auth, email.trim(), password);
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

/** Connexion e-mail/mot de passe. */
export async function signInEmail(email: string, password: string): Promise<void> {
  const { auth } = ensureInit();
  try {
    await signInWithEmailAndPassword(auth, email.trim(), password);
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

/** Envoi d'un e-mail de réinitialisation du mot de passe. */
export async function resetPassword(email: string): Promise<void> {
  const { auth } = ensureInit();
  try {
    await sendPasswordResetEmail(auth, email.trim());
  } catch (e) {
    throw new Error(authErrorMessage(e));
  }
}

/** Observe l'état d'auth (reconnexion silencieuse au rechargement). */
export function observeAuth(cb: (r: { provider: FirebaseProvider; user: CloudUser } | null) => void): () => void {
  const { auth, db } = ensureInit();
  return onAuthStateChanged(auth, (u: User | null) => {
    if (!u) return cb(null);
    cb({ provider: new FirebaseProvider(db, u.uid), user: { uid: u.uid, email: u.email, name: u.displayName } });
  });
}
