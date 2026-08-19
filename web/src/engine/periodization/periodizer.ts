// Portage de Periodization/Periodizer.swift.
import type { Race } from '../domain/equipment';
import type { ProgressionLevel, RaceFormat, TrainingPhase } from '../domain/types';
import { addDays, daysBetween } from '../util/dates';

export interface PlannedWeek {
  index: number; // 0 = première semaine
  startDate: Date;
  phase: TrainingPhase;
  targetLoad: number; // charge hebdo cible (TSS-like)
  isDeload: boolean;
  rationale: string;
}

export interface PeriodizerConfig {
  startingWeeklyLoad: number;
  weeklyRampRate: number; // ex. 0.08 = +8 %/sem
  deloadEvery: number;
  deloadFactor: number;
}

export function defaultPeriodizerConfig(): PeriodizerConfig {
  return { startingWeeklyLoad: 300, weeklyRampRate: 0.08, deloadEvery: 4, deloadFactor: 0.6 };
}

/** Réglages selon la volonté de progression. */
export function configForProgression(level: ProgressionLevel, startingWeeklyLoad = 300): PeriodizerConfig {
  switch (level) {
    case 'prudent': return { startingWeeklyLoad, weeklyRampRate: 0.05, deloadEvery: 3, deloadFactor: 0.55 };
    case 'balanced': return { startingWeeklyLoad, weeklyRampRate: 0.08, deloadEvery: 4, deloadFactor: 0.6 };
    case 'performance': return { startingWeeklyLoad, weeklyRampRate: 0.11, deloadEvery: 4, deloadFactor: 0.65 };
  }
}

function taperWeeks(format: RaceFormat): number {
  switch (format) {
    case 'full': return 3;
    case 'half':
    case 'marathon': return 2;
    default: return 1;
  }
}

function rationale(phase: TrainingPhase, isDeload: boolean): string {
  if (isDeload) return 'Semaine de décharge : on assimile le travail, la forme remonte.';
  switch (phase) {
    case 'base': return 'Base : volume aérobie et technique, fondations posées.';
    case 'build': return "Build : on introduit le seuil et l'intensité spécifique.";
    case 'specific': return 'Spécifique : allure course et enchaînements ciblés.';
    case 'taper': return 'Affûtage : charge réduite, fraîcheur maximale pour le jour J.';
    case 'recovery': return 'Récupération.';
  }
}

export class Periodizer {
  plan(start: Date, race: Race, config: PeriodizerConfig = defaultPeriodizerConfig()): PlannedWeek[] {
    const days = daysBetween(start, race.date);
    const totalWeeks = Math.max(1, Math.ceil(days / 7.0));
    const taper = Math.min(taperWeeks(race.format), Math.max(1, totalWeeks - 1));
    const buildAndBase = totalWeeks - taper;

    const baseCount = Math.round(buildAndBase * 0.5);
    const buildCount = Math.round(buildAndBase * 0.3);

    const phaseFor = (weekIndex: number): TrainingPhase => {
      if (weekIndex >= totalWeeks - taper) return 'taper';
      if (weekIndex < baseCount) return 'base';
      if (weekIndex < baseCount + buildCount) return 'build';
      return 'specific';
    };

    const weeks: PlannedWeek[] = [];
    let progressiveLoad = config.startingWeeklyLoad;

    for (let w = 0; w < totalWeeks; w++) {
      const ph = phaseFor(w);
      const isDeload = (w + 1) % config.deloadEvery === 0 && ph !== 'taper';
      const weekStart = addDays(start, w * 7);

      let load: number;
      if (ph === 'taper') {
        const posInTaper = w - (totalWeeks - taper); // 0..taper-1
        const factor = 0.6 - 0.15 * posInTaper;
        load = progressiveLoad * Math.max(0.3, factor);
      } else if (isDeload) {
        load = progressiveLoad * config.deloadFactor;
      } else {
        load = progressiveLoad;
        progressiveLoad *= 1 + config.weeklyRampRate;
      }

      weeks.push({
        index: w,
        startDate: weekStart,
        phase: ph,
        targetLoad: Math.round(load),
        isDeload,
        rationale: rationale(ph, isDeload),
      });
    }
    return weeks;
  }
}
