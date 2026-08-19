import { describe, it, expect } from 'vitest';
import {
  Adapter,
  ZoneCalculator,
  makeProfile,
  makeEquipment,
  makePlannedSession,
  addDays,
  type SessionIntent,
  type PlannedSession,
  type LoadPoint,
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
const equip = makeEquipment({ hasBike: true, bikeType: 'road', hasAeroBars: true, poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
const zones = new ZoneCalculator().zones(profile);

function rSession(d: number, load = 90, intent: SessionIntent = 'vo2'): PlannedSession {
  return makePlannedSession({ date: addDays(start, d), sport: 'run', intent, title: 'Course', estimatedLoad: load, estimatedDuration: 3600, phase: 'build' });
}

const hist: DailyReadiness[] = Array.from({ length: 7 }, (_, i) => ({ date: addDays(start, i), sleepHours: 8, hrRest: 48, hrvMs: 80 }));

describe("Moteur d'adaptation", () => {
  it('blessure genou : course → natation + rappel médical', () => {
    const res = new Adapter().adapt({
      today: start,
      upcoming: [rSession(1)],
      injuries: [{ zone: 'knee', intensity: 4, since: start, affectedSports: new Set(['run']) }],
      equipment: equip,
      profile,
      zones,
    });
    expect(res.plan[0]?.sport).toBe('swim');
    expect(res.events.find((e) => e.kind === 'injuryAdjusted')?.message).toContain('avis médical');
  });

  it('récupération basse → séance allégée en récupération', () => {
    const res = new Adapter().adapt({
      today: start,
      upcoming: [rSession(0)],
      readinessToday: { date: start, sleepHours: 5, hrRest: 60, hrvMs: 40, subjective: { form: 1, sleepQuality: 1, soreness: 1, motivation: 1 } },
      readinessHistory: hist,
      equipment: equip,
      profile,
      zones,
    });
    expect(res.plan[0]?.intent).toBe('recovery');
  });

  it('ACWR 1.7 → décharge appliquée', () => {
    const recentLoad: LoadPoint[] = [{ date: start, dailyLoad: 100, ctl: 60, atl: 95, tsb: -35, acwr: 1.7 }];
    const res = new Adapter().adapt({ today: start, upcoming: [rSession(1, 100)], recentLoad, equipment: equip, profile, zones });
    expect(res.events.some((e) => e.kind === 'deload')).toBe(true);
    expect(res.plan[0]!.estimatedLoad).toBeLessThan(100);
  });

  it('séance manquée (frais) → replanifiée', () => {
    const recentLoad: LoadPoint[] = [{ date: start, dailyLoad: 40, ctl: 50, atl: 45, tsb: 5, acwr: 1.0 }];
    const res = new Adapter().adapt({ today: start, upcoming: [], missed: [rSession(-1, 70)], recentLoad, equipment: equip, profile, zones });
    expect(res.events.some((e) => e.kind === 'rescheduled')).toBe(true);
  });
});
