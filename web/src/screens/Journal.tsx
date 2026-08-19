import { useRef, useState } from 'react';
import { startOfDay, type Sport } from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, EmptyState } from '../ui/components';
import { dateFr, hms, km, sportEmoji, sportLabel } from '../ui/format';
import { parseActivityFile } from '../services/importFiles';

const SPORTS: Sport[] = ['run', 'bike', 'swim', 'strength', 'brick'];
const todayISO = () => new Date().toISOString().slice(0, 10);

function num(v: string): number | undefined {
  const n = parseFloat(v.replace(',', '.'));
  return Number.isFinite(n) ? n : undefined;
}

export function Journal() {
  const data = useStore((s) => s.data);
  const addActivity = useStore((s) => s.addActivity);
  const addActivities = useStore((s) => s.addActivities);
  const addReadiness = useStore((s) => s.addReadiness);
  const removeActivity = useStore((s) => s.removeActivity);
  const [tab, setTab] = useState<'activity' | 'sleep'>('activity');
  const fileRef = useRef<HTMLInputElement>(null);
  const [importMsg, setImportMsg] = useState<string | null>(null);

  async function onFiles(files: FileList | null) {
    if (!files || files.length === 0) return;
    setImportMsg('Import en cours…');
    let total = 0;
    for (const f of Array.from(files)) {
      try {
        const acts = await parseActivityFile(f);
        if (acts.length) addActivities(acts);
        total += acts.length;
      } catch (e) {
        setImportMsg(`Erreur sur ${f.name} : ${(e as Error).message}`);
        return;
      }
    }
    setImportMsg(total > 0 ? `${total} activité(s) importée(s) ✅` : 'Aucune activité trouvée dans le fichier.');
  }

  return (
    <div className="screen">
      <div className="screen-header"><h1>Journal</h1></div>
      <div className="seg" style={{ marginBottom: 'var(--sp-md)' }}>
        <button className={tab === 'activity' ? 'active' : ''} onClick={() => setTab('activity')}>🏃 Entraînement</button>
        <button className={tab === 'sleep' ? 'active' : ''} onClick={() => setTab('sleep')}>😴 Sommeil / Forme</button>
      </div>

      {tab === 'activity' && (
        <Card style={{ marginBottom: 'var(--sp-md)' }}>
          <div className="row between">
            <div>
              <div style={{ fontWeight: 600 }}>📁 Importer un fichier</div>
              <div className="tertiary small">.fit · .tcx · .gpx · .csv (Garmin Connect, Strava…)</div>
            </div>
            <button className="btn" onClick={() => fileRef.current?.click()}>Choisir</button>
          </div>
          <input ref={fileRef} type="file" accept=".fit,.tcx,.gpx,.csv" multiple hidden onChange={(e) => void onFiles(e.target.files)} />
          {importMsg && <div className="banner" style={{ marginTop: 10 }}>{importMsg}</div>}
        </Card>
      )}

      {tab === 'activity' ? <ActivityForm onAdd={addActivity} /> : <SleepForm onAdd={addReadiness} />}

      <SectionTitle>Dernières entrées</SectionTitle>
      {data.activities.length === 0 && data.readiness.length === 0 && (
        <EmptyState title="Rien pour l'instant">Saisis une séance ou ton sommeil : le coach recalcule ta charge et adapte le plan.</EmptyState>
      )}
      <div className="stack-sm">
        {[...data.activities].sort((a, b) => b.start.getTime() - a.start.getTime()).slice(0, 12).map((a) => (
          <div key={a.id} className="session">
            <div className="badge" style={{ background: 'var(--surface-elevated)' }}>{sportEmoji(a.sport)}</div>
            <div className="grow">
              <div className="title">{sportLabel(a.sport)}</div>
              <div className="sub">
                {dateFr(a.start)} · {hms(a.duration)}
                {a.distanceM ? ` · ${km(a.distanceM)}` : ''}
                {a.avgHr ? ` · ${a.avgHr} bpm` : ''}
                {a.avgPowerW ? ` · ${a.avgPowerW} W` : ''}
              </div>
            </div>
            <button className="btn ghost danger small" onClick={() => removeActivity(a.id)}>✕</button>
          </div>
        ))}
      </div>
    </div>
  );
}

function ActivityForm({ onAdd }: { onAdd: ReturnType<typeof useStore.getState>['addActivity'] }) {
  const [sport, setSport] = useState<Sport>('run');
  const [date, setDate] = useState(todayISO());
  const [durationMin, setDurationMin] = useState('');
  const [distanceKm, setDistanceKm] = useState('');
  const [avgHr, setAvgHr] = useState('');
  const [power, setPower] = useState('');
  const [normPower, setNormPower] = useState('');
  const [lengths, setLengths] = useState('');
  const [rpe, setRpe] = useState('6');
  const [notes, setNotes] = useState('');
  const [msg, setMsg] = useState<string | null>(null);

  function submit() {
    const dur = num(durationMin);
    if (!dur || dur <= 0) { setMsg('Indique une durée.'); return; }
    const start = startOfDay(new Date(date + 'T08:00:00'));
    const distanceM = num(distanceKm) != null ? num(distanceKm)! * 1000 : undefined;
    const avgPaceSecPerKm = sport === 'run' && distanceM ? (dur * 60) / (distanceM / 1000) : undefined;
    onAdd({
      sport,
      start,
      duration: dur * 60,
      distanceM,
      avgHr: num(avgHr),
      avgPowerW: sport === 'bike' ? num(power) : undefined,
      normalizedPowerW: sport === 'bike' ? num(normPower) ?? num(power) : undefined,
      avgPaceSecPerKm,
      poolLengths: sport === 'swim' ? num(lengths) : undefined,
      rpe: num(rpe),
      source: 'manual',
    });
    setMsg('Séance enregistrée ✅');
    setDurationMin(''); setDistanceKm(''); setAvgHr(''); setPower(''); setNormPower(''); setLengths(''); setNotes('');
  }

  return (
    <Card>
      <div className="seg" style={{ marginBottom: 'var(--sp-sm)' }}>
        {SPORTS.map((s) => (
          <button key={s} className={sport === s ? 'active' : ''} onClick={() => setSport(s)}>{sportEmoji(s)}</button>
        ))}
      </div>
      <div className="field"><label>Date</label><input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
      <div className="row">
        <div className="field grow"><label>Durée (min)</label><input className="input" inputMode="decimal" value={durationMin} onChange={(e) => setDurationMin(e.target.value)} /></div>
        {sport !== 'strength' && <div className="field grow"><label>Distance (km)</label><input className="input" inputMode="decimal" value={distanceKm} onChange={(e) => setDistanceKm(e.target.value)} /></div>}
      </div>
      <div className="row">
        <div className="field grow"><label>FC moy (bpm)</label><input className="input" inputMode="numeric" value={avgHr} onChange={(e) => setAvgHr(e.target.value)} /></div>
        {sport === 'bike' && <div className="field grow"><label>Puissance moy (W)</label><input className="input" inputMode="numeric" value={power} onChange={(e) => setPower(e.target.value)} /></div>}
        {sport === 'bike' && <div className="field grow"><label>Puiss. norm. (W)</label><input className="input" inputMode="numeric" value={normPower} onChange={(e) => setNormPower(e.target.value)} /></div>}
        {sport === 'swim' && <div className="field grow"><label>Longueurs</label><input className="input" inputMode="numeric" value={lengths} onChange={(e) => setLengths(e.target.value)} /></div>}
      </div>
      <div className="field"><label>RPE ressenti (1–10)</label><input className="input" inputMode="numeric" value={rpe} onChange={(e) => setRpe(e.target.value)} /></div>
      <div className="field"><label>Notes</label><textarea className="input" rows={2} value={notes} onChange={(e) => setNotes(e.target.value)} /></div>
      <button className="btn primary block" onClick={submit}>Enregistrer la séance</button>
      {msg && <div className="banner success" style={{ marginTop: 'var(--sp-sm)' }}>{msg}</div>}
    </Card>
  );
}

function Slider({ label, value, set }: { label: string; value: number; set: (n: number) => void }) {
  return (
    <div className="field">
      <label>{label} : <b>{value}</b>/5</label>
      <input type="range" min={1} max={5} value={value} onChange={(e) => set(parseInt(e.target.value))} style={{ width: '100%' }} />
    </div>
  );
}

function SleepForm({ onAdd }: { onAdd: ReturnType<typeof useStore.getState>['addReadiness'] }) {
  const [date, setDate] = useState(todayISO());
  const [sleep, setSleep] = useState('7.5');
  const [hrRest, setHrRest] = useState('');
  const [hrv, setHrv] = useState('');
  const [form, setForm] = useState(4);
  const [sleepQuality, setSleepQuality] = useState(4);
  const [soreness, setSoreness] = useState(4);
  const [motivation, setMotivation] = useState(4);
  const [msg, setMsg] = useState<string | null>(null);

  function submit() {
    onAdd({
      date: startOfDay(new Date(date + 'T08:00:00')),
      sleepHours: num(sleep),
      hrRest: num(hrRest),
      hrvMs: num(hrv),
      subjective: { form, sleepQuality, soreness, motivation },
    });
    setMsg('Check-in enregistré ✅ — le plan s\'adapte aujourd\'hui.');
  }

  return (
    <Card>
      <div className="field"><label>Date</label><input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
      <div className="row">
        <div className="field grow"><label>Sommeil (h)</label><input className="input" inputMode="decimal" value={sleep} onChange={(e) => setSleep(e.target.value)} /></div>
        <div className="field grow"><label>FC repos (bpm)</label><input className="input" inputMode="numeric" value={hrRest} onChange={(e) => setHrRest(e.target.value)} /></div>
        <div className="field grow"><label>VFC (ms)</label><input className="input" inputMode="numeric" value={hrv} onChange={(e) => setHrv(e.target.value)} /></div>
      </div>
      <Slider label="Forme" value={form} set={setForm} />
      <Slider label="Qualité sommeil" value={sleepQuality} set={setSleepQuality} />
      <Slider label="Courbatures (5 = aucune)" value={soreness} set={setSoreness} />
      <Slider label="Motivation" value={motivation} set={setMotivation} />
      <button className="btn primary block" onClick={submit}>Enregistrer le check-in</button>
      {msg && <div className="banner success" style={{ marginTop: 'var(--sp-sm)' }}>{msg}</div>}
    </Card>
  );
}
