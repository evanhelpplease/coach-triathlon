import { useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  isTestSession, vdotFromVMATest, vmaFromTest, ftpFrom20minTest, cssFromTest,
  type PlannedSession, type Sport, type StepTarget, type WorkoutStep, type CompletedActivity,
} from '@engine/index';
import { useStore, type ActualSession } from '../app/store';
import { downloadFitWorkout } from '../services/fitWorkout';
import { adaptedPlan } from '../app/derive';
import { Card, SectionTitle, Pill, Banner } from '../ui/components';
import { hms, intentLabel, mmss, sportColor, sportEmoji, sportLabel } from '../ui/format';

function fmtTarget(t: StepTarget): string {
  switch (t.kind) {
    case 'hrZone': return `Zone FC ${t.zone}`;
    case 'paceRange': return `${mmss(t.lowSecPerKm)}–${mmss(t.highSecPerKm)}/km`;
    case 'swimPaceRange': return `${mmss(t.lowSecPer100m)}–${mmss(t.highSecPer100m)}/100m`;
    case 'powerRange': return `${Math.round(t.lowW)}–${Math.round(t.highW)} W`;
    case 'rpe': return `RPE ${t.value}/10`;
    case 'free': return 'Allure libre';
  }
}

function fmtDuration(step: WorkoutStep): string {
  const d = step.duration;
  if (d.kind === 'time') return `${Math.round(d.seconds / 60)} min`;
  if (d.kind === 'lengths') return `${d.count} × ${d.poolMeters} m`;
  return `${(d.meters / 1000).toFixed(1)} km`;
}

const KIND_LABEL: Record<string, string> = {
  warmup: 'Échauffement', work: 'Effort', recovery: 'Récup', rest: 'Repos', cooldown: 'Retour au calme', repeatBlock: 'Bloc',
};

function StepView({ step }: { step: WorkoutStep }) {
  if (step.kind === 'repeatBlock' && step.children) {
    return (
      <Card style={{ borderLeft: '3px solid var(--primary)' }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>{step.repeats ?? 1} × répétitions</div>
        <div className="stack-sm">
          {step.children.map((c, i) => (
            <div key={i} className="row between small">
              <span>{KIND_LABEL[c.kind] ?? c.kind} · {fmtDuration(c)}</span>
              <span className="muted">{fmtTarget(c.target)}</span>
            </div>
          ))}
        </div>
        {step.children[0]?.cue && <div className="tertiary small" style={{ marginTop: 6 }}>{step.children[0].cue}</div>}
      </Card>
    );
  }
  return (
    <Card>
      <div className="row between">
        <span style={{ fontWeight: 600 }}>{KIND_LABEL[step.kind] ?? step.kind}</span>
        <Pill>{fmtDuration(step)}</Pill>
      </div>
      <div className="row between small" style={{ marginTop: 6 }}>
        <span className="muted">{fmtTarget(step.target)}</span>
      </div>
      {step.cue && <div className="tertiary small" style={{ marginTop: 6 }}>{step.cue}</div>}
    </Card>
  );
}

function exportZwo(s: PlannedSession) {
  // Export minimal Zwift (.zwo) : chaque pas temporel → SteadyState à un %FTP indicatif.
  const ifByKind = (step: WorkoutStep): number => {
    if (step.target.kind === 'powerRange') return 0.7; // remplacé ci-dessous
    return 0.6;
  };
  const segs: string[] = [];
  const push = (step: WorkoutStep) => {
    if (step.duration.kind !== 'time') return;
    const p = step.target.kind === 'powerRange' ? Math.round(((step.target.lowW + step.target.highW) / 2)) : null;
    const power = p ? (p / (2.5 * 100)) : ifByKind(step); // approximation si pas de FTP
    segs.push(`    <SteadyState Duration="${Math.round(step.duration.seconds)}" Power="${power.toFixed(2)}"/>`);
  };
  for (const st of s.steps) {
    if (st.kind === 'repeatBlock' && st.children) {
      for (let i = 0; i < (st.repeats ?? 1); i++) st.children.forEach(push);
    } else push(st);
  }
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<workout_file>
  <author>Coach Triathlon IA</author>
  <name>${s.title}</name>
  <description>${intentLabel(s.intent)}</description>
  <sportType>bike</sportType>
  <workout>
${segs.join('\n')}
  </workout>
</workout_file>`;
  const blob = new Blob([xml], { type: 'application/xml' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${s.title.replace(/[^\w]+/g, '_')}.zwo`;
  a.click();
  URL.revokeObjectURL(url);
}

function TestResultForm({ sport }: { sport: Sport }) {
  const nav = useNavigate();
  const recalibrate = useStore((s) => s.recalibrate);
  const [distance, setDistance] = useState('1500'); // run : m sur 6 min
  const [power, setPower] = useState('220'); // bike : W moyens 20 min
  const [t400, setT400] = useState('6:30'); // swim
  const [t200, setT200] = useState('3:05');

  const mmssToSec = (s: string): number => {
    const m = s.match(/^(\d+):(\d{1,2})$/);
    return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : parseFloat(s) || 0;
  };

  let resultLabel = '';
  let resultValue = '';
  let apply: () => void = () => {};
  if (sport === 'run') {
    const d = parseFloat(distance) || 0;
    const vma = vmaFromTest(d);
    const vdot = vdotFromVMATest(d);
    resultLabel = 'VMA / VDOT';
    resultValue = `${vma.toFixed(1)} km/h · VDOT ~${vdot.toFixed(0)}`;
    apply = () => recalibrate({ vma, vdot });
  } else if (sport === 'bike') {
    const p = parseInt(power) || 0;
    const ftp = ftpFrom20minTest(p);
    resultLabel = 'FTP estimée';
    resultValue = `${ftp} W`;
    apply = () => recalibrate({ ftpWatts: ftp });
  } else {
    const css = cssFromTest(mmssToSec(t400), mmssToSec(t200));
    resultLabel = 'CSS';
    resultValue = Number.isFinite(css) && css > 0 ? `${mmss(css)}/100m` : '—';
    apply = () => { if (Number.isFinite(css) && css > 0) recalibrate({ cssSecPer100m: css }); };
  }

  return (
    <Card style={{ borderLeft: '3px solid var(--accent)' }}>
      <div style={{ fontWeight: 600, marginBottom: 8 }}>📋 Saisir le résultat du test</div>
      {sport === 'run' && (
        <div className="field"><label>Distance parcourue en 6 min (m)</label>
          <input className="input" inputMode="numeric" value={distance} onChange={(e) => setDistance(e.target.value)} />
        </div>
      )}
      {sport === 'bike' && (
        <div className="field"><label>Puissance moyenne sur 20 min (W)</label>
          <input className="input" inputMode="numeric" value={power} onChange={(e) => setPower(e.target.value)} />
        </div>
      )}
      {sport === 'swim' && (
        <div className="row">
          <div className="field grow"><label>Temps 400 m (mm:ss)</label><input className="input" value={t400} onChange={(e) => setT400(e.target.value)} /></div>
          <div className="field grow"><label>Temps 200 m (mm:ss)</label><input className="input" value={t200} onChange={(e) => setT200(e.target.value)} /></div>
        </div>
      )}
      <div className="row between" style={{ margin: '8px 0' }}>
        <span className="muted">{resultLabel}</span>
        <span className="num" style={{ color: 'var(--accent)' }}>{resultValue}</span>
      </div>
      <button className="btn accent block" onClick={() => { apply(); nav('/plan'); }}>Recalibrer zones & plan</button>
      <div className="tertiary small" style={{ marginTop: 8 }}>Ton référentiel est mis à jour, les zones et le plan régénérés, et ce test disparaît.</div>
    </Card>
  );
}

// Cible principale « travail » de la séance (pour la comparaison réalisé/prévu).
function mainRangeTarget(session: PlannedSession): StepTarget | null {
  for (const st of session.steps) {
    const cands = st.kind === 'repeatBlock' && st.children ? st.children : [st];
    for (const c of cands) {
      if (c.kind === 'work' && (c.target.kind === 'paceRange' || c.target.kind === 'powerRange' || c.target.kind === 'swimPaceRange')) return c.target;
    }
  }
  return null;
}

interface TargetCompare { label: string; target: string; actual: string; verdict: 'in' | 'over' | 'under'; }
function compareVsTarget(session: PlannedSession, a: CompletedActivity): TargetCompare | null {
  const t = mainRangeTarget(session);
  if (!t) return null;
  if (t.kind === 'paceRange' && a.avgPaceSecPerKm) {
    const v = a.avgPaceSecPerKm < t.lowSecPerKm ? 'over' : a.avgPaceSecPerKm > t.highSecPerKm ? 'under' : 'in';
    return { label: 'Allure', target: `${mmss(t.lowSecPerKm)}–${mmss(t.highSecPerKm)}/km`, actual: `${mmss(a.avgPaceSecPerKm)}/km`, verdict: v };
  }
  if (t.kind === 'powerRange') {
    const p = a.normalizedPowerW ?? a.avgPowerW;
    if (p == null) return null;
    const v = p > t.highW ? 'over' : p < t.lowW ? 'under' : 'in';
    return { label: 'Puissance', target: `${Math.round(t.lowW)}–${Math.round(t.highW)} W`, actual: `${p} W`, verdict: v };
  }
  if (t.kind === 'swimPaceRange' && a.distanceM && a.duration > 0) {
    const pace = 100 / (a.distanceM / a.duration);
    const v = pace < t.lowSecPer100m ? 'over' : pace > t.highSecPer100m ? 'under' : 'in';
    return { label: 'Allure', target: `${mmss(t.lowSecPer100m)}–${mmss(t.highSecPer100m)}/100m`, actual: `${mmss(pace)}/100m`, verdict: v };
  }
  return null;
}

function toNum(v: string): number | undefined {
  const n = parseFloat(v.replace(',', '.'));
  return Number.isFinite(n) ? n : undefined;
}

/** Saisie des données réelles à la fin d'une séance (prérempli avec le prévu). */
function CompletionForm({ session, onDone }: { session: PlannedSession; onDone: () => void }) {
  const completeSession = useStore((s) => s.completeSession);
  const poolMeters = useStore((s) => s.data.settings.poolMeters);
  const existing = useStore((s) => s.data.activities.find((a) => a.id === `done-${session.id}`));
  const sport = session.sport;

  const [durationMin, setDurationMin] = useState(String(Math.round((existing?.duration ?? session.estimatedDuration) / 60)));
  const [distanceKm, setDistanceKm] = useState(existing?.distanceM ? String(Math.round(existing.distanceM / 100) / 10) : '');
  const [lengths, setLengths] = useState(existing?.poolLengths ? String(existing.poolLengths) : '');
  const [avgHr, setAvgHr] = useState(existing?.avgHr ? String(existing.avgHr) : '');
  const [power, setPower] = useState(existing?.normalizedPowerW ?? existing?.avgPowerW ? String(existing?.normalizedPowerW ?? existing?.avgPowerW) : '');
  const [rpe, setRpe] = useState(String(existing?.rpe ?? 6));

  function save() {
    const dur = (toNum(durationMin) ?? Math.round(session.estimatedDuration / 60)) * 60;
    let distanceM: number | undefined;
    if (sport === 'swim') distanceM = toNum(lengths) != null ? toNum(lengths)! * poolMeters : undefined;
    else if (sport === 'run' || sport === 'bike') distanceM = toNum(distanceKm) != null ? toNum(distanceKm)! * 1000 : undefined;

    const actual: ActualSession = {
      duration: dur,
      distanceM,
      avgHr: toNum(avgHr),
      avgPowerW: sport === 'bike' ? toNum(power) : undefined,
      normalizedPowerW: sport === 'bike' ? toNum(power) : undefined,
      avgPaceSecPerKm: sport === 'run' && distanceM ? dur / (distanceM / 1000) : undefined,
      poolLengths: sport === 'swim' ? toNum(lengths) : undefined,
      rpe: toNum(rpe),
    };
    completeSession(session, actual);
    onDone();
  }

  return (
    <Card style={{ borderLeft: '3px solid var(--accent)' }}>
      <div style={{ fontWeight: 600, marginBottom: 8 }}>Comment s'est passée la séance ?</div>
      <div className="row">
        <div className="field grow"><label>Durée (min)</label><input className="input" inputMode="numeric" value={durationMin} onChange={(e) => setDurationMin(e.target.value)} /></div>
        {(sport === 'run' || sport === 'bike') && <div className="field grow"><label>Distance (km)</label><input className="input" inputMode="decimal" value={distanceKm} onChange={(e) => setDistanceKm(e.target.value)} /></div>}
        {sport === 'swim' && <div className="field grow"><label>Longueurs</label><input className="input" inputMode="numeric" value={lengths} onChange={(e) => setLengths(e.target.value)} /></div>}
      </div>
      <div className="row">
        <div className="field grow"><label>FC moy (bpm)</label><input className="input" inputMode="numeric" value={avgHr} onChange={(e) => setAvgHr(e.target.value)} /></div>
        {sport === 'bike' && <div className="field grow"><label>Puissance moy (W)</label><input className="input" inputMode="numeric" value={power} onChange={(e) => setPower(e.target.value)} /></div>}
        <div className="field grow"><label>RPE (1–10)</label><input className="input" inputMode="numeric" value={rpe} onChange={(e) => setRpe(e.target.value)} /></div>
      </div>
      <div className="row wrap">
        <button className="btn accent" onClick={save}>Valider</button>
        <button className="btn ghost" onClick={onDone}>Annuler</button>
      </div>
      <div className="tertiary small" style={{ marginTop: 8 }}>Ces données alimentent ta charge (CTL/ATL/TSB), ton analyse et tes prédictions.</div>
    </Card>
  );
}

export function SessionDetail() {
  const { id } = useParams();
  const nav = useNavigate();
  const data = useStore((s) => s.data);
  const plan = useStore((s) => s.plan);
  const unmarkSessionDone = useStore((s) => s.unmarkSessionDone);
  const [showForm, setShowForm] = useState(false);

  const session = useMemo(() => {
    const adapt = adaptedPlan(data, plan);
    return adapt.plan.find((s) => s.id === id) ?? plan?.sessions.find((s) => s.id === id) ?? null;
  }, [data, plan, id]);

  const doneActivity = session ? data.activities.find((a) => a.id === `done-${session.id}`) : undefined;
  const isDone = doneActivity != null;

  if (!session) {
    return (
      <div className="screen">
        <button className="btn ghost" onClick={() => nav(-1)}>← Retour</button>
        <Card style={{ marginTop: 12 }}>Séance introuvable.</Card>
      </div>
    );
  }

  return (
    <div className="screen">
      <button className="btn ghost" onClick={() => nav(-1)}>← Retour</button>
      <div className="row" style={{ gap: 12, margin: '12px 0' }}>
        <div className="badge" style={{ width: 52, height: 52, fontSize: '1.6rem', borderRadius: 14, display: 'grid', placeItems: 'center', background: `color-mix(in srgb, ${sportColor(session.sport)} 22%, transparent)` }}>
          {sportEmoji(session.sport)}
        </div>
        <div>
          <h1 style={{ fontSize: '1.35rem' }}>{session.title}</h1>
          <div className="muted small">{sportLabel(session.sport)} · {intentLabel(session.intent)} · {hms(session.estimatedDuration)} · charge {Math.round(session.estimatedLoad)}</div>
        </div>
      </div>

      {session.notes && <div className="banner" style={{ marginBottom: 'var(--sp-md)' }}>{session.notes}</div>}

      <SectionTitle>Déroulé</SectionTitle>
      <div className="stack-sm">
        {session.steps.map((step, i) => (
          <StepView key={i} step={step} />
        ))}
        {session.steps.length === 0 && <Card className="muted">Séance à matérialiser (substitution matériel).</Card>}
      </div>

      {isTestSession(session) ? (
        <div style={{ marginTop: 'var(--sp-lg)' }}>
          <Banner kind="success">Séance de test : réalise-la puis saisis ton résultat pour calibrer tes zones.</Banner>
          <div style={{ marginTop: 'var(--sp-sm)' }}>
            <TestResultForm sport={session.sport} />
          </div>
        </div>
      ) : showForm ? (
        <div style={{ marginTop: 'var(--sp-lg)' }}>
          <CompletionForm session={session} onDone={() => setShowForm(false)} />
        </div>
      ) : isDone ? (
        <div style={{ marginTop: 'var(--sp-lg)' }}>
          <Banner kind="success">✅ Séance réalisée — enregistrée dans ta charge et ton analyse.</Banner>
          {(() => {
            const cmp = doneActivity ? compareVsTarget(session, doneActivity) : null;
            if (!cmp) return null;
            const kind = cmp.verdict === 'in' ? 'success' : cmp.verdict === 'over' ? 'info' : 'warning';
            const word = cmp.verdict === 'in' ? 'dans la cible ✓' : cmp.verdict === 'over' ? 'au-dessus de la cible' : 'sous la cible';
            return (
              <Card style={{ marginTop: 'var(--sp-sm)' }}>
                <div className="row between">
                  <span className="muted small">{cmp.label} — cible</span>
                  <span className="num small">{cmp.target}</span>
                </div>
                <div className="row between" style={{ marginTop: 4 }}>
                  <span className="muted small">Réalisé</span>
                  <span className="num small" style={{ color: 'var(--text-primary)' }}>{cmp.actual}</span>
                </div>
                <Banner kind={kind}>{cmp.label} {word}.</Banner>
              </Card>
            );
          })()}
          <div className="row wrap" style={{ marginTop: 'var(--sp-sm)' }}>
            <button className="btn" onClick={() => setShowForm(true)}>✏️ Modifier</button>
            <button className="btn ghost danger" onClick={() => unmarkSessionDone(session)}>↩️ Annuler</button>
            <button className="btn ghost" onClick={() => downloadFitWorkout(session)}>⌚ Garmin (.FIT)</button>
            {session.sport === 'bike' && <button className="btn ghost" onClick={() => exportZwo(session)}>⬇️ .ZWO</button>}
          </div>
        </div>
      ) : (
        <div className="row wrap" style={{ marginTop: 'var(--sp-lg)' }}>
          <button className="btn accent" onClick={() => setShowForm(true)}>✅ Marquer réalisée</button>
          <button className="btn ghost" onClick={() => downloadFitWorkout(session)}>⌚ Garmin (.FIT)</button>
          {session.sport === 'bike' && <button className="btn ghost" onClick={() => exportZwo(session)}>⬇️ .ZWO</button>}
        </div>
      )}
    </div>
  );
}
