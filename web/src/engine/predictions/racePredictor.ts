// Portage de Predictions/RacePredictor.swift — prédiction de course assemblée.
import type { AthleteProfile } from '../domain/profile';
import type { Equipment } from '../domain/equipment';
import { bikeMeters, isTriathlon, runMeters, swimMeters, type RaceFormat } from '../domain/types';
import { predictTimeSeconds as vdotPredict } from './vdot';
import { predictTimeSeconds as cssPredict } from './css';
import { CyclingPowerModel } from './cyclingPower';

export interface RacePrediction {
  format: RaceFormat;
  swimSeconds: number | null;
  t1Seconds: number | null;
  bikeSeconds: number | null;
  t2Seconds: number | null;
  runSeconds: number;
  totalSeconds: number;
  /** Demi-largeur relative de l'IC (0.05 = ±5 %). */
  confidenceHalfWidth: number;
}

export function lowSeconds(p: RacePrediction): number {
  return p.totalSeconds * (1 - p.confidenceHalfWidth);
}
export function highSeconds(p: RacePrediction): number {
  return p.totalSeconds * (1 + p.confidenceHalfWidth);
}

/** Fraction de FTP soutenable sur la partie vélo selon le format. */
function bikeIntensity(f: RaceFormat): number {
  switch (f) {
    case 'sprint':
    case 'xs': return 0.95;
    case 'olympic': return 0.9;
    case 'half': return 0.83;
    case 'full': return 0.72;
    default: return 0.9;
  }
}

/** Pénalité d'allure course après le vélo. */
function runFatigueFactor(f: RaceFormat): number {
  switch (f) {
    case 'sprint':
    case 'xs': return 1.03;
    case 'olympic': return 1.05;
    case 'half': return 1.08;
    case 'full': return 1.13;
    default: return 1.0;
  }
}

/** Transitions estimées (s) par format. */
function transitions(f: RaceFormat): { t1: number; t2: number } {
  switch (f) {
    case 'xs':
    case 'sprint': return { t1: 60, t2: 45 };
    case 'olympic': return { t1: 90, t2: 60 };
    case 'half': return { t1: 150, t2: 90 };
    case 'full': return { t1: 240, t2: 150 };
    default: return { t1: 0, t2: 0 };
  }
}

function confidence(missing: number, base: number): number {
  return Math.min(0.25, base + missing * 0.05);
}

/** Écart entre le temps prédit (forme actuelle) et l'objectif de temps visé. */
export interface RaceGoalGap {
  goalSeconds: number;
  predictedSeconds: number;
  /** predit / objectif : > 1 = il faut progresser, < 1 = objectif déjà à portée. */
  ratio: number;
  deltaSeconds: number; // predit − objectif (positif = en retard sur l'objectif)
  verdict: 'ahead' | 'onTrack' | 'behind';
}

export function raceGoalGap(profile: AthleteProfile, equipment: Equipment, format: RaceFormat, goalSeconds: number): RaceGoalGap {
  const pred = new RacePredictor().predict(format, profile, equipment);
  const ratio = pred.totalSeconds / goalSeconds;
  const verdict: RaceGoalGap['verdict'] = ratio <= 0.99 ? 'ahead' : ratio <= 1.03 ? 'onTrack' : 'behind';
  return { goalSeconds, predictedSeconds: pred.totalSeconds, ratio, deltaSeconds: pred.totalSeconds - goalSeconds, verdict };
}

export class RacePredictor {
  predict(format: RaceFormat, profile: AthleteProfile, equipment: Equipment): RacePrediction {
    let missing = 0;

    // --- Course (toujours présente) ---
    const vdotValue = profile.vdot ?? 45; // défaut prudent si inconnu
    if (profile.vdot == null) missing += 1;
    const openRun = vdotPredict(vdotValue, runMeters(format));
    const run = isTriathlon(format) ? openRun * runFatigueFactor(format) : openRun;

    if (!isTriathlon(format)) {
      return {
        format,
        swimSeconds: null,
        t1Seconds: null,
        bikeSeconds: null,
        t2Seconds: null,
        runSeconds: run,
        totalSeconds: run,
        confidenceHalfWidth: confidence(missing, 0.04),
      };
    }

    // --- Natation ---
    const swimDist = swimMeters(format)!;
    const cssPace = profile.cssSecPer100m ?? 120; // 2:00/100m défaut
    if (profile.cssSecPer100m == null) missing += 1;
    let swim = cssPredict(cssPace, swimDist);
    if (equipment.hasWetsuit) swim *= 0.96; // combinaison ≈ −4 %

    // --- Vélo ---
    const bikeDist = bikeMeters(format)!;
    const ftp = profile.ftpWatts ?? 200;
    if (profile.ftpWatts == null) missing += 1;
    const cda = CyclingPowerModel.typicalCdA(equipment.bikeType ?? 'road', equipment.hasAeroBars);
    const mass = profile.weightKg + (equipment.bikeWeightKg ?? 9.0);
    const model = new CyclingPowerModel({ totalMassKg: mass, cda });
    const bike = model.predictTimeSeconds(bikeDist, ftp * bikeIntensity(format));

    const tr = transitions(format);
    const total = swim + tr.t1 + bike + tr.t2 + run;

    return {
      format,
      swimSeconds: swim,
      t1Seconds: tr.t1,
      bikeSeconds: bike,
      t2Seconds: tr.t2,
      runSeconds: run,
      totalSeconds: total,
      confidenceHalfWidth: confidence(missing, 0.05),
    };
  }
}
