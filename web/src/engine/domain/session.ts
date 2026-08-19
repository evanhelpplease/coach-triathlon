// Portage de Domain/Session.swift.
import type { Sport, SessionIntent, TrainingPhase } from './types';

export type StepKind = 'warmup' | 'work' | 'recovery' | 'rest' | 'cooldown' | 'repeatBlock';

/** Cible d'un pas de séance (union discriminée = enum Swift à valeurs associées). */
export type StepTarget =
  | { kind: 'hrZone'; zone: number }
  | { kind: 'paceRange'; lowSecPerKm: number; highSecPerKm: number }
  | { kind: 'swimPaceRange'; lowSecPer100m: number; highSecPer100m: number }
  | { kind: 'powerRange'; lowW: number; highW: number }
  | { kind: 'rpe'; value: number }
  | { kind: 'free' };

export const Target = {
  hrZone: (zone: number): StepTarget => ({ kind: 'hrZone', zone }),
  paceRange: (lowSecPerKm: number, highSecPerKm: number): StepTarget => ({ kind: 'paceRange', lowSecPerKm, highSecPerKm }),
  swimPaceRange: (lowSecPer100m: number, highSecPer100m: number): StepTarget => ({ kind: 'swimPaceRange', lowSecPer100m, highSecPer100m }),
  powerRange: (lowW: number, highW: number): StepTarget => ({ kind: 'powerRange', lowW, highW }),
  rpe: (value: number): StepTarget => ({ kind: 'rpe', value }),
  free: (): StepTarget => ({ kind: 'free' }),
};

/** Durée d'un pas : temps, distance, ou longueurs de bassin. */
export type StepDuration =
  | { kind: 'time'; seconds: number }
  | { kind: 'distance'; meters: number }
  | { kind: 'lengths'; count: number; poolMeters: number };

export const Duration = {
  time: (seconds: number): StepDuration => ({ kind: 'time', seconds }),
  distance: (meters: number): StepDuration => ({ kind: 'distance', meters }),
  lengths: (count: number, poolMeters: number): StepDuration => ({ kind: 'lengths', count, poolMeters }),
};

/** Durée estimée en secondes, pour le calcul de charge et l'agenda. */
export function estimatedSeconds(d: StepDuration, paceSecPerKm: number | null): number {
  switch (d.kind) {
    case 'time':
      return d.seconds;
    case 'distance': {
      if (paceSecPerKm == null) return d.meters / 3.0; // défaut ~3 m/s
      return (d.meters / 1000.0) * paceSecPerKm;
    }
    case 'lengths': {
      const m = d.count * d.poolMeters;
      const pace = paceSecPerKm ?? 95.0 * 10; // ~1:35/100m → s/km équiv.
      return (m / 1000.0) * pace;
    }
  }
}

export interface WorkoutStep {
  kind: StepKind;
  duration: StepDuration;
  target: StepTarget;
  cue?: string;
  repeats?: number; // pour repeatBlock
  children?: WorkoutStep[];
}

export interface PlannedSession {
  id: string;
  date: Date;
  sport: Sport;
  intent: SessionIntent;
  title: string;
  steps: WorkoutStep[];
  estimatedLoad: number; // charge (TSS-like)
  estimatedDuration: number; // secondes
  notes: string;
  phase?: TrainingPhase;
}

let sessionCounter = 0;
export function newSessionId(): string {
  return `sess-${++sessionCounter}-${Math.random().toString(36).slice(2, 8)}`;
}

export function makePlannedSession(
  p: Omit<Partial<PlannedSession>, 'date' | 'sport' | 'intent' | 'title'> & {
    date: Date;
    sport: Sport;
    intent: SessionIntent;
    title: string;
  },
): PlannedSession {
  return {
    id: p.id ?? newSessionId(),
    steps: [],
    estimatedLoad: 0,
    estimatedDuration: 0,
    notes: '',
    ...p,
  };
}
