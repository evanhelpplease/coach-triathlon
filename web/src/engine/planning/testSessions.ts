// Séances de TEST de terrain pour établir les référentiels manquants
// (VMA course, FTP vélo, CSS natation). Portage de App/Planning/TestSessions.swift.
// Le résultat saisi recalcule le référentiel → zones + plan régénérés → le test disparaît.
import type { Sport } from '../domain/types';
import { makePlannedSession, Target, Duration, type PlannedSession, type WorkoutStep } from '../domain/session';
import { vdotFromVMA } from '../predictions/vdot';
import { pacePer100m } from '../predictions/css';

const TEST_PREFIX = 'Test ';

export function isTestSession(s: PlannedSession): boolean {
  return s.title.startsWith(TEST_PREFIX);
}

export function makeTestSession(sport: Sport, date: Date, poolMeters = 25): PlannedSession {
  switch (sport) {
    case 'bike': return bikeFTP(date);
    case 'swim': return swimCSS(date, poolMeters);
    default: return runVMA(date);
  }
}

// Course — test VMA (6 min max)
function runVMA(date: Date): PlannedSession {
  const steps: WorkoutStep[] = [
    { kind: 'warmup', duration: Duration.time(900), target: Target.rpe(4), cue: 'Échauffement progressif 15 min + 3 lignes droites' },
    { kind: 'work', duration: Duration.time(360), target: Target.rpe(10), cue: '6 min à la vitesse MAX régulière — note la distance parcourue' },
    { kind: 'cooldown', duration: Duration.time(600), target: Target.rpe(3), cue: 'Retour au calme 10 min' },
  ];
  return makePlannedSession({
    date, sport: 'run', intent: 'vo2', title: 'Test VMA (6 min)', steps,
    estimatedLoad: 55, estimatedDuration: 1860,
    notes: 'VMA ≈ distance(m) / 100. Saisis le résultat : le plan se recalibre.', phase: 'base',
  });
}

// Vélo — test FTP (20 min)
function bikeFTP(date: Date): PlannedSession {
  const steps: WorkoutStep[] = [
    { kind: 'warmup', duration: Duration.time(1200), target: Target.rpe(4), cue: '20 min échauffement dont 3×1 min vifs' },
    { kind: 'work', duration: Duration.time(1200), target: Target.rpe(9), cue: '20 min à la puissance MAX soutenable et RÉGULIÈRE — note la puissance moyenne' },
    { kind: 'cooldown', duration: Duration.time(600), target: Target.rpe(3), cue: '10 min retour au calme' },
  ];
  return makePlannedSession({
    date, sport: 'bike', intent: 'threshold', title: 'Test FTP (20 min)', steps,
    estimatedLoad: 70, estimatedDuration: 3000,
    notes: 'FTP ≈ 95 % de la puissance moyenne des 20 min.', phase: 'base',
  });
}

// Natation — test CSS (400 m + 200 m)
function swimCSS(date: Date, poolMeters: number): PlannedSession {
  const l = (m: number) => Math.max(1, Math.round(m / poolMeters));
  const steps: WorkoutStep[] = [
    { kind: 'warmup', duration: Duration.lengths(l(300), poolMeters), target: Target.rpe(4), cue: '300 m souple + éducatifs' },
    { kind: 'work', duration: Duration.lengths(l(400), poolMeters), target: Target.rpe(9), cue: '400 m contre-la-montre — note ton temps' },
    { kind: 'rest', duration: Duration.time(300), target: Target.free(), cue: '5 min récup complète' },
    { kind: 'work', duration: Duration.lengths(l(200), poolMeters), target: Target.rpe(9), cue: '200 m contre-la-montre — note ton temps' },
    { kind: 'cooldown', duration: Duration.lengths(l(200), poolMeters), target: Target.rpe(3), cue: '200 m décrassage' },
  ];
  return makePlannedSession({
    date, sport: 'swim', intent: 'threshold', title: 'Test CSS (400 m + 200 m)', steps,
    estimatedLoad: 45, estimatedDuration: 2400,
    notes: 'CSS (s/100m) = 100 × (400−200) / (T400−T200). Saisis tes deux temps.', phase: 'base',
  });
}

// MARK: - Recalibrage : convertit un résultat de test en référentiel.

/** VMA (test 6 min) : distance parcourue (m) → VMA (km/h). */
export function vmaFromTest(distanceM: number): number {
  return distanceM / 100; // VMA ≈ distance(m) sur 6 min / 100
}

/** VMA (test 6 min) : distance parcourue (m) → VDOT. */
export function vdotFromVMATest(distanceM: number): number {
  return vdotFromVMA(vmaFromTest(distanceM));
}

/** FTP (test 20 min) : puissance moyenne (W) → FTP. */
export function ftpFrom20minTest(avgPowerW: number): number {
  return Math.round(avgPowerW * 0.95);
}

/** CSS : temps 400 m et 200 m (s) → allure critique (s/100m). */
export function cssFromTest(t400Sec: number, t200Sec: number): number {
  return pacePer100m(400, t400Sec, 200, t200Sec);
}
