// Portage de Predictions/VDOT.swift — modèle VDOT de Jack Daniels.

export interface TrainingPaces {
  easySecPerKm: number;
  marathonSecPerKm: number;
  thresholdSecPerKm: number;
  intervalSecPerKm: number;
  repetitionSecPerKm: number;
}

/** Coût en O₂ (ml/kg/min) d'une vitesse en m/min. */
export function vo2Cost(velocityMetersPerMin: number): number {
  const v = velocityMetersPerMin;
  return -4.6 + 0.182258 * v + 0.000104 * v * v;
}

/** Fraction de VO₂max soutenable pour une durée (minutes). */
export function fractionOfMax(durationMin: number): number {
  const t = durationMin;
  return 0.8 + 0.1894393 * Math.exp(-0.012778 * t) + 0.2989558 * Math.exp(-0.1932605 * t);
}

/** VDOT à partir d'une performance (distance en m, temps en s). */
export function vdot(distanceMeters: number, timeSeconds: number): number {
  if (!(distanceMeters > 0 && timeSeconds > 0)) throw new Error('vdot: d & t > 0');
  const minutes = timeSeconds / 60.0;
  const v = distanceMeters / minutes; // m/min
  return vo2Cost(v) / fractionOfMax(minutes);
}

/**
 * Prédit le temps (s) sur une distance (m) pour un VDOT donné.
 * Bissection : f(t) = VO2(d/t) − VDOT·%max(t), décroissante en t.
 */
export function predictTimeSeconds(vdotValue: number, distanceMeters: number): number {
  if (!(vdotValue > 0 && distanceMeters > 0)) throw new Error('predictTimeSeconds: vdot & d > 0');
  const f = (tSeconds: number): number => {
    const minutes = tSeconds / 60.0;
    const v = distanceMeters / minutes;
    return vo2Cost(v) - vdotValue * fractionOfMax(minutes);
  };
  let lo = 60.0;
  let hi = 36_000.0;
  for (let i = 0; i < 100; i++) {
    const mid = (lo + hi) / 2;
    if (f(mid) > 0) lo = mid;
    else hi = mid;
    if (hi - lo < 0.01) break;
  }
  return (lo + hi) / 2;
}

/**
 * Vitesse (m/min) soutenable à une fraction de VO₂max.
 * Inverse vo2Cost : 0.000104·v² + 0.182258·v − (4.60 + VO2target) = 0.
 */
export function velocityForVO2(vo2Target: number): number {
  const a = 0.000104;
  const b = 0.182258;
  const c = -(4.6 + vo2Target);
  const disc = b * b - 4 * a * c;
  return (-b + Math.sqrt(disc)) / (2 * a); // racine positive
}

/** VMA (km/h) → VDOT : VO₂ à la vitesse maximale aérobie ≈ VDOT. */
export function vdotFromVMA(vmaKmh: number): number {
  return vo2Cost((vmaKmh * 1000) / 60);
}

/** Allures d'entraînement (s/km) dérivées du VDOT, par fraction de VO₂max. */
export function trainingPaces(vdotValue: number): TrainingPaces {
  const pace = (fraction: number): number => {
    const v = velocityForVO2(vdotValue * fraction); // m/min
    return 1000.0 / (v / 60.0); // s/km
  };
  return {
    easySecPerKm: pace(0.7),
    marathonSecPerKm: pace(0.82),
    thresholdSecPerKm: pace(0.88),
    intervalSecPerKm: pace(0.98),
    repetitionSecPerKm: pace(1.05),
  };
}

export const VDOT = {
  vo2Cost,
  fractionOfMax,
  vdot,
  vdotFromVMA,
  predictTimeSeconds,
  velocityForVO2,
  trainingPaces,
};
