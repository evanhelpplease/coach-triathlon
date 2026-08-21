import { useEffect } from 'react';
import { HashRouter, Routes, Route, NavLink, Navigate } from 'react-router-dom';
import { useStore } from './app/store';
import { Cockpit } from './screens/Cockpit';
import { PlanScreen } from './screens/PlanScreen';
import { SessionDetail } from './screens/SessionDetail';
import { RaceDay } from './screens/RaceDay';
import { Journal } from './screens/Journal';
import { Analysis } from './screens/Analysis';
import { Predictions } from './screens/Predictions';
import { ZonesScreen } from './screens/ZonesScreen';
import { Races } from './screens/Races';
import { Injuries } from './screens/Injuries';
import { Settings } from './screens/Settings';
import { Onboarding } from './screens/Onboarding';

const TABS = [
  { to: '/', ico: '🏠', label: 'Cockpit', end: true },
  { to: '/plan', ico: '📅', label: 'Plan', end: false },
  { to: '/journal', ico: '✍️', label: 'Journal', end: false },
  { to: '/analysis', ico: '📊', label: 'Analyse', end: false },
  { to: '/settings', ico: '⚙️', label: 'Réglages', end: false },
];

function BottomNav() {
  return (
    <nav className="bottom-nav">
      {TABS.map((t) => (
        <NavLink key={t.to} to={t.to} end={t.end} className={({ isActive }) => `tab ${isActive ? 'active' : ''}`}>
          <span className="ico">{t.ico}</span>
          <span>{t.label}</span>
        </NavLink>
      ))}
    </nav>
  );
}

export function App() {
  const hydrated = useStore((s) => s.hydrated);
  const onboardingComplete = useStore((s) => s.data.onboardingComplete);
  const hydrate = useStore((s) => s.hydrate);

  useEffect(() => {
    void hydrate();
  }, [hydrate]);

  if (!hydrated) {
    return (
      <div className="app">
        <div className="screen" style={{ display: 'grid', placeItems: 'center' }}>
          <div className="muted">Chargement…</div>
        </div>
      </div>
    );
  }

  if (!onboardingComplete) {
    return (
      <div className="app">
        <Onboarding />
      </div>
    );
  }

  return (
    <HashRouter>
      <div className="app">
        <Routes>
          <Route path="/" element={<Cockpit />} />
          <Route path="/plan" element={<PlanScreen />} />
          <Route path="/session/:id" element={<SessionDetail />} />
          <Route path="/race/:id" element={<RaceDay />} />
          <Route path="/journal" element={<Journal />} />
          <Route path="/analysis" element={<Analysis />} />
          <Route path="/predictions" element={<Predictions />} />
          <Route path="/zones" element={<ZonesScreen />} />
          <Route path="/races" element={<Races />} />
          <Route path="/injuries" element={<Injuries />} />
          <Route path="/settings" element={<Settings />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
        <BottomNav />
      </div>
    </HashRouter>
  );
}
