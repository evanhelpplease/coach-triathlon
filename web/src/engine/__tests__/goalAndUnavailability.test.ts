import { describe, it, expect } from 'vitest';
import {
  PlanBuilder, planWeekLoad, defaultPlanConfig, makeAvailability, makeProfile, makeEquipment, makeRace,
  makeUnavailability, raceGoalGap, equipmentOn, canPractice, addDays, startOfDay, SkillLevel,
} from '../index';

const start = startOfDay(new Date(0));
const profile = makeProfile({
  birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 180, weightKg: 72,
  hrMax: 190, hrRest: 48, ftpWatts: 250, cssSecPer100m: 95, vdot: 50,
  levels: { swim: SkillLevel.novice, bike: SkillLevel.advanced, run: SkillLevel.intermediate },
});
const equip = makeEquipment({ hasBike: true, bikeType: 'road', hasAeroBars: true, poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
const race = makeRace({ date: addDays(start, 12 * 7), format: 'olympic', priority: 'a', title: 'M' });
const avail = makeAvailability({ maxSessionsPerWeek: 6 });

describe('Objectif de temps → ambition du plan', () => {
  it('raceGoalGap : objectif ambitieux = behind, objectif large = ahead', () => {
    const hard = raceGoalGap(profile, equip, 'olympic', 6600); // 1h50 très ambitieux
    const easy = raceGoalGap(profile, equip, 'olympic', 12000); // 3h20 confortable
    expect(hard.verdict).toBe('behind');
    expect(easy.verdict).toBe('ahead');
    expect(hard.predictedSeconds).toBeGreaterThan(hard.goalSeconds);
  });

  it('objectif ambitieux → périodisation plus agressive (pic de charge supérieur)', () => {
    const noGoal = new PlanBuilder().buildOne(profile, equip, race, start, avail);
    const ambitious = new PlanBuilder().buildOne(profile, equip, { ...race, goalTimeSeconds: 6600 }, start, avail);
    const peak = (p: ReturnType<PlanBuilder['buildOne']>) =>
      Math.max(...p.weeks.filter((w) => w.phase !== 'taper').map((w) => planWeekLoad(p, w.index)));
    expect(peak(ambitious)).toBeGreaterThan(peak(noGoal));
    expect(ambitious.rationale.some((r) => r.includes('ambitieux'))).toBe(true);
  });
});

describe('Indisponibilité temporaire', () => {
  it('equipmentOn désactive la discipline sur la période', () => {
    const u = makeUnavailability({ from: start, to: addDays(start, 6), sports: ['bike'] });
    expect(canPractice(equipmentOn(equip, [u], addDays(start, 3)), 'bike')).toBe(false);
    expect(canPractice(equipmentOn(equip, [u], addDays(start, 10)), 'bike')).toBe(true); // hors période
  });

  it('plan : pas de vélo pendant la période, mais du vélo après', () => {
    const u = makeUnavailability({ from: start, to: addDays(start, 6), sports: ['bike'], reason: 'déplacement' });
    const plan = new PlanBuilder().build(profile, equip, [race], start, avail, { ...defaultPlanConfig(), unavailabilities: [u] });

    const inWindow = plan.sessions.filter((s) => s.date >= start && s.date < addDays(start, 7));
    expect(inWindow.length).toBeGreaterThan(0);
    expect(inWindow.some((s) => s.sport === 'bike' || s.sport === 'brick')).toBe(false);

    const afterWindow = plan.sessions.filter((s) => s.date >= addDays(start, 14) && s.date < addDays(start, 28));
    expect(afterWindow.some((s) => s.sport === 'bike')).toBe(true);

    expect(plan.rationale.some((r) => r.includes('indisponibilité'))).toBe(true);
  });
});
