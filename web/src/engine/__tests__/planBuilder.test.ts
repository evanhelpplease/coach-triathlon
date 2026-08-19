import { describe, it, expect } from 'vitest';
import {
  PlanBuilder,
  planWeekLoad,
  makeAvailability,
  makeProfile,
  makeEquipment,
  makeRace,
  addDays,
  isSameDay,
  weekday,
  SkillLevel,
  polarization,
  type SessionIntent,
} from '../index';

const INTENSE: Set<SessionIntent> = new Set(['threshold', 'vo2', 'sprint']);

const start = new Date(0);
const planProfile = makeProfile({
  birthDate: new Date(Date.UTC(1990, 0, 1)),
  sex: 'male',
  heightCm: 180,
  weightKg: 72,
  hrMax: 190,
  hrRest: 48,
  ftpWatts: 250,
  cssSecPer100m: 95,
  vdot: 50,
  levels: { swim: SkillLevel.novice, bike: SkillLevel.advanced, run: SkillLevel.intermediate },
});
const equip = makeEquipment({ hasBike: true, bikeType: 'road', hasAeroBars: true, poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
const raceA = makeRace({ date: addDays(start, 12 * 7), format: 'olympic', priority: 'a', title: 'Triathlon M' });

describe('PlanBuilder (assemblage bout-en-bout)', () => {
  const plan = new PlanBuilder().buildOne(planProfile, equip, raceA, start, makeAvailability({ maxSessionsPerWeek: 6 }));

  it('plan non vide', () => {
    expect(plan.sessions.length).toBeGreaterThan(0);
  });

  it('chaque semaine a des séances', () => {
    expect(
      plan.weeks.every((w) => {
        const end = addDays(w.startDate, 7);
        return plan.sessions.some((s) => s.date >= w.startDate && s.date < end);
      }),
    ).toBe(true);
  });

  it('semaine build couvre nat + vélo + course', () => {
    const buildWk = plan.weeks.find((w) => w.phase === 'build')!;
    const endB = addDays(buildWk.startDate, 7);
    const sports = new Set(plan.sessions.filter((s) => s.date >= buildWk.startDate && s.date < endB).map((s) => s.sport));
    expect(sports.has('swim') && sports.has('bike') && sports.has('run')).toBe(true);
  });

  it('polarisation ~80/20 par le temps en intensité (facile ≥ 75 %)', () => {
    const pol = polarization(plan.sessions);
    expect(pol.easyFraction).toBeGreaterThanOrEqual(0.75);
    expect(pol.easyFraction).toBeLessThan(0.95); // sinon ce n'est plus polarisé mais mou
  });

  it('travail de vitesse réparti : intensité chaque phase, natation incluse, VMA présente', () => {
    const intense = plan.sessions.filter((s) => INTENSE.has(s.intent));
    // La base n'est plus un désert de vitesse.
    const baseWeeks = plan.weeks.filter((w) => w.phase === 'base');
    for (const w of baseWeeks) {
      const end = addDays(w.startDate, 7);
      const hard = plan.sessions.filter((s) => s.date >= w.startDate && s.date < end && INTENSE.has(s.intent));
      expect(hard.length).toBeGreaterThanOrEqual(1);
    }
    // Chaque discipline reçoit de l'intensité (natation comprise).
    for (const sport of ['swim', 'bike', 'run'] as const) {
      expect(intense.some((s) => s.sport === sport)).toBe(true);
    }
    // VMA / vitesse pure programmée quelque part.
    expect(plan.sessions.some((s) => s.intent === 'sprint' || s.intent === 'vo2')).toBe(true);
  });

  it('intervalles vélo présents en build', () => {
    const buildWk = plan.weeks.find((w) => w.phase === 'build')!;
    const endB = addDays(buildWk.startDate, 7);
    const buildBike = plan.sessions.filter((s) => s.date >= buildWk.startDate && s.date < endB && s.sport === 'bike');
    expect(buildBike.some((s) => s.intent === 'threshold' || s.intent === 'vo2')).toBe(true);
  });

  it('charge semaine build ≈ cible (±30 %)', () => {
    const buildWk = plan.weeks.find((w) => w.phase === 'build')!;
    const got = planWeekLoad(plan, buildWk.index);
    expect(Math.abs(got - buildWk.targetLoad)).toBeLessThanOrEqual(buildWk.targetLoad * 0.3);
  });

  it('affûtage plus léger que le pic', () => {
    const peak = Math.max(...plan.weeks.filter((w) => w.phase !== 'taper').map((w) => planWeekLoad(plan, w.index)));
    expect(plan.weeks.filter((w) => w.phase === 'taper').every((w) => planWeekLoad(plan, w.index) < peak)).toBe(true);
  });

  it('identifiants déterministes : deux régénérations identiques → mêmes ids (synchro idempotente)', () => {
    const a = new PlanBuilder().buildOne(planProfile, equip, raceA, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    const b = new PlanBuilder().buildOne(planProfile, equip, raceA, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    expect(a.sessions.map((s) => s.id)).toEqual(b.sessions.map((s) => s.id));
    // Ids uniques dans un plan.
    expect(new Set(a.sessions.map((s) => s.id)).size).toBe(a.sessions.length);
  });
});

describe('PlanBuilder — contraintes', () => {
  it('démarrage sans vélo/piscine : plan quand même, sans vélo ni bassin', () => {
    const noGear = makeEquipment({ hasBike: false, poolAccess: false, openWaterAccess: false, hasDrylandCords: true, runOutdoor: true, strengthAccess: 'bodyweightOnly' });
    const race = makeRace({ date: addDays(start, 8 * 7), format: 'olympic', priority: 'a', title: 'M' });
    const plan = new PlanBuilder().buildOne(planProfile, noGear, race, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    expect(plan.sessions.length).toBeGreaterThan(0);
    expect(plan.sessions.some((s) => s.sport === 'bike' || s.sport === 'swim')).toBe(false);
  });

  it('natation uniquement le lundi (jours piscine respectés)', () => {
    const poolMonday = makeAvailability({ maxSessionsPerWeek: 6, sportDays: { swim: new Set([2]) } });
    const plan = new PlanBuilder().buildOne(planProfile, equip, raceA, start, poolMonday);
    const swimDays = new Set(plan.sessions.filter((s) => s.sport === 'swim').map((s) => weekday(s.date)));
    expect(swimDays.size).toBeGreaterThan(0);
    expect([...swimDays].every((d) => d === 2)).toBe(true);
  });

  it('courses multiples : aucune séance le jour de la course B', () => {
    const raceB = makeRace({ date: addDays(start, 6 * 7), format: 'sprint', priority: 'b', title: 'Sprint local' });
    const plan = new PlanBuilder().build(planProfile, equip, [raceB, raceA], start, makeAvailability({ maxSessionsPerWeek: 6 }));
    expect(plan.sessions.some((s) => isSameDay(s.date, raceB.date))).toBe(false);
  });
});
