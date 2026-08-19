// Mesure de polarisation (80/20) par le TEMPS passé en intensité, et non par
// séance entière : dans une séance de VO2/seuil, seule la fraction "travail"
// compte comme dur (échauffement/récup/retour au calme restent en aérobie).
import type { PlannedSession } from '../domain/session';
import type { SessionIntent } from '../domain/types';

/** Fraction de la durée d'une séance réellement passée à haute intensité, par intention. */
const HARD_FRACTION: Partial<Record<SessionIntent, number>> = {
  threshold: 0.5,
  vo2: 0.35,
  sprint: 0.2,
  tempo: 0.25, // zone grise, comptée partiellement
};

export function sessionHardSeconds(s: PlannedSession): number {
  return s.estimatedDuration * (HARD_FRACTION[s.intent] ?? 0);
}

export interface Polarization {
  hardSeconds: number;
  easySeconds: number;
  totalSeconds: number;
  /** Part du temps en aérobie facile (viser ≥ ~0.75 pour du polarisé). */
  easyFraction: number;
}

export function polarization(sessions: PlannedSession[]): Polarization {
  const totalSeconds = sessions.reduce((a, s) => a + s.estimatedDuration, 0);
  const hardSeconds = sessions.reduce((a, s) => a + sessionHardSeconds(s), 0);
  return {
    hardSeconds,
    easySeconds: totalSeconds - hardSeconds,
    totalSeconds,
    easyFraction: totalSeconds > 0 ? 1 - hardSeconds / totalSeconds : 1,
  };
}
