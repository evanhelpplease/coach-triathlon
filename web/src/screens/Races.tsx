import { useState } from 'react';
import { makeRace, type RaceFormat, type RacePriority } from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, EmptyState, Pill } from '../ui/components';
import { dateFr, daysUntil, clock, parseClock } from '../ui/format';

const FORMATS: { value: RaceFormat; label: string }[] = [
  { value: 'xs', label: 'XS' },
  { value: 'sprint', label: 'Sprint' },
  { value: 'olympic', label: 'Olympique (M)' },
  { value: 'half', label: 'Half 70.3' },
  { value: 'full', label: 'Full 140.6' },
  { value: 'run10k', label: '10 km' },
  { value: 'halfMarathon', label: 'Semi' },
  { value: 'marathon', label: 'Marathon' },
];

export function Races() {
  const data = useStore((s) => s.data);
  const addRace = useStore((s) => s.addRace);
  const removeRace = useStore((s) => s.removeRace);

  const [title, setTitle] = useState('');
  const [date, setDate] = useState('');
  const [format, setFormat] = useState<RaceFormat>('olympic');
  const [priority, setPriority] = useState<RacePriority>('a');
  const [goal, setGoal] = useState('');

  function add() {
    if (!title.trim() || !date) return;
    addRace(makeRace({ title: title.trim(), date: new Date(date + 'T09:00:00'), format, priority, goalTimeSeconds: parseClock(goal) ?? undefined }));
    setTitle(''); setDate(''); setGoal('');
  }

  const sorted = [...data.races].sort((a, b) => a.date.getTime() - b.date.getTime());

  return (
    <div className="screen">
      <div className="screen-header"><h1>Courses 🏁</h1></div>

      <Card>
        <div className="field"><label>Nom de la course</label><input className="input" value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Triathlon de…" /></div>
        <div className="row">
          <div className="field grow"><label>Date</label><input className="input" type="date" value={date} onChange={(e) => setDate(e.target.value)} /></div>
          <div className="field grow"><label>Priorité</label>
            <select className="select" value={priority} onChange={(e) => setPriority(e.target.value as RacePriority)}>
              <option value="a">A (objectif)</option><option value="b">B</option><option value="c">C</option>
            </select>
          </div>
        </div>
        <div className="row">
          <div className="field grow"><label>Format</label>
            <select className="select" value={format} onChange={(e) => setFormat(e.target.value as RaceFormat)}>
              {FORMATS.map((f) => <option key={f.value} value={f.value}>{f.label}</option>)}
            </select>
          </div>
          <div className="field grow"><label>Objectif de temps (h:mm:ss)</label>
            <input className="input" value={goal} onChange={(e) => setGoal(e.target.value)} placeholder="2:15:00" />
          </div>
        </div>
        <div className="tertiary small" style={{ marginBottom: 'var(--sp-sm)' }}>L'objectif pilote l'ambition du plan (rampe & intensité) et le pacing du jour J.</div>
        <button className="btn primary block" onClick={add}>Ajouter la course</button>
      </Card>

      <SectionTitle>Mes courses</SectionTitle>
      {sorted.length === 0 ? (
        <EmptyState title="Aucune course">Ajoute au moins une course pour générer un plan périodisé.</EmptyState>
      ) : (
        <div className="stack-sm">
          {sorted.map((r) => (
            <div key={r.id} className="session">
              <div className="grow">
                <div className="title">{r.title}</div>
                <div className="sub">
                  {dateFr(r.date)} · {FORMATS.find((f) => f.value === r.format)?.label}
                  {r.goalTimeSeconds != null ? ` · 🎯 ${clock(r.goalTimeSeconds)}` : ''}
                </div>
              </div>
              <Pill color={r.priority === 'a' ? 'var(--primary)' : undefined}>Prio {r.priority.toUpperCase()}</Pill>
              {r.date >= new Date() && <span className="num tertiary small">J−{daysUntil(r.date)}</span>}
              <button className="btn ghost danger small" onClick={() => removeRace(r.id)}>✕</button>
            </div>
          ))}
        </div>
      )}
      <div className="tertiary small" style={{ marginTop: 12 }}>Le plan se régénère automatiquement à chaque ajout/suppression.</div>
    </div>
  );
}
