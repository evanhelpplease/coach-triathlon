// Portage de Domain/Profile.swift.
import { ageYears } from '../util/dates';
import { vdotFromVMA } from '../predictions/vdot';
import type { BiologicalSex, Discipline, SkillLevel, Sport } from './types';

/** Profil physiologique de l'athlète. Référentiels optionnels, estimés si absents. */
export interface AthleteProfile {
  birthDate: Date;
  sex: BiologicalSex;
  heightCm: number;
  weightKg: number;
  hrMax?: number;
  hrRest?: number;
  ftpWatts?: number;
  cssSecPer100m?: number; // Critical Swim Speed
  vdot?: number; // Daniels (course)
  vma?: number; // Vitesse Maximale Aérobie (km/h) — test 6 min
  levels: Partial<Record<Discipline, SkillLevel>>;
}

export function makeProfile(
  p: Omit<Partial<AthleteProfile>, 'birthDate' | 'sex' | 'heightCm' | 'weightKg'> & {
    birthDate: Date;
    sex: BiologicalSex;
    heightCm: number;
    weightKg: number;
  },
): AthleteProfile {
  const profile: AthleteProfile = { levels: {}, ...p };
  // La VMA implique un VDOT : on le dérive si absent (les zones course en dépendent).
  if (profile.vma != null && profile.vdot == null) profile.vdot = vdotFromVMA(profile.vma);
  return profile;
}

/** Âge en années à une date de référence. */
export function age(profile: AthleteProfile, on: Date = new Date()): number {
  return ageYears(profile.birthDate, on);
}

/** FC max estimée si non mesurée — formule de Nes (2013) : 211 − 0,64·âge. */
export function estimatedHRMax(profile: AthleteProfile, on: Date = new Date()): number {
  return Math.round(211.0 - 0.64 * age(profile, on));
}

// MARK: - Blessures

export type BodyZone =
  | 'ankle'
  | 'knee'
  | 'hip'
  | 'lowerBack'
  | 'shoulder'
  | 'calf'
  | 'hamstring'
  | 'foot'
  | 'other';

export interface InjuryRecord {
  zone: BodyZone;
  intensity: number; // 1–5
  since: Date;
  affectedSports: Set<Sport>;
  /** Libellé de la douleur précise choisie (optionnel, informatif). */
  specific?: string;
}
