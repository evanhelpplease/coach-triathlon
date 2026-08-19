import { useState } from 'react';
import { makeAvailability, makeUnavailability, type WeeklyAvailability, type TemporaryUnavailability, type Sport } from '@engine/index';
import { Card } from './components';
import { dateShort } from './format';

// Jours grégoriens (1=dim…7=sam), affichés du lundi au dimanche.
const DAYS: { g: number; label: string }[] = [
  { g: 2, label: 'L' }, { g: 3, label: 'M' }, { g: 4, label: 'M' }, { g: 5, label: 'J' },
  { g: 6, label: 'V' }, { g: 7, label: 'S' }, { g: 1, label: 'D' },
];
const DISCIPLINES: { sport: Sport; label: string; emoji: string }[] = [
  { sport: 'swim', label: 'Natation', emoji: '🏊' },
  { sport: 'bike', label: 'Vélo', emoji: '🚴' },
  { sport: 'run', label: 'Course', emoji: '🏃' },
];

/** Jours autorisés par discipline (ex. piscine seulement lun/mer/ven). */
export function SportDaysEditor({ availability, onChange }: { availability: WeeklyAvailability; onChange: (a: WeeklyAvailability) => void }) {
  const toggle = (sport: Sport, g: number) => {
    const current = new Set(availability.sportDays[sport] ?? []);
    current.has(g) ? current.delete(g) : current.add(g);
    const sportDays = { ...availability.sportDays, [sport]: current };
    if (current.size === 0) delete sportDays[sport];
    onChange(makeAvailability({ ...availability, sportDays }));
  };

  return (
    <Card>
      <div className="tertiary small" style={{ marginBottom: 10 }}>
        Sélectionne les jours où chaque discipline est possible. Aucun jour coché = disponible tous les jours dispo.
      </div>
      {DISCIPLINES.map(({ sport, label, emoji }) => {
        const set = availability.sportDays[sport];
        return (
          <div key={sport} style={{ marginBottom: 12 }}>
            <div className="row between" style={{ marginBottom: 6 }}>
              <span style={{ fontWeight: 600 }}>{emoji} {label}</span>
              <span className="tertiary small">{!set || set.size === 0 ? 'tous les jours' : `${set.size} jour(s)`}</span>
            </div>
            <div className="row" style={{ gap: 4 }}>
              {DAYS.map((d) => {
                const active = set?.has(d.g) ?? false;
                return (
                  <button
                    key={d.g}
                    onClick={() => toggle(sport, d.g)}
                    className="btn"
                    style={{
                      flex: 1, padding: '8px 0',
                      background: active ? 'var(--primary)' : 'var(--surface-elevated)',
                      color: active ? '#04222a' : 'var(--text-secondary)',
                      borderColor: 'transparent',
                    }}
                  >
                    {d.label}
                  </button>
                );
              })}
            </div>
          </div>
        );
      })}
    </Card>
  );
}

const UNAVAIL_SPORTS: { sport: Sport; label: string }[] = [
  { sport: 'swim', label: 'Natation' },
  { sport: 'bike', label: 'Vélo' },
  { sport: 'run', label: 'Course' },
  { sport: 'strength', label: 'Renfo' },
];

/** Périodes d'indisponibilité temporaire (déplacement, matériel manquant…). */
export function UnavailabilityEditor({
  unavailabilities,
  onAdd,
  onRemove,
}: {
  unavailabilities: TemporaryUnavailability[];
  onAdd: (u: TemporaryUnavailability) => void;
  onRemove: (id: string) => void;
}) {
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [sports, setSports] = useState<Set<Sport>>(new Set());
  const [reason, setReason] = useState('');

  const toggleSport = (s: Sport) => {
    const next = new Set(sports);
    next.has(s) ? next.delete(s) : next.add(s);
    setSports(next);
  };

  const add = () => {
    if (!from || !to || sports.size === 0) return;
    onAdd(makeUnavailability({
      from: new Date(from + 'T00:00:00'),
      to: new Date(to + 'T00:00:00'),
      sports: [...sports],
      reason: reason.trim() || undefined,
    }));
    setFrom(''); setTo(''); setSports(new Set()); setReason('');
  };

  return (
    <>
      <Card>
        <div className="tertiary small" style={{ marginBottom: 10 }}>
          Ex. en déplacement sans vélo, ou piscine fermée. Les séances concernées sont automatiquement converties (course ↔ vélo, travail à sec…).
        </div>
        <div className="row">
          <div className="field grow"><label>Du</label><input className="input" type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></div>
          <div className="field grow"><label>Au</label><input className="input" type="date" value={to} onChange={(e) => setTo(e.target.value)} /></div>
        </div>
        <div className="field">
          <label>Disciplines indisponibles</label>
          <div className="row wrap">
            {UNAVAIL_SPORTS.map(({ sport, label }) => (
              <button key={sport} className={`btn ${sports.has(sport) ? 'primary' : 'ghost'} small`} onClick={() => toggleSport(sport)}>{label}</button>
            ))}
          </div>
        </div>
        <div className="field"><label>Motif (optionnel)</label><input className="input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Déplacement pro…" /></div>
        <button className="btn primary block" onClick={add} disabled={!from || !to || sports.size === 0}>Ajouter la période</button>
      </Card>

      {unavailabilities.length > 0 && (
        <div className="stack-sm" style={{ marginTop: 'var(--sp-sm)' }}>
          {[...unavailabilities].sort((a, b) => a.from.getTime() - b.from.getTime()).map((u) => (
            <div key={u.id} className="session">
              <div className="grow">
                <div className="title">{u.sports.map((s) => UNAVAIL_SPORTS.find((x) => x.sport === s)?.label ?? s).join(', ')} indispo.</div>
                <div className="sub">{dateShort(u.from)} → {dateShort(u.to)}{u.reason ? ` · ${u.reason}` : ''}</div>
              </div>
              <button className="btn ghost danger small" onClick={() => onRemove(u.id)}>✕</button>
            </div>
          ))}
        </div>
      )}
    </>
  );
}
