// Utilitaires de date en UTC, pour reproduire fidèlement le comportement de
// `Calendar(identifier: .gregorian)` du code Swift, de façon déterministe
// (indépendant du fuseau de la machine).

export const DAY_MS = 86_400_000;

/** Ajoute `n` jours (exactement n·86400 s, en UTC). */
export function addDays(date: Date, n: number): Date {
  return new Date(date.getTime() + n * DAY_MS);
}

/** Ajoute `n` secondes. */
export function addSeconds(date: Date, n: number): Date {
  return new Date(date.getTime() + n * 1000);
}

/** Minuit UTC du jour de `date`. */
export function startOfDay(date: Date): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

/** Jour de la semaine grégorien : 1 = dimanche … 7 = samedi (comme Swift). */
export function weekday(date: Date): number {
  return date.getUTCDay() + 1;
}

/** Deux dates tombent-elles le même jour (UTC) ? */
export function isSameDay(a: Date, b: Date): boolean {
  return startOfDay(a).getTime() === startOfDay(b).getTime();
}

/** Nombre de jours calendaires entre deux dates (composante `.day` de Swift). */
export function daysBetween(from: Date, to: Date): number {
  return Math.round((startOfDay(to).getTime() - startOfDay(from).getTime()) / DAY_MS);
}

/** Âge en années entières à une date de référence. */
export function ageYears(birth: Date, on: Date): number {
  let age = on.getUTCFullYear() - birth.getUTCFullYear();
  const m = on.getUTCMonth() - birth.getUTCMonth();
  if (m < 0 || (m === 0 && on.getUTCDate() < birth.getUTCDate())) age -= 1;
  return age;
}
