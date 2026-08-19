import { describe, it, expect } from 'vitest';
import {
  PlanBuilder, makeAvailability, makeProfile, makeEquipment, makeRace, makeProfile as mkP,
  vdotFromVMA, vo2Cost, isTestSession, addDays, startOfDay, SkillLevel,
  type PlannedSession, type TrainingPhase,
} from '../index';

const start = startOfDay(new Date(0));
const equip = makeEquipment({ hasBike: true, bikeType: 'road', poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
const avail = makeAvailability({ maxSessionsPerWeek: 6 });
const race = makeRace({ date: addDays(start, 12 * 7), format: 'olympic', priority: 'a', title: 'M' });

describe('VMA', () => {
  it('vdotFromVMA = VO2 à la vitesse VMA', () => {
    expect(vdotFromVMA(16.5)).toBeCloseTo(vo2Cost((16.5 * 1000) / 60), 6);
    expect(vdotFromVMA(18)).toBeGreaterThan(vdotFromVMA(15)); // plus rapide = VDOT plus haut
  });

  it('makeProfile dérive le VDOT depuis la VMA si absent, sinon garde le VDOT', () => {
    const fromVma = mkP({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, vma: 16.5 });
    expect(fromVma.vdot).toBeCloseTo(vdotFromVMA(16.5), 6);
    const explicit = mkP({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, vma: 16.5, vdot: 60 });
    expect(explicit.vdot).toBe(60);
  });

  it('VMA renseignée → pas de test course (référentiel course connu)', () => {
    const p = makeProfile({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48, vma: 16.5 });
    const plan = new PlanBuilder().buildOne(p, equip, race, start, avail);
    expect(plan.sessions.filter(isTestSession).some((s) => s.sport === 'run')).toBe(false);
  });

  it('aucun référentiel course → test VMA planifié', () => {
    const p = makeProfile({ birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48 });
    const plan = new PlanBuilder().buildOne(p, equip, race, start, avail);
    const runTest = plan.sessions.filter(isTestSession).find((s) => s.sport === 'run');
    expect(runTest?.title).toContain('VMA');
  });
});

// Allure course la plus rapide (paceRange.lowSecPerKm) trouvée dans un ensemble de phases.
function fastestRunPace(plan: ReturnType<PlanBuilder['buildOne']>, phases: TrainingPhase[]): number {
  const weekOf = (d: Date) => plan.weeks.find((w) => d >= w.startDate && d < addDays(w.startDate, 7));
  let best = Infinity;
  const scan = (s: PlannedSession) => {
    if (s.sport !== 'run') return;
    const w = weekOf(s.date);
    if (!w || !phases.includes(w.phase)) return;
    for (const st of s.steps) {
      const kids = st.kind === 'repeatBlock' && st.children ? st.children : [st];
      for (const k of kids) if (k.target.kind === 'paceRange') best = Math.min(best, k.target.lowSecPerKm);
    }
  };
  plan.sessions.forEach(scan);
  return best;
}

describe("Objectif → allures cibles spécifiques (progressives et plafonnées)", () => {
  const profile = makeProfile({
    birthDate: new Date(Date.UTC(1990, 0, 1)), sex: 'male', heightCm: 180, weightKg: 72,
    hrMax: 190, hrRest: 48, ftpWatts: 250, cssSecPer100m: 95, vdot: 50,
    levels: { swim: SkillLevel.novice, bike: SkillLevel.advanced, run: SkillLevel.intermediate },
  });

  it('objectif ambitieux → allures spécifiques plus rapides, base inchangée, écart plafonné', () => {
    const withGoal = new PlanBuilder().buildOne(profile, equip, { ...race, goalTimeSeconds: 6600 }, start, avail);
    const noGoal = new PlanBuilder().buildOne(profile, equip, race, start, avail);

    const specGoal = fastestRunPace(withGoal, ['specific', 'taper']);
    const specNo = fastestRunPace(noGoal, ['specific', 'taper']);
    const baseGoal = fastestRunPace(withGoal, ['base']);
    const baseNo = fastestRunPace(noGoal, ['base']);

    // Spécifique : plus rapide (allure plus basse en s/km) avec objectif.
    expect(specGoal).toBeLessThan(specNo);
    // Base : inchangée (les fondations ne sont pas dénaturées).
    expect(baseGoal).toBeCloseTo(baseNo, 0);
    // Plafonné : l'amélioration d'allure reste ≤ ~12 % (atteignable).
    expect(specNo / specGoal).toBeLessThan(1.12);
    expect(specNo / specGoal).toBeGreaterThan(1.0);
  });
});
