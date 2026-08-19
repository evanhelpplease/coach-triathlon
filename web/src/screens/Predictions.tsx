import { useMemo, useState } from 'react';
import {
  RacePredictor, RaceNutrition, RacePacing, raceGoalGap, startOfDay,
  type RaceFormat, type RacePrediction,
} from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, EmptyState, Pill, Banner } from '../ui/components';
import { hms, mmss, clock, sportColor } from '../ui/format';

const TRI_FORMATS: RaceFormat[] = ['xs', 'sprint', 'olympic', 'half', 'full'];
const FORMAT_LABEL: Record<string, string> = {
  xs: 'XS', sprint: 'Sprint', olympic: 'Olympique (M)', half: 'Half (70.3)', full: 'Full (140.6)',
  run10k: '10 km', halfMarathon: 'Semi', marathon: 'Marathon',
};

function splitRow(label: string, sec: number | null | undefined, color?: string) {
  if (sec == null) return null;
  return (
    <div className="row between small" key={label}>
      <span style={color ? { color } : undefined}>{label}</span>
      <span className="num">{hms(sec)}</span>
    </div>
  );
}

export function Predictions() {
  const data = useStore((s) => s.data);
  const today = startOfDay(new Date());
  const nextRace = useMemo(
    () => [...data.races].filter((r) => r.date >= today).sort((a, b) => a.date.getTime() - b.date.getTime())[0] ?? data.races[0] ?? null,
    [data.races, today],
  );
  const [format, setFormat] = useState<RaceFormat>(nextRace?.format ?? 'olympic');

  if (!data.profile) {
    return (
      <div className="screen">
        <div className="screen-header"><h1>Prédictions</h1></div>
        <EmptyState title="Profil requis">Renseigne tes référentiels (VDOT, FTP, CSS) pour prédire tes chronos.</EmptyState>
      </div>
    );
  }

  const predictor = new RacePredictor();
  const pred: RacePrediction = predictor.predict(format, data.profile, data.equipment);
  const pacing = RacePacing.targets(format, data.profile);
  const nutrition = RaceNutrition.plan(pred.totalSeconds, data.profile.weightKg, format);
  const ic = Math.round(pred.confidenceHalfWidth * 100);

  // Comparaison à l'objectif (si la course sélectionnée a un chrono cible et correspond au format affiché).
  const goalRace = nextRace && nextRace.format === format && nextRace.goalTimeSeconds != null ? nextRace : null;
  const gap = goalRace ? raceGoalGap(data.profile, data.equipment, format, goalRace.goalTimeSeconds!) : null;

  return (
    <div className="screen">
      <div className="screen-header">
        <div>
          <h1>Prédictions</h1>
          {nextRace && <div className="sub">{nextRace.title}</div>}
        </div>
      </div>

      <div className="row wrap" style={{ marginBottom: 'var(--sp-md)' }}>
        {TRI_FORMATS.map((f) => (
          <button key={f} className={`btn ${format === f ? 'primary' : 'ghost'} small`} onClick={() => setFormat(f)}>
            {FORMAT_LABEL[f]}
          </button>
        ))}
      </div>

      <Card>
        <div className="row between" style={{ marginBottom: 8 }}>
          <span className="muted">Chrono prédit — {FORMAT_LABEL[format]}</span>
          <Pill color={ic > 12 ? 'var(--warning)' : 'var(--success)'}>± {ic} %</Pill>
        </div>
        <div className="num" style={{ fontSize: '2.4rem', color: 'var(--primary)' }}>{hms(pred.totalSeconds)}</div>
        <div className="tertiary small" style={{ marginBottom: 12 }}>
          Fourchette {hms(pred.totalSeconds * (1 - pred.confidenceHalfWidth))} – {hms(pred.totalSeconds * (1 + pred.confidenceHalfWidth))}
        </div>
        <div className="stack-sm">
          {splitRow('🏊 Natation', pred.swimSeconds, sportColor('swim'))}
          {splitRow('🔄 T1', pred.t1Seconds)}
          {splitRow('🚴 Vélo', pred.bikeSeconds, sportColor('bike'))}
          {splitRow('🔄 T2', pred.t2Seconds)}
          {splitRow('🏃 Course', pred.runSeconds, sportColor('run'))}
        </div>
        {ic > 12 && <div className="banner warning" style={{ marginTop: 12 }}>Intervalle large : renseigne tes référentiels manquants (VDOT/FTP/CSS) pour préciser.</div>}
      </Card>

      {gap && (
        <>
          <SectionTitle>Objectif</SectionTitle>
          <Card>
            <div className="row between">
              <div><div className="tertiary small">🎯 Objectif</div><div className="num" style={{ fontSize: '1.4rem', color: 'var(--accent)' }}>{clock(gap.goalSeconds)}</div></div>
              <div style={{ textAlign: 'right' }}><div className="tertiary small">Prédit (forme actuelle)</div><div className="num" style={{ fontSize: '1.4rem' }}>{hms(gap.predictedSeconds)}</div></div>
            </div>
            <Banner kind={gap.verdict === 'behind' ? 'warning' : gap.verdict === 'ahead' ? 'success' : 'info'}>
              {gap.verdict === 'behind'
                ? `Il te manque ~${Math.round(gap.deltaSeconds / 60)} min : le plan renforce l'intensité et la rampe pour t'y amener.`
                : gap.verdict === 'ahead'
                  ? `Tu es ~${Math.round(-gap.deltaSeconds / 60)} min plus rapide que l'objectif : marge confortable.`
                  : 'Objectif cohérent avec ta forme actuelle.'}
            </Banner>
          </Card>
        </>
      )}

      <SectionTitle>Pacing cible le jour J</SectionTitle>
      {pacing.length > 0 ? (
        <div className="stack-sm">
          {pacing.map((p) => (
            <Card key={p.sportKey}>
              <div className="row between">
                <span style={{ fontWeight: 600, color: sportColor(p.sportKey as never) }}>{p.label}</span>
                <span className="num">{p.value}</span>
              </div>
              <div className="tertiary small" style={{ marginTop: 4 }}>{p.note}</div>
            </Card>
          ))}
        </div>
      ) : (
        <EmptyState title="Référentiels manquants">Ajoute VDOT/FTP/CSS pour des cibles précises.</EmptyState>
      )}

      <SectionTitle>Nutrition</SectionTitle>
      <Card>
        <div className="stat-grid">
          <div className="stat"><div className="v">{nutrition.carbsPerHour}</div><div className="l">g glucides/h</div></div>
          <div className="stat"><div className="v">{nutrition.totalCarbs}</div><div className="l">g total</div></div>
          <div className="stat"><div className="v">{nutrition.fluidPerHour}</div><div className="l">ml liquide/h</div></div>
          <div className="stat"><div className="v">{nutrition.sodiumPerHour}</div><div className="l">mg sodium/h</div></div>
        </div>
        <div className="small muted" style={{ marginTop: 10 }}>{nutrition.summary}</div>
      </Card>

      <SectionTitle>Projections tous formats</SectionTitle>
      <Card>
        <div className="stack-sm">
          {TRI_FORMATS.map((f) => {
            const p = predictor.predict(f, data.profile!, data.equipment);
            return (
              <div key={f} className="row between small">
                <span>{FORMAT_LABEL[f]}</span>
                <span className="num">{hms(p.totalSeconds)}</span>
              </div>
            );
          })}
        </div>
      </Card>
      <div className="tertiary small" style={{ textAlign: 'center', marginTop: 12 }}>
        Basé sur {data.profile.vma ? `VMA ${data.profile.vma} km/h · ` : ''}VDOT {data.profile.vdot ? data.profile.vdot.toFixed(0) : '—'}, FTP {data.profile.ftpWatts ?? '—'} W, CSS {data.profile.cssSecPer100m ? mmss(data.profile.cssSecPer100m) + '/100m' : '—'}.
      </div>
    </div>
  );
}
