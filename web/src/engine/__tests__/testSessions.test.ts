import { describe, it, expect } from 'vitest';
import {
  PlanBuilder, makeAvailability, makeProfile, makeEquipment, makeRace, addDays, startOfDay, isTestSession,
  vdotFromVMATest, ftpFrom20minTest, cssFromTest,
} from '../index';

const start = startOfDay(new Date(0));
const equip = makeEquipment({ hasBike: true, bikeType: 'road', poolAccess: true, runOutdoor: true, strengthAccess: 'homeWeights' });
const race = makeRace({ date: addDays(start, 12 * 7), format: 'olympic', priority: 'a', title: 'M' });

describe('Séances de test & recalibrage', () => {
  it('référentiels manquants → un test de terrain par discipline, tôt', () => {
    const profile = makeProfile({ birthDate: new Date(Date.UTC(1995, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48 });
    const plan = new PlanBuilder().buildOne(profile, equip, race, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    const tests = plan.sessions.filter(isTestSession);
    expect(new Set(tests.map((s) => s.sport))).toEqual(new Set(['run', 'bike', 'swim']));
    // Tous placés dans les 10 premiers jours.
    expect(tests.every((s) => s.date < addDays(start, 10))).toBe(true);
  });

  it('référentiels complets → aucun test', () => {
    const profile = makeProfile({ birthDate: new Date(Date.UTC(1995, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48, vdot: 51, ftpWatts: 255, cssSecPer100m: 96 });
    const plan = new PlanBuilder().buildOne(profile, equip, race, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    expect(plan.sessions.filter(isTestSession).length).toBe(0);
  });

  it('sport indisponible → pas de test pour ce sport', () => {
    const noPool = makeEquipment({ hasBike: true, bikeType: 'road', poolAccess: false, openWaterAccess: false, runOutdoor: true });
    const profile = makeProfile({ birthDate: new Date(Date.UTC(1995, 0, 1)), sex: 'male', heightCm: 178, weightKg: 71, hrMax: 190, hrRest: 48 });
    const plan = new PlanBuilder().buildOne(profile, noPool, race, start, makeAvailability({ maxSessionsPerWeek: 6 }));
    const sports = new Set(plan.sessions.filter(isTestSession).map((s) => s.sport));
    expect(sports.has('swim')).toBe(false);
    expect(sports.has('run')).toBe(true);
  });

  it('calculs de recalibrage cohérents', () => {
    expect(vdotFromVMATest(1500)).toBeCloseTo(47.5, 0); // 15 km/h → VDOT ~47.5
    expect(ftpFrom20minTest(220)).toBe(209); // 95 %
    // 400 m en 6:30, 200 m en 3:05 → v = 200/205 m/s → CSS = 100·205/200 = 102.5 s/100m
    expect(cssFromTest(390, 185)).toBeCloseTo(102.5, 1);
  });
});
