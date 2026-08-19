// Portage de Domain/Activity.swift.
import type { DataSource, Sport } from './types';

/** Activité réellement réalisée (importée ou saisie manuellement). */
export interface CompletedActivity {
  id: string;
  sport: Sport;
  start: Date;
  duration: number; // secondes
  distanceM?: number;
  avgHr?: number;
  maxHr?: number;
  avgPowerW?: number;
  normalizedPowerW?: number;
  avgPaceSecPerKm?: number;
  hrDriftPct?: number;
  poolLengths?: number;
  rpe?: number;
  source: DataSource;
}

let activityCounter = 0;
export function newActivityId(): string {
  return `act-${++activityCounter}-${Math.random().toString(36).slice(2, 8)}`;
}

export function makeActivity(
  p: Omit<Partial<CompletedActivity>, 'sport' | 'start' | 'duration'> & {
    sport: Sport;
    start: Date;
    duration: number;
  },
): CompletedActivity {
  return { id: p.id ?? newActivityId(), source: 'manual', ...p };
}

/** Check-in subjectif quotidien (1–5, 5 = au top). */
export interface SubjectiveCheckin {
  form: number;
  sleepQuality: number;
  soreness: number; // 5 = aucune courbature
  motivation: number;
}

/** État de récupération d'un jour donné (objectif + subjectif). */
export interface DailyReadiness {
  date: Date;
  sleepHours?: number;
  hrRest?: number;
  hrvMs?: number;
  bodyBattery?: number;
  subjective?: SubjectiveCheckin;
}
