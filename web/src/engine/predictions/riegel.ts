// Portage de Predictions/Riegel.swift — T2 = T1·(D2/D1)^b, b ≈ 1.06.

export const RIEGEL_DEFAULT_EXPONENT = 1.06;

export function predictTimeSeconds(
  knownDistanceMeters: number,
  knownTimeSeconds: number,
  targetDistanceMeters: number,
  exponent: number = RIEGEL_DEFAULT_EXPONENT,
): number {
  if (!(knownDistanceMeters > 0 && knownTimeSeconds > 0 && targetDistanceMeters > 0)) {
    throw new Error('Riegel: distances & temps > 0');
  }
  return knownTimeSeconds * Math.pow(targetDistanceMeters / knownDistanceMeters, exponent);
}

/** Estime l'exposant de fatigue propre à l'athlète à partir de deux perfs. */
export function fittedExponent(d1: number, t1: number, d2: number, t2: number): number {
  if (!(d1 > 0 && t1 > 0 && d2 > 0 && t2 > 0 && d1 !== d2)) throw new Error('Riegel.fittedExponent: entrées invalides');
  return Math.log(t2 / t1) / Math.log(d2 / d1);
}

export const Riegel = { predictTimeSeconds, fittedExponent, defaultExponent: RIEGEL_DEFAULT_EXPONENT };
