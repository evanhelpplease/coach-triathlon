import { describe, it, expect } from 'vitest';
import {
  PostSessionAnalyzer,
  PersonalRecords,
  RaceNutrition,
  RacePacing,
  raceFueling,
  makeProfile,
  makeActivity,
  addDays,
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

describe('Analyse post-séance & records', () => {
  const doneRun = makeActivity({ sport: 'run', start, duration: 3000, distanceM: 9000, avgHr: 150, avgPaceSecPerKm: 320, hrDriftPct: 3.5 });
  const histRun = [
    makeActivity({ sport: 'run', start: addDays(start, -1), duration: 2700, distanceM: 7000, avgPaceSecPerKm: 350 }),
    makeActivity({ sport: 'run', start: addDays(start, -2), duration: 2700, distanceM: 6000, avgPaceSecPerKm: 345 }),
  ];

  it('analyse : titre non vide, dérive faible et progression détectées', () => {
    const a = new PostSessionAnalyzer().analyze(doneRun, profile, histRun);
    expect(a.headline.length).toBeGreaterThan(0);
    expect(a.insights.some((s) => s.includes('Dérive'))).toBe(true);
    expect(a.insights.some((s) => s.includes('progresse'))).toBe(true);
  });

  it('records : plus longue distance et meilleure allure course', () => {
    const records = new PersonalRecords().compute([doneRun, ...histRun]);
    expect(records.some((r) => r.sportKey === 'run' && r.label.includes('distance'))).toBe(true);
    expect(records.some((r) => r.label.includes('allure'))).toBe(true);
  });
});

describe('Stratégie de course', () => {
  it('nutrition : glucides/h et total croissent avec la durée', () => {
    const shortN = RaceNutrition.plan(3600, 72, 'sprint');
    const longN = RaceNutrition.plan(11 * 3600, 72, 'full');
    expect(longN.carbsPerHour).toBeGreaterThan(shortN.carbsPerHour);
    expect(longN.totalCarbs).toBeGreaterThan(shortN.totalCarbs);
  });

  it('pacing : 3 cibles pour un triathlon, vélo en % FTP', () => {
    const pacing = RacePacing.targets('olympic', profile);
    expect(pacing.length).toBe(3);
    expect(pacing.some((p) => p.sportKey === 'bike' && p.value.includes('FTP'))).toBe(true);
  });

  it('ravitaillement : gels et liquide croissent avec la durée', () => {
    const shortR = raceFueling('sprint', 3600, 72);
    const longR = raceFueling('full', 11 * 3600, 72);
    expect(longR.during.gels).toBeGreaterThan(shortR.during.gels);
    expect(longR.during.bidons).toBeGreaterThanOrEqual(shortR.during.bidons);
    expect(shortR.weekBefore.length).toBeGreaterThan(0);
    expect(longR.raceMorning.length).toBeGreaterThan(0);
  });
});
