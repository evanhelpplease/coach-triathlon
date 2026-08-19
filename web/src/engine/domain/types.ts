// Types de base du domaine — portage de Domain/CoreTypes.swift.

export type Sport = 'swim' | 'bike' | 'run' | 'strength' | 'brick';
export const ALL_SPORTS: Sport[] = ['swim', 'bike', 'run', 'strength', 'brick'];

export type Discipline = 'swim' | 'bike' | 'run';
export const ALL_DISCIPLINES: Discipline[] = ['swim', 'bike', 'run'];

/** Niveau de compétence (Comparable via l'ordre numérique). */
export enum SkillLevel {
  beginner = 0,
  novice = 1,
  intermediate = 2,
  advanced = 3,
  expert = 4,
}

export type BiologicalSex = 'male' | 'female' | 'other';

export type BikeType = 'road' | 'tt' | 'gravel' | 'mtb' | 'trainer';

export type DataSource = 'appleHealth' | 'garmin' | 'manual' | 'generated';

export type TrainingPhase = 'base' | 'build' | 'specific' | 'taper' | 'recovery';
export const ALL_PHASES: TrainingPhase[] = ['base', 'build', 'specific', 'taper', 'recovery'];

export type SessionIntent =
  | 'recovery'
  | 'endurance'
  | 'tempo'
  | 'threshold'
  | 'vo2'
  | 'sprint'
  | 'technique'
  | 'brick'
  | 'strength';

export type RacePriority = 'a' | 'b' | 'c';

/** Volonté de progression : arbitre la rampe de charge et le volume d'intensité. */
export type ProgressionLevel = 'prudent' | 'balanced' | 'performance';

export type RaceFormat =
  // triathlon
  | 'xs'
  | 'sprint'
  | 'olympic'
  | 'half'
  | 'full'
  // mono-sport course
  | 'run10k'
  | 'halfMarathon'
  | 'marathon';

export const ALL_RACE_FORMATS: RaceFormat[] = [
  'xs', 'sprint', 'olympic', 'half', 'full', 'run10k', 'halfMarathon', 'marathon',
];

/** Distance natation (m) du format, ou null si non concerné. */
export function swimMeters(f: RaceFormat): number | null {
  switch (f) {
    case 'xs': return 400;
    case 'sprint': return 750;
    case 'olympic': return 1500;
    case 'half': return 1900;
    case 'full': return 3800;
    default: return null;
  }
}

/** Distance vélo (m) du format, ou null si non concerné. */
export function bikeMeters(f: RaceFormat): number | null {
  switch (f) {
    case 'xs': return 10_000;
    case 'sprint': return 20_000;
    case 'olympic': return 40_000;
    case 'half': return 90_000;
    case 'full': return 180_000;
    default: return null;
  }
}

/** Distance course (m) du format. */
export function runMeters(f: RaceFormat): number {
  switch (f) {
    case 'xs': return 2_500;
    case 'sprint': return 5_000;
    case 'olympic': return 10_000;
    case 'half': return 21_097.5;
    case 'full': return 42_195;
    case 'run10k': return 10_000;
    case 'halfMarathon': return 21_097.5;
    case 'marathon': return 42_195;
  }
}

export function isTriathlon(f: RaceFormat): boolean {
  return swimMeters(f) !== null;
}
