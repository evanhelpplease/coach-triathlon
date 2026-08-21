import { describe, it, expect } from 'vitest';
import {
  Periodizer,
  configForProgression,
  SessionGenerator,
  ZoneCalculator,
  ReadinessEvaluator,
  makeProfile,
  makeEquipment,
  makeRace,
  addDays,
  type TrainingPhase,
  type DailyReadiness,
} from '../index';

const start = new Date(0);
const profile = makeProfile({
  birthDate: new Date(Date.UTC(1990, 0, 1)),
  sex: 'male',
  heightCm: 180,
  weightKg: 72,
  hrMax: 190,
  hrRest: 48,
  ftpWatts: 260,
  cssSecPer100m: 95,
  vdot: 52,
});

const rank = (p: TrainingPhase) => ['base', 'build', 'specific', 'taper', 'recovery'].indexOf(p);

describe('Périodisation', () => {
  const race = makeRace({ date: addDays(start, 12 * 7), format: 'olympic', priority: 'a', title: 'A' });
  const weeks = new Periodizer().plan(start, race);

  it('phases non décroissantes', () => {
    for (let i = 1; i < weeks.length; i++) {
      expect(rank(weeks[i - 1].phase)).toBeLessThanOrEqual(rank(weeks[i].phase));
    }
  });

  it('contient une semaine de décharge', () => {
    expect(weeks.some((w) => w.isDeload)).toBe(true);
  });

  it("se termine par l'affûtage", () => {
    expect(weeks.at(-1)!.phase).toBe('taper');
  });

  it('progression Performance monte plus fort que Prudent', () => {
    const prudent = new Periodizer().plan(start, race, configForProgression('prudent'));
    const perf = new Periodizer().plan(start, race, configForProgression('performance'));
    const peakPrudent = Math.max(...prudent.map((w) => w.targetLoad));
    const peakPerf = Math.max(...perf.map((w) => w.targetLoad));
    expect(peakPerf).toBeGreaterThan(peakPrudent);
  });
});

describe('Générateur de séances', () => {
  const zones = new ZoneCalculator().zones(profile);
  const equip = makeEquipment({ hasBike: true, bikeType: 'road', hasAeroBars: true, poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
  const gen = new SessionGenerator();

  it('course seuil : échauffement + bloc répété + retour au calme', () => {
    const thr = gen.generate('run', 'threshold', 'build', start, zones, profile, equip);
    expect(thr.steps[0]?.kind).toBe('warmup');
    expect(thr.steps.at(-1)?.kind).toBe('cooldown');
    expect(thr.steps.some((s) => s.kind === 'repeatBlock')).toBe(true);
    expect(thr.estimatedLoad).toBeGreaterThan(0);
    expect(thr.estimatedDuration).toBeGreaterThan(0);
  });

  it('phase build > phase base (volume)', () => {
    const baseR = gen.generate('run', 'endurance', 'base', start, zones, profile, equip);
    const buildR = gen.generate('run', 'endurance', 'build', start, zones, profile, equip);
    expect(buildR.estimatedLoad).toBeGreaterThan(baseR.estimatedLoad);
  });

  it('natation exprimée en longueurs', () => {
    const swim = gen.generate('swim', 'technique', 'base', start, zones, profile, equip);
    expect(swim.steps.some((s) => s.duration.kind === 'lengths')).toBe(true);
  });
});

describe('Évaluation de la récupération', () => {
  const hist: DailyReadiness[] = Array.from({ length: 7 }, (_, i) => ({
    date: addDays(start, i),
    sleepHours: 8,
    hrRest: 48,
    hrvMs: 80,
  }));

  it('jour frais → good', () => {
    const good = new ReadinessEvaluator().assess(
      { date: start, sleepHours: 8, hrRest: 47, hrvMs: 82, subjective: { form: 5, sleepQuality: 5, soreness: 5, motivation: 5 } },
      hist,
    );
    expect(good.level).toBe('good');
  });

  it('jour fatigué → low', () => {
    const bad = new ReadinessEvaluator().assess(
      { date: start, sleepHours: 5, hrRest: 58, hrvMs: 42, subjective: { form: 2, sleepQuality: 2, soreness: 1, motivation: 2 } },
      hist,
    );
    expect(bad.level).toBe('low');
  });

  it('nuit de 2h ne peut jamais être « au top », même sans autre signal', () => {
    // Sommeil très court seul, ressenti neutre (3/5) : ne doit PAS donner good.
    const r = new ReadinessEvaluator().assess(
      { date: start, sleepHours: 2, subjective: { form: 3, sleepQuality: 2, soreness: 3, motivation: 3 } },
      hist,
    );
    expect(r.level).toBe('low'); // < 3 h → repos impératif
    expect(r.level).not.toBe('good');
  });

  it('nuit de 4h30 bride à moderate au mieux', () => {
    const r = new ReadinessEvaluator().assess(
      { date: start, sleepHours: 4.5, subjective: { form: 4, sleepQuality: 3, soreness: 4, motivation: 4 } },
      hist,
    );
    expect(r.level).not.toBe('good');
  });
});
