import { useState } from 'react';
import { useStore } from '../app/store';

/** Connexion / création de compte pour la synchro multi-appareils (Google + e-mail). */
export function AuthPanel({ title }: { title?: string }) {
  const cloudUser = useStore((s) => s.cloudUser);
  const cloudAvailable = useStore((s) => s.cloudAvailable);
  const signInCloud = useStore((s) => s.signInCloud);
  const signUpEmail = useStore((s) => s.signUpEmail);
  const signInEmail = useStore((s) => s.signInEmail);
  const resetPassword = useStore((s) => s.resetPassword);
  const signOutCloud = useStore((s) => s.signOutCloud);

  const [mode, setMode] = useState<'signin' | 'signup'>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  if (cloudUser) {
    return (
      <div className="card" style={{ borderLeft: '3px solid var(--success)' }}>
        <div className="row between">
          <div>
            <div style={{ fontWeight: 600 }}>☁️ Connecté</div>
            <div className="tertiary small">{cloudUser.email ?? cloudUser.name ?? cloudUser.uid}</div>
          </div>
          <button className="btn ghost small" onClick={() => void signOutCloud()}>Se déconnecter</button>
        </div>
        <div className="tertiary small" style={{ marginTop: 8 }}>Tes données se synchronisent en temps réel sur tous tes appareils.</div>
      </div>
    );
  }

  if (!cloudAvailable) {
    return (
      <div className="card">
        <div className="tertiary small">Synchro multi-appareils bientôt disponible (configuration en cours).</div>
      </div>
    );
  }

  async function google() {
    setErr(null); setMsg(null); setBusy(true);
    try {
      await signInCloud();
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function submitEmail() {
    setErr(null); setMsg(null);
    if (!email.trim() || password.length < 6) {
      setErr('Renseigne un e-mail et un mot de passe (6 caractères min.).');
      return;
    }
    setBusy(true);
    try {
      if (mode === 'signup') await signUpEmail(email, password);
      else await signInEmail(email, password);
    } catch (e) {
      setErr((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function forgot() {
    setErr(null); setMsg(null);
    if (!email.trim()) { setErr('Saisis ton e-mail d\'abord.'); return; }
    try {
      await resetPassword(email);
      setMsg('E-mail de réinitialisation envoyé (vérifie tes spams).');
    } catch (e) {
      setErr((e as Error).message);
    }
  }

  return (
    <div className="card">
      {title && <div style={{ fontWeight: 600, marginBottom: 10 }}>{title}</div>}

      <button className="btn block" onClick={() => void google()} disabled={busy} style={{ marginBottom: 'var(--sp-sm)' }}>
        🔓 Continuer avec Google
      </button>

      <div className="row" style={{ gap: 8, alignItems: 'center', margin: 'var(--sp-sm) 0' }}>
        <div style={{ flex: 1, height: 1, background: 'var(--separator)' }} />
        <span className="tertiary small">ou par e-mail</span>
        <div style={{ flex: 1, height: 1, background: 'var(--separator)' }} />
      </div>

      <div className="seg" style={{ marginBottom: 'var(--sp-sm)' }}>
        <button className={mode === 'signin' ? 'active' : ''} onClick={() => { setMode('signin'); setErr(null); }}>Connexion</button>
        <button className={mode === 'signup' ? 'active' : ''} onClick={() => { setMode('signup'); setErr(null); }}>Créer un compte</button>
      </div>

      <div className="field"><label>E-mail</label><input className="input" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="toi@exemple.com" /></div>
      <div className="field"><label>Mot de passe</label><input className="input" type="password" autoComplete={mode === 'signup' ? 'new-password' : 'current-password'} value={password} onChange={(e) => setPassword(e.target.value)} placeholder="6 caractères min." /></div>

      <button className="btn primary block" onClick={() => void submitEmail()} disabled={busy}>
        {mode === 'signup' ? 'Créer mon compte' : 'Se connecter'}
      </button>

      {mode === 'signin' && (
        <button className="btn ghost small block" style={{ marginTop: 6 }} onClick={() => void forgot()}>Mot de passe oublié ?</button>
      )}

      {err && <div className="banner danger" style={{ marginTop: 10 }}>{err}</div>}
      {msg && <div className="banner success" style={{ marginTop: 10 }}>{msg}</div>}
    </div>
  );
}
