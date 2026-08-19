// Portage de RaceStrategy/RaceStrategy.swift — nutrition + pacing.
import type { AthleteProfile } from '../domain/profile';
import { isTriathlon, runMeters, type RaceFormat } from '../domain/types';
import { trainingPaces } from '../predictions/vdot';

export interface NutritionPlan {
  carbsPerHour: number; // g/h
  totalCarbs: number; // g
  fluidPerHour: number; // ml/h
  sodiumPerHour: number; // mg/h
  summary: string;
}

function mmss(sec: number): string {
  const s = Math.round(sec);
  return `${Math.trunc(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export const RaceNutrition = {
  plan(durationSec: number, weightKg: number, format: RaceFormat): NutritionPlan {
    void weightKg; // conservé pour parité de signature
    void format;
    const hours = Math.max(0.25, durationSec / 3600);

    let carbsPerHour: number;
    if (hours < 1.0) carbsPerHour = 30;
    else if (hours < 2.0) carbsPerHour = 55;
    else if (hours < 3.5) carbsPerHour = 70;
    else if (hours < 6.0) carbsPerHour = 80;
    else carbsPerHour = 90;

    const total = Math.round(carbsPerHour * hours);
    const fluidPerHour = hours > 4 ? 700 : 550;
    const sodiumPerHour = hours > 3 ? 700 : 500;

    let summary: string;
    if (hours < 1.2) {
      summary = "Course courte : privilégie l'apport la veille et 30–60 g de glucides 1 h avant. Pendant : hydratation + éventuellement un gel.";
    } else if (hours < 3.5) {
      summary = `Vise ${carbsPerHour} g de glucides/h dès la partie vélo (gels, boisson, barres). Bois régulièrement par petites gorgées.`;
    } else {
      summary = `Format long : ${carbsPerHour} g/h de glucides, ${fluidPerHour} ml/h de liquide, ${sodiumPerHour} mg/h de sodium. Anticipe dès le début, n'attends pas la sensation de faim.`;
    }
    return { carbsPerHour, totalCarbs: total, fluidPerHour, sodiumPerHour, summary };
  },
};

// MARK: - Plan de ravitaillement (semaine avant + jour J)

export interface RaceFueling {
  weekBefore: string[];
  raceMorning: string[];
  during: {
    carbsPerHour: number;
    gels: number;
    carbsPerGel: number;
    fluidMl: number;
    bidons: number;
    sodiumMg: number;
    note: string;
  };
}

export function raceFueling(format: RaceFormat, durationSec: number, weightKg: number): RaceFueling {
  const plan = RaceNutrition.plan(durationSec, weightKg, format);
  const hours = Math.max(0.4, durationSec / 3600);
  const carbsPerGel = 25;
  const gels = Math.max(0, Math.round(plan.totalCarbs / carbsPerGel));
  const fluidMl = Math.round(plan.fluidPerHour * hours);
  const bidons = Math.max(1, Math.round(fluidMl / 500));
  const long = hours >= 2.5;
  const veryLong = hours >= 5;

  const weekBefore: string[] = [
    'J-7 à J-3 : entraînement allégé (affûtage), sommeil prioritaire, hydratation régulière.',
    long
      ? `J-2 et J-1 : recharge glucidique progressive (~7–10 g/kg/j, soit ${Math.round(weightKg * 8)}–${Math.round(weightKg * 10)} g/j), réduis les fibres.`
      : 'J-1 : repas riche en glucides le midi et le soir, pauvre en fibres/gras.',
    'J-1 : évite toute nouveauté alimentaire, prépare et teste ton matériel, hydrate-toi avec des électrolytes.',
  ];
  if (veryLong) weekBefore.push("Prépare tes ravitaillements à l'avance (gels, bidons, sel) et répartis-les sur le parcours.");

  const raceMorning: string[] = [
    `3 h avant : petit-déjeuner riche en glucides (~${Math.round(weightKg * 1.5)}–${Math.round(weightKg * 2)} g), pauvre en fibres/gras (pain-miel, banane, boisson d'attente).`,
    "30–60 min avant : petite collation glucidique (gel ou barre) + quelques gorgées d'eau.",
  ];
  if (hours < 1.2) raceMorning.push("Course courte : l'essentiel se joue avant. Pendant : hydratation, éventuellement 1 gel.");

  const note = hours < 1.2
    ? "Format court : peu d'apport pendant, surtout de l'hydratation."
    : `Vise ${plan.carbsPerHour} g de glucides/h dès le début, régulièrement (pas tout d'un coup).`;

  return {
    weekBefore,
    raceMorning,
    during: { carbsPerHour: plan.carbsPerHour, gels, carbsPerGel, fluidMl, bidons, sodiumMg: plan.sodiumPerHour, note },
  };
}

export interface PacingTarget {
  sportKey: string;
  label: string;
  value: string;
  note: string;
}

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
function runFatigue(f: RaceFormat): number {
  switch (f) {
    case 'sprint':
    case 'xs': return 1.03;
    case 'olympic': return 1.05;
    case 'half': return 1.08;
    case 'full': return 1.13;
    default: return 1.0;
  }
}

export const RacePacing = {
  targets(format: RaceFormat, profile: AthleteProfile): PacingTarget[] {
    const out: PacingTarget[] = [];
    const tri = isTriathlon(format);

    if (tri && profile.cssSecPer100m != null) {
      const pace = profile.cssSecPer100m + (format === 'full' ? 6 : 3);
      out.push({
        sportKey: 'swim',
        label: 'Allure natation',
        value: `${mmss(pace)}/100m`,
        note: 'Départ contrôlé, respiration régulière. Ne pars pas trop vite.',
      });
    }
    if (tri && profile.ftpWatts != null) {
      const intensity = bikeIntensity(format);
      const power = Math.trunc(profile.ftpWatts * intensity);
      out.push({
        sportKey: 'bike',
        label: 'Puissance vélo',
        value: `${power} W (${Math.trunc(intensity * 100)} % FTP)`,
        note: 'Puissance lissée, évite les à-coups. Économise pour la course à pied.',
      });
    }
    if (profile.vdot != null) {
      const fatigue = tri ? runFatigue(format) : 1.0;
      const base = trainingPaces(profile.vdot);
      const racePace = (runMeters(format) <= 10_000 ? base.thresholdSecPerKm : base.marathonSecPerKm) * fatigue;
      out.push({
        sportKey: 'run',
        label: 'Allure course',
        value: `${mmss(racePace)}/km`,
        note: tri ? 'Les jambes seront lourdes au début : monte en allure progressivement.' : 'Allure régulière, negative split si possible.',
      });
    }
    return out;
  },
};
