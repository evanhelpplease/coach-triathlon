import { useState } from 'react';
import {
  VDOT, CSS, vdotFromVMA, makeProfile, makeEquipment, makeAvailability, makeRace,
  SkillLevel, type BiologicalSex, type RaceFormat, type ProgressionLevel, type Discipline, type BikeType,
} from '@engine/index';
import { useStore } from '../app/store';
import { Card } from '../ui/components';
import { parseClock } from '../ui/format';
import { AuthPanel } from './AuthPanel';

interface Draft {
  birthDate: string;
  sex: BiologicalSex;
  heightCm: string;
  weightKg: string;
  hrMax: string;
  hrRest: string;
  swimLevel: SkillLevel;
  bikeLevel: SkillLevel;
  runLevel: SkillLevel;
  run5kMin: string; // temps 5 km "mm:ss" → VDOT
  vma: string; // VMA km/h (test 6 min) → VDOT
  ftp: string;
  css400: string; // "mm:ss"
  css200: string;
  hasBike: boolean;
  bikeType: BikeType;
  hasAeroBars: boolean;
  poolAccess: boolean;
  hasWetsuit: boolean;
  raceTitle: string;
  raceDate: string;
  raceFormat: RaceFormat;
  raceGoal: string;
  progression: ProgressionLevel;
}

function parseMMSS(s: string): number | null {
  const m = s.match(/^(\d+):(\d{1,2})$/);
  if (!m) { const n = parseFloat(s); return Number.isFinite(n) ? n : null; }
  return parseInt(m[1]) * 60 + parseInt(m[2]);
}

const initial: Draft = {
  birthDate: '1995-01-01', sex: 'male', heightCm: '178', weightKg: '72', hrMax: '', hrRest: '',
  swimLevel: SkillLevel.novice, bikeLevel: SkillLevel.intermediate, runLevel: SkillLevel.intermediate,
  run5kMin: '', vma: '', ftp: '', css400: '', css200: '',
  hasBike: true, bikeType: 'road', hasAeroBars: false, poolAccess: true, hasWetsuit: false,
  raceTitle: '', raceDate: '', raceFormat: 'olympic', raceGoal: '', progression: 'balanced',
};

const STEPS = ['Bienvenue', 'Physique', 'Niveaux & référentiels', 'Matériel', 'Objectif', 'Progression'];
const LEVELS: { v: SkillLevel; l: string }[] = [
  { v: SkillLevel.beginner, l: 'Débutant' }, { v: SkillLevel.novice, l: 'Novice' },
  { v: SkillLevel.intermediate, l: 'Intermédiaire' }, { v: SkillLevel.advanced, l: 'Avancé' }, { v: SkillLevel.expert, l: 'Expert' },
];

export function Onboarding() {
  const [step, setStep] = useState(0);
  const [d, setD] = useState<Draft>(initial);
  const completeOnboarding = useStore((s) => s.completeOnboarding);
  const cloudAvailable = useStore((s) => s.cloudAvailable);
  const cloudUser = useStore((s) => s.cloudUser);
  const signOutCloud = useStore((s) => s.signOutCloud);
  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((prev) => ({ ...prev, [k]: v }));

  function finish() {
    const vma = d.vma ? (parseFloat(d.vma.replace(',', '.')) || undefined) : undefined;
    const vdotFrom5k = d.run5kMin ? (() => { const t = parseMMSS(d.run5kMin); return t ? VDOT.vdot(5000, t) : undefined; })() : undefined;
    const vdot = vma != null ? vdotFromVMA(vma) : vdotFrom5k;
    const css = d.css400 && d.css200 ? (() => {
      const t4 = parseMMSS(d.css400), t2 = parseMMSS(d.css200);
      return t4 && t2 && t4 > t2 ? CSS.pacePer100m(400, t4, 200, t2) : undefined;
    })() : undefined;

    const levels: Partial<Record<Discipline, SkillLevel>> = { swim: d.swimLevel, bike: d.bikeLevel, run: d.runLevel };
    const profile = makeProfile({
      birthDate: new Date(d.birthDate + 'T12:00:00Z'),
      sex: d.sex,
      heightCm: parseFloat(d.heightCm) || 178,
      weightKg: parseFloat(d.weightKg) || 72,
      hrMax: parseInt(d.hrMax) || undefined,
      hrRest: parseInt(d.hrRest) || undefined,
      ftpWatts: parseInt(d.ftp) || undefined,
      cssSecPer100m: css,
      vdot,
      vma,
      levels,
    });
    const equipment = makeEquipment({
      hasBike: d.hasBike, bikeType: d.bikeType, hasAeroBars: d.hasAeroBars,
      poolAccess: d.poolAccess, hasWetsuit: d.hasWetsuit, runOutdoor: true, strengthAccess: 'bodyweightOnly',
    });
    const races = d.raceTitle && d.raceDate
      ? [makeRace({ title: d.raceTitle, date: new Date(d.raceDate + 'T09:00:00'), format: d.raceFormat, priority: 'a', goalTimeSeconds: parseClock(d.raceGoal) ?? undefined })]
      : [];
    completeOnboarding({ profile, equipment, races, availability: makeAvailability({ maxSessionsPerWeek: 6 }), progression: d.progression });
  }

  return (
    <div className="screen" style={{ paddingBottom: 'var(--sp-lg)' }}>
      <div className="row between" style={{ marginBottom: 'var(--sp-md)' }}>
        <h1 style={{ fontSize: '1.4rem' }}>{STEPS[step]}</h1>
        <span className="tertiary small">{step + 1}/{STEPS.length}</span>
      </div>

      {step === 0 && (
        <>
          <Card>
            <h2 style={{ fontSize: '1.2rem', marginBottom: 8 }}>Coach Triathlon IA 🏊🚴🏃</h2>
            <p className="muted small">Un coach adaptatif : plan périodisé vers ta course, ajusté chaque jour selon ta forme, ton matériel et tes blessures. Français, métrique.</p>
          </Card>

          {cloudAvailable && !cloudUser && (
            <>
              <div className="section-title" style={{ marginTop: 'var(--sp-lg)' }}>Connecte-toi ou crée ton compte</div>
              <AuthPanel />
              <div className="tertiary small" style={{ marginTop: 'var(--sp-xs)', textAlign: 'center' }}>
                Ton plan te suit sur tous tes appareils (téléphone + ordinateur).
              </div>
            </>
          )}

          {(cloudUser || !cloudAvailable) && (
            <Card style={{ marginTop: 'var(--sp-md)' }}>
              {cloudUser && (
                <div className="row between" style={{ marginBottom: 10 }}>
                  <div className="tertiary small">Connecté : {cloudUser.email ?? cloudUser.name}</div>
                  <button className="btn ghost small" onClick={() => void signOutCloud()}>Changer de compte</button>
                </div>
              )}
              <div className="muted small" style={{ marginBottom: 10 }}>Créons ton profil pour générer ton plan sur mesure.</div>
              <button className="btn primary block" onClick={() => setStep(1)}>Créer mon profil</button>
            </Card>
          )}
        </>
      )}

      {step === 1 && (
        <Card>
          <div className="field"><label>Date de naissance</label><input className="input" type="date" value={d.birthDate} onChange={(e) => set('birthDate', e.target.value)} /></div>
          <div className="field"><label>Sexe</label>
            <div className="seg">
              {(['male', 'female', 'other'] as BiologicalSex[]).map((s) => (
                <button key={s} className={d.sex === s ? 'active' : ''} onClick={() => set('sex', s)}>{s === 'male' ? 'Homme' : s === 'female' ? 'Femme' : 'Autre'}</button>
              ))}
            </div>
          </div>
          <div className="row">
            <div className="field grow"><label>Taille (cm)</label><input className="input" inputMode="numeric" value={d.heightCm} onChange={(e) => set('heightCm', e.target.value)} /></div>
            <div className="field grow"><label>Poids (kg)</label><input className="input" inputMode="decimal" value={d.weightKg} onChange={(e) => set('weightKg', e.target.value)} /></div>
          </div>
          <div className="row">
            <div className="field grow"><label>FC max (option.)</label><input className="input" inputMode="numeric" value={d.hrMax} onChange={(e) => set('hrMax', e.target.value)} /></div>
            <div className="field grow"><label>FC repos (option.)</label><input className="input" inputMode="numeric" value={d.hrRest} onChange={(e) => set('hrRest', e.target.value)} /></div>
          </div>
        </Card>
      )}

      {step === 2 && (
        <Card>
          {([['swim', 'Natation', d.swimLevel, 'swimLevel'], ['bike', 'Vélo', d.bikeLevel, 'bikeLevel'], ['run', 'Course', d.runLevel, 'runLevel']] as const).map(([, label, val, key]) => (
            <div className="field" key={key}>
              <label>{label}</label>
              <select className="select" value={val} onChange={(e) => set(key, parseInt(e.target.value) as SkillLevel)}>
                {LEVELS.map((l) => <option key={l.v} value={l.v}>{l.l}</option>)}
              </select>
            </div>
          ))}
          <div className="tertiary small" style={{ margin: '8px 0' }}>Référentiels (laisse vide si inconnu → un test de terrain sera planifié).</div>
          <div className="row">
            <div className="field grow"><label>VMA (km/h, test 6 min)</label><input className="input" inputMode="decimal" placeholder="16.5" value={d.vma} onChange={(e) => set('vma', e.target.value)} /></div>
            <div className="field grow"><label>ou chrono 5 km (mm:ss)</label><input className="input" placeholder="22:30" value={d.run5kMin} onChange={(e) => set('run5kMin', e.target.value)} /></div>
          </div>
          <div className="field"><label>FTP vélo (W)</label><input className="input" inputMode="numeric" placeholder="240" value={d.ftp} onChange={(e) => set('ftp', e.target.value)} /></div>
          <div className="row">
            <div className="field grow"><label>400 m nat (mm:ss)</label><input className="input" placeholder="6:20" value={d.css400} onChange={(e) => set('css400', e.target.value)} /></div>
            <div className="field grow"><label>200 m nat (mm:ss)</label><input className="input" placeholder="3:00" value={d.css200} onChange={(e) => set('css200', e.target.value)} /></div>
          </div>
        </Card>
      )}

      {step === 3 && (
        <Card>
          <label className="row between" style={{ padding: '8px 0' }}><span>Vélo</span><input type="checkbox" checked={d.hasBike} onChange={(e) => set('hasBike', e.target.checked)} /></label>
          {d.hasBike && (
            <div className="field"><label>Type de vélo</label>
              <select className="select" value={d.bikeType} onChange={(e) => set('bikeType', e.target.value as BikeType)}>
                <option value="road">Route</option><option value="tt">Contre-la-montre</option><option value="gravel">Gravel</option><option value="mtb">VTT</option>
              </select>
            </div>
          )}
          <label className="row between" style={{ padding: '8px 0' }}><span>Prolongateurs (aéro)</span><input type="checkbox" checked={d.hasAeroBars} onChange={(e) => set('hasAeroBars', e.target.checked)} /></label>
          <label className="row between" style={{ padding: '8px 0' }}><span>Accès piscine</span><input type="checkbox" checked={d.poolAccess} onChange={(e) => set('poolAccess', e.target.checked)} /></label>
          <label className="row between" style={{ padding: '8px 0' }}><span>Combinaison néoprène</span><input type="checkbox" checked={d.hasWetsuit} onChange={(e) => set('hasWetsuit', e.target.checked)} /></label>
        </Card>
      )}

      {step === 4 && (
        <Card>
          <div className="field"><label>Nom de la course cible</label><input className="input" value={d.raceTitle} onChange={(e) => set('raceTitle', e.target.value)} placeholder="Triathlon de…" /></div>
          <div className="field"><label>Date</label><input className="input" type="date" value={d.raceDate} onChange={(e) => set('raceDate', e.target.value)} /></div>
          <div className="row">
            <div className="field grow"><label>Format</label>
              <select className="select" value={d.raceFormat} onChange={(e) => set('raceFormat', e.target.value as RaceFormat)}>
                <option value="xs">XS</option><option value="sprint">Sprint</option><option value="olympic">Olympique (M)</option><option value="half">Half 70.3</option><option value="full">Full 140.6</option>
                <option value="run10k">10 km</option><option value="halfMarathon">Semi</option><option value="marathon">Marathon</option>
              </select>
            </div>
            <div className="field grow"><label>Objectif (h:mm:ss)</label><input className="input" value={d.raceGoal} onChange={(e) => set('raceGoal', e.target.value)} placeholder="2:15:00" /></div>
          </div>
          <div className="tertiary small">L'objectif de temps pilote l'ambition du plan. Tu pourras ajouter d'autres courses ensuite.</div>
        </Card>
      )}

      {step === 5 && (
        <Card>
          <div className="stack-sm">
            {([['prudent', 'Prudent', 'Montée douce, sécurité maximale.'], ['balanced', 'Équilibré', 'Compromis progrès / sécurité.'], ['performance', 'Performance', 'Montée rapide, plus exigeant.']] as const).map(([v, l, desc]) => (
              <button key={v} className="session" onClick={() => set('progression', v)} style={{ borderColor: d.progression === v ? 'var(--primary)' : undefined }}>
                <div className="grow"><div className="title">{l}</div><div className="sub">{desc}</div></div>
                {d.progression === v && <span style={{ color: 'var(--primary)' }}>✓</span>}
              </button>
            ))}
          </div>
        </Card>
      )}

      {step > 0 && (
        <div className="row between" style={{ marginTop: 'var(--sp-lg)' }}>
          <button className="btn ghost" onClick={() => setStep(step - 1)}>← Précédent</button>
          {step < STEPS.length - 1 ? (
            <button className="btn primary" onClick={() => setStep(step + 1)}>Suivant →</button>
          ) : (
            <button className="btn accent" onClick={finish}>C'est parti 🚀</button>
          )}
        </div>
      )}
    </div>
  );
}
