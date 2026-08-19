// Portage de Domain/Zones.swift.

/** Une borne de zone. Unités selon le contexte (bpm, s/km, s/100m, W). */
export interface ZoneBoundary {
  zone: number; // 1...N
  label: string;
  lower: number; // borne basse incluse
  upper: number; // borne haute exclue ; Infinity pour la dernière
}

export function zoneContains(b: ZoneBoundary, value: number): boolean {
  return value >= b.lower && value < b.upper;
}

export type ZoneSource = 'test' | 'estimated' | 'autoRecalibrated';

/** Jeu complet de zones individualisées. */
export interface TrainingZones {
  hr: ZoneBoundary[]; // bpm, croissant
  runPace: ZoneBoundary[]; // s/km
  swimPace: ZoneBoundary[]; // s/100m
  power: ZoneBoundary[]; // W, croissant
  updatedAt: Date;
  source: ZoneSource;
}

export function emptyZones(updatedAt: Date = new Date(), source: ZoneSource = 'estimated'): TrainingZones {
  return { hr: [], runPace: [], swimPace: [], power: [], updatedAt, source };
}
