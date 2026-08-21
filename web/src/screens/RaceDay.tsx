import { useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
  RacePredictor, RacePacing, raceFueling, raceGoalGap, isTriathlon,
  type RaceFormat,
} from '@engine/index';
import { useStore } from '../app/store';
import { Card, SectionTitle, Banner, Pill, EmptyState } from '../ui/components';
import { hms, clock, dateFr, daysUntil, sportColor } from '../ui/format';
import { raceChecklist } from '../data/raceChecklist';

const FORMAT_LABEL: Record<string, string> = {
  xs: 'XS', sprint: 'Sprint', olympic: 'Olympique (M)', half: 'Half (70.3)', full: 'Full (140.6)',
  run5k: '5 km', run10k: '10 km', halfMarathon: 'Semi-marathon', marathon: 'Marathon',
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

export function RaceDay() {
  const { id } = useParams();
  const nav = useNavigate();
  const data = useStore((s) => s.data);
  const toggleChecklistItem = useStore((s) => s.toggleChecklistItem);

  const race = data.races.find((r) => r.id === id) ?? null;
  const checked = useMemo(() => new Set(race ? data.raceChecklists[race.id] ?? [] : []), [data.raceChecklists, race]);

  const model = useMemo(() => {
    if (!race || !data.profile) return null;
    const format = race.format as RaceFormat;
    const pred = new RacePredictor().predict(format, data.profile, data.equipment);
    const pacing = RacePacing.targets(format, data.profile);
    const fueling = raceFueling(format, pred.totalSeconds, data.profile.weightKg);
    const gap = race.goalTimeSeconds != null ? raceGoalGap(data.profile, data.equipment, format, race.goalTimeSeconds) : null;
    const checklist = raceChecklist(format, data.equipment);
    return { format, pred, pacing, fueling, gap, checklist, tri: isTriathlon(format) };
  }, [race, data.profile, data.equipment]);

  if (!race) {
    return (
      <div className="screen">
        <button className="btn ghost" onClick={() => nav(-1)}>← Retour</button>
        <Card style={{ marginTop: 12 }}>Course introuvable.</Card>
      </div>
    );
  }

  const toggle = (key: string) => toggleChecklistItem(race.id, key);

  const dLeft = daysUntil(race.date);

  return (
    <div className="screen">
      <button className="btn ghost" onClick={() => nav(-1)}>← Retour</button>

      <div className="row between" style={{ margin: '12px 0' }}>
        <div>
          <h1 style={{ fontSize: '1.4rem' }}>🏁 {race.title}</h1>
          <div className="muted small">{dateFr(race.date)} · {FORMAT_LABEL[race.format]} · priorité {race.priority.toUpperCase()}</div>
        </div>
        {dLeft >= 0 && <div className="num" style={{ fontSize: '1.6rem', color: 'var(--accent)' }}>J−{dLeft}</div>}
      </div>

      {!data.profile ? (
        <EmptyState title="Profil requis">Complète tes référentiels pour la prédiction et la stratégie.</EmptyState>
      ) : model && (
        <>
          <SectionTitle>Prédiction (au vu de ta forme)</SectionTitle>
          <Card>
            <div className="row between" style={{ marginBottom: 8 }}>
              <span className="muted">{FORMAT_LABEL[race.format]}</span>
              <Pill color={model.pred.confidenceHalfWidth > 0.12 ? 'var(--warning)' : 'var(--success)'}>± {Math.round(model.pred.confidenceHalfWidth * 100)} %</Pill>
            </div>
            <div className="num" style={{ fontSize: '2.2rem', color: 'var(--primary)' }}>{hms(model.pred.totalSeconds)}</div>
            <div className="tertiary small" style={{ marginBottom: model.tri ? 12 : 0 }}>
              Fourchette {hms(model.pred.totalSeconds * (1 - model.pred.confidenceHalfWidth))} – {hms(model.pred.totalSeconds * (1 + model.pred.confidenceHalfWidth))}
            </div>
            {model.tri && (
              <div className="stack-sm">
                {splitRow('🏊 Natation', model.pred.swimSeconds, sportColor('swim'))}
                {splitRow('🔄 T1', model.pred.t1Seconds)}
                {splitRow('🚴 Vélo', model.pred.bikeSeconds, sportColor('bike'))}
                {splitRow('🔄 T2', model.pred.t2Seconds)}
                {splitRow('🏃 Course', model.pred.runSeconds, sportColor('run'))}
              </div>
            )}
            {model.gap && (
              <Banner kind={model.gap.verdict === 'behind' ? 'warning' : model.gap.verdict === 'ahead' ? 'success' : 'info'}>
                🎯 Objectif {clock(model.gap.goalSeconds)} · {model.gap.verdict === 'behind'
                  ? `il te manque ~${Math.round(model.gap.deltaSeconds / 60)} min`
                  : model.gap.verdict === 'ahead'
                    ? `~${Math.round(-model.gap.deltaSeconds / 60)} min de marge`
                    : 'cohérent avec ta forme'}
              </Banner>
            )}
          </Card>

          <SectionTitle>Stratégie / pacing</SectionTitle>
          {model.pacing.length > 0 ? (
            <div className="stack-sm">
              {model.pacing.map((p) => (
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
            <EmptyState title="Référentiels manquants">Ajoute VDOT/VMA, FTP, CSS pour des cibles précises.</EmptyState>
          )}

          <SectionTitle>Nutrition — pendant la course</SectionTitle>
          <Card>
            <div className="stat-grid">
              <div className="stat"><div className="v">{model.fueling.during.carbsPerHour}</div><div className="l">g glucides/h</div></div>
              <div className="stat"><div className="v">{model.fueling.during.gels}</div><div className="l">gels (~{model.fueling.during.carbsPerGel} g)</div></div>
              <div className="stat"><div className="v">{model.fueling.during.bidons}</div><div className="l">bidons (~500 ml)</div></div>
              <div className="stat"><div className="v">{model.fueling.during.sodiumMg}</div><div className="l">mg sodium/h</div></div>
            </div>
            <div className="small muted" style={{ marginTop: 10 }}>{model.fueling.during.note}</div>
          </Card>

          <SectionTitle>Nutrition — la semaine avant</SectionTitle>
          <Card>
            <div className="stack-sm">
              {model.fueling.weekBefore.map((t, i) => <div key={i} className="small">• {t}</div>)}
            </div>
          </Card>

          <SectionTitle>Nutrition — le matin J</SectionTitle>
          <Card>
            <div className="stack-sm">
              {model.fueling.raceMorning.map((t, i) => <div key={i} className="small">• {t}</div>)}
            </div>
          </Card>

          <SectionTitle>Checklist matériel</SectionTitle>
          <div className="stack-sm">
            {model.checklist.map((section) => (
              <Card key={section.title}>
                <div style={{ fontWeight: 600, marginBottom: 8 }}>{section.title}</div>
                {section.items.map((item) => {
                  const key = section.title + '::' + item;
                  const on = checked.has(key);
                  return (
                    <label key={key} className="row" style={{ gap: 10, padding: '6px 0', cursor: 'pointer' }}>
                      <input type="checkbox" checked={on} onChange={() => toggle(key)} />
                      <span className="small" style={{ textDecoration: on ? 'line-through' : 'none', color: on ? 'var(--text-tertiary)' : 'var(--text-primary)' }}>{item}</span>
                    </label>
                  );
                })}
              </Card>
            ))}
          </div>
          <div className="tertiary small" style={{ textAlign: 'center', marginTop: 12 }}>Coche au fur et à mesure — sauvegardé automatiquement.</div>
        </>
      )}
    </div>
  );
}
