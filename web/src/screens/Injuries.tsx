import { useState } from 'react';
import type { BodyZone, Sport } from '@engine/index';
import { useStore } from '../app/store';
import { BODY_ZONES, REHAB_LABEL, rehab, specifics } from '../data/injuryCatalog';
import { Card, SectionTitle, Pill, Banner, EmptyState } from '../ui/components';

const ZONE_LABEL = Object.fromEntries(BODY_ZONES.map((z) => [z.zone, z.label])) as Record<BodyZone, string>;

// Sports affectés par zone (aligné sur la politique du moteur d'adaptation).
function affected(zone: BodyZone): Sport[] {
  switch (zone) {
    case 'knee': case 'ankle': case 'foot': case 'calf': case 'hip': case 'hamstring': return ['run', 'brick'];
    case 'shoulder': return ['swim'];
    case 'lowerBack': return ['brick'];
    default: return [];
  }
}

export function Injuries() {
  const data = useStore((s) => s.data);
  const addInjury = useStore((s) => s.addInjury);
  const removeInjury = useStore((s) => s.removeInjury);

  const [zone, setZone] = useState<BodyZone>('knee');
  const [specific, setSpecific] = useState<string | null>(null);
  const [intensity, setIntensity] = useState(3);
  const [present, setPresent] = useState(true);
  const [done, setDone] = useState(false);

  function selectZone(z: BodyZone) {
    setZone(z);
    setSpecific(null);
    setDone(false);
  }

  function declare() {
    addInjury({ zone, intensity, since: new Date(), affectedSports: new Set(affected(zone)), specific: specific ?? undefined });
    setDone(true);
  }

  return (
    <div className="screen">
      <div className="screen-header"><h1>Blessures 🩹</h1></div>
      <Banner kind="warning">Ceci ne remplace pas un avis médical. En cas de douleur persistante, consulte un professionnel.</Banner>

      <SectionTitle>Zone concernée</SectionTitle>
      <div className="row wrap">
        {BODY_ZONES.map((z) => (
          <button key={z.zone} className={`btn ${zone === z.zone ? 'primary' : 'ghost'} small`} onClick={() => selectZone(z.zone)}>{z.label}</button>
        ))}
      </div>

      <SectionTitle>Douleurs fréquentes — {ZONE_LABEL[zone]}</SectionTitle>
      <div className="tertiary small" style={{ marginBottom: 'var(--sp-xs)' }}>Touche la douleur qui correspond le mieux pour la sélectionner.</div>
      <div className="stack-sm">
        {specifics(zone).map((s) => {
          const sel = specific === s.name;
          return (
            <button
              key={s.id}
              onClick={() => { setSpecific(s.name); setDone(false); }}
              className="card"
              style={{ width: '100%', textAlign: 'left', cursor: 'pointer', borderColor: sel ? 'var(--danger)' : 'var(--separator)', background: sel ? 'color-mix(in srgb, var(--danger) 14%, var(--surface))' : 'var(--surface)' }}
            >
              <div className="row between">
                <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{s.name}</span>
                {sel && <span style={{ color: 'var(--danger)' }}>✓</span>}
              </div>
              <div className="small muted" style={{ marginTop: 4 }}>{s.sensation}</div>
            </button>
          );
        })}
      </div>

      <SectionTitle>Déclarer</SectionTitle>
      <Card>
        <div className="row between" style={{ marginBottom: 12 }}>
          <span className="muted small">Douleur</span>
          <span style={{ fontWeight: 600 }}>{specific ?? `${ZONE_LABEL[zone]} (non précisée)`}</span>
        </div>
        <div className="field">
          <label>Intensité : <b>{intensity}</b>/5 {intensity >= 3 && <span className="tertiary">(le plan sera adapté)</span>}</label>
          <input type="range" min={1} max={5} value={intensity} onChange={(e) => setIntensity(parseInt(e.target.value))} style={{ width: '100%' }} />
        </div>
        <label className="row" style={{ gap: 8, marginBottom: 12 }}>
          <input type="checkbox" checked={present} onChange={(e) => setPresent(e.target.checked)} /> Douleur encore présente
        </label>
        <button className="btn danger block" onClick={declare} disabled={!present}>Déclarer cette gêne</button>
        {affected(zone).length > 0 && <div className="tertiary small" style={{ marginTop: 8 }}>Sports mis en pause si intensité ≥ 3 : {affected(zone).join(', ')}.</div>}
        {done && <div className="banner success" style={{ marginTop: 10 }}>Blessure déclarée ✅ — le plan s'adapte.</div>}
      </Card>

      <SectionTitle>Rééducation & prévention — {ZONE_LABEL[zone]}</SectionTitle>
      <div className="stack-sm">
        {rehab(zone).map((ex) => (
          <Card key={ex.id}>
            <div className="row between">
              <span style={{ fontWeight: 600 }}>{ex.name}</span>
              <Pill>{REHAB_LABEL[ex.kind]}</Pill>
            </div>
            <div className="small muted" style={{ marginTop: 4 }}>{ex.howTo}</div>
          </Card>
        ))}
      </div>

      <SectionTitle>Blessures actives</SectionTitle>
      {data.injuries.length === 0 ? (
        <EmptyState title="Aucune blessure déclarée">Tant mieux ! Déclare une gêne pour que le coach adapte les séances.</EmptyState>
      ) : (
        <div className="stack-sm">
          {data.injuries.map((inj, i) => (
            <div key={i} className="session">
              <div className="grow">
                <div className="title">{ZONE_LABEL[inj.zone]}{inj.specific ? ` — ${inj.specific}` : ''}</div>
                <div className="sub">Intensité {inj.intensity}/5 · depuis le {inj.since.toLocaleDateString('fr-FR')}</div>
              </div>
              <button className="btn ghost small" onClick={() => removeInjury(i)}>Guéri ✓</button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
