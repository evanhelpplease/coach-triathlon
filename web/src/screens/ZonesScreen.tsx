import { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { ZoneCalculator, type TrainingZones, type ZoneBoundary } from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, EmptyState } from '../ui/components';
import { mmss } from '../ui/format';

function bpm(v: number): string {
  return Number.isFinite(v) ? String(Math.round(v)) : '∞';
}
function watts(v: number): string {
  return Number.isFinite(v) ? String(Math.round(v)) : '∞';
}

function ZoneList({ zones, kind, accent }: { zones: ZoneBoundary[]; kind: 'hr' | 'power' | 'runPace' | 'swimPace'; accent: string }) {
  const range = (z: ZoneBoundary): string => {
    switch (kind) {
      case 'hr': return `${bpm(z.lower)} – ${Number.isFinite(z.upper) ? bpm(z.upper) : 'max'} bpm`;
      case 'power': return `${watts(z.lower)} – ${Number.isFinite(z.upper) ? watts(z.upper) : 'max'} W`;
      case 'runPace': return `${mmss(z.lower)} – ${mmss(z.upper)} /km`;
      case 'swimPace': return `${mmss(z.lower)} – ${mmss(z.upper)} /100m`;
    }
  };
  return (
    <Card>
      <div className="stack-sm">
        {zones.map((z) => (
          <div key={z.zone} className="row between" style={{ alignItems: 'center' }}>
            <div className="row" style={{ gap: 10 }}>
              <span style={{ width: 22, height: 22, borderRadius: 6, background: `color-mix(in srgb, ${accent} ${20 + z.zone * 12}%, transparent)`, color: 'var(--text-primary)', display: 'grid', placeItems: 'center', fontSize: '0.75rem', fontWeight: 700 }}>
                {z.zone}
              </span>
              <span style={{ fontWeight: 600 }}>{z.label}</span>
            </div>
            <span className="num small">{range(z)}</span>
          </div>
        ))}
      </div>
    </Card>
  );
}

export function ZonesScreen() {
  const nav = useNavigate();
  const data = useStore((s) => s.data);
  const zones: TrainingZones | null = useMemo(() => (data.profile ? new ZoneCalculator().zones(data.profile) : null), [data.profile]);

  return (
    <div className="screen">
      <button className="btn ghost" onClick={() => nav(-1)}>← Retour</button>
      <div className="screen-header" style={{ marginTop: 12 }}>
        <div>
          <h1>Mes zones</h1>
          <div className="sub">Individualisées d'après tes référentiels</div>
        </div>
      </div>

      {!zones ? (
        <EmptyState title="Profil requis">Renseigne tes référentiels (FC, FTP, VMA/VDOT, CSS) pour calculer tes zones.</EmptyState>
      ) : (
        <>
          {zones.hr.length > 0 && (
            <>
              <SectionTitle>❤️ Fréquence cardiaque (Karvonen)</SectionTitle>
              <ZoneList zones={zones.hr} kind="hr" accent="var(--danger)" />
            </>
          )}
          {zones.power.length > 0 && (
            <>
              <SectionTitle>🚴 Puissance vélo (Coggan)</SectionTitle>
              <ZoneList zones={zones.power} kind="power" accent="var(--bike)" />
            </>
          )}
          {zones.runPace.length > 0 && (
            <>
              <SectionTitle>🏃 Allures course (VDOT)</SectionTitle>
              <ZoneList zones={zones.runPace} kind="runPace" accent="var(--run)" />
            </>
          )}
          {zones.swimPace.length > 0 && (
            <>
              <SectionTitle>🏊 Allures natation (CSS)</SectionTitle>
              <ZoneList zones={zones.swimPace} kind="swimPace" accent="var(--swim)" />
            </>
          )}
          <div className="tertiary small" style={{ marginTop: 'var(--sp-md)', textAlign: 'center' }}>
            {zones.source === 'estimated' ? 'Certaines zones sont estimées (FC max/repos manquants).' : 'Zones calculées depuis tes tests/référentiels.'}
          </div>
        </>
      )}
    </div>
  );
}
