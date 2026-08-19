// Configuration Firebase (config web publique — sans danger côté client).
// Renseignée via variables d'env Vite au build (voir web/README.md).
// Si absente, la synchro cloud est simplement désactivée (fallback local).

export interface FirebaseWebConfig {
  apiKey: string;
  authDomain: string;
  projectId: string;
  appId: string;
  storageBucket?: string;
  messagingSenderId?: string;
}

const env = import.meta.env;

export function firebaseConfig(): FirebaseWebConfig | null {
  const apiKey = env.VITE_FIREBASE_API_KEY;
  const projectId = env.VITE_FIREBASE_PROJECT_ID;
  const appId = env.VITE_FIREBASE_APP_ID;
  if (!apiKey || !projectId || !appId) return null;
  return {
    apiKey,
    authDomain: env.VITE_FIREBASE_AUTH_DOMAIN ?? `${projectId}.firebaseapp.com`,
    projectId,
    appId,
    storageBucket: env.VITE_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  };
}

export function isFirebaseConfigured(): boolean {
  return firebaseConfig() !== null;
}
