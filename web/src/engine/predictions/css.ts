// Portage de Predictions/CSS.swift — Critical Swim Speed.

export function speedMetersPerSec(
  longDistanceM: number,
  longTimeSec: number,
  shortDistanceM: number,
  shortTimeSec: number,
): number {
  if (!(longDistanceM > shortDistanceM && longTimeSec > shortTimeSec)) throw new Error('CSS: long > court');
  return (longDistanceM - shortDistanceM) / (longTimeSec - shortTimeSec);
}

/** Allure critique en secondes / 100 m. */
export function pacePer100m(
  longDistanceM: number,
  longTimeSec: number,
  shortDistanceM: number,
  shortTimeSec: number,
): number {
  const v = speedMetersPerSec(longDistanceM, longTimeSec, shortDistanceM, shortTimeSec);
  return 100.0 / v;
}

/** Convertit une allure (s/100 m) en vitesse (m/s). */
export function speedFromPacePer100m(pace: number): number {
  return 100.0 / pace;
}

/** Prédit un temps (s) sur une distance (m) à partir de la CSS, avec dérive de fatigue. */
export function predictTimeSeconds(cssPacePer100m: number, distanceM: number): number {
  const v = speedFromPacePer100m(cssPacePer100m);
  const ref = 400.0;
  const drift = distanceM > ref ? Math.pow(distanceM / ref, 0.02) : 1.0;
  return (distanceM / v) * drift;
}

export const CSS = { speedMetersPerSec, pacePer100m, speedFromPacePer100m, predictTimeSeconds };
