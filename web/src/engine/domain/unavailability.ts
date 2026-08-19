// Indisponibilité temporaire : sur une période donnée, certaines disciplines ne
// sont pas praticables (ex. en déplacement, pas d'accès vélo/piscine du XX au XX).
// Le plan convertit alors ces séances via la substitution matériel existante.
import type { Sport } from './types';
import type { Equipment } from './equipment';
import { startOfDay } from '../util/dates';

export interface TemporaryUnavailability {
  id: string;
  from: Date;
  to: Date; // inclus (au jour près)
  sports: Sport[]; // disciplines indisponibles sur la période
  reason?: string;
}

let unavailCounter = 0;
export function makeUnavailability(p: Omit<TemporaryUnavailability, 'id'> & { id?: string }): TemporaryUnavailability {
  return { id: p.id ?? `unav-${++unavailCounter}-${Date.now()}`, ...p };
}

/** La période couvre-t-elle ce jour ? (bornes incluses, au jour près) */
export function coversDate(u: TemporaryUnavailability, date: Date): boolean {
  const d = startOfDay(date).getTime();
  return d >= startOfDay(u.from).getTime() && d <= startOfDay(u.to).getTime();
}

/** Un sport est-il indisponible ce jour-là ? */
export function sportUnavailableOn(unavailabilities: TemporaryUnavailability[], sport: Sport, date: Date): boolean {
  return unavailabilities.some((u) => u.sports.includes(sport) && coversDate(u, date));
}

/**
 * Matériel « effectif » à une date : désactive les disciplines rendues
 * indisponibles ce jour-là → `canPractice` renvoie false → substitution.
 */
export function equipmentOn(base: Equipment, unavailabilities: TemporaryUnavailability[], date: Date): Equipment {
  const active = unavailabilities.filter((u) => coversDate(u, date));
  if (active.length === 0) return base;
  const disabled = new Set<Sport>(active.flatMap((u) => u.sports));
  if (disabled.size === 0) return base;

  const e: Equipment = { ...base };
  if (disabled.has('swim')) {
    e.poolAccess = false;
    e.openWaterAccess = false;
  }
  if (disabled.has('bike')) e.hasBike = false;
  if (disabled.has('run')) {
    e.runOutdoor = false;
    e.hasTreadmill = false;
    e.hasTrack = false;
  }
  if (disabled.has('strength')) e.strengthAccess = 'none';
  return e;
}
