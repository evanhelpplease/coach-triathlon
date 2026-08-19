// Portage de Domain/Equipment.swift.
import type { BikeType, RaceFormat, RacePriority, Sport } from './types';

export type StrengthAccess = 'gym' | 'homeWeights' | 'bodyweightOnly' | 'none';

/** État du matériel disponible à un instant T. */
export interface Equipment {
  hasBike: boolean;
  bikeType?: BikeType;
  bikeWeightKg?: number;
  hasAeroBars: boolean;
  hasPowerMeter: boolean;
  hasSmartTrainer: boolean;
  poolAccess: boolean;
  openWaterAccess: boolean;
  hasWetsuit: boolean;
  hasDrylandCords: boolean;
  runOutdoor: boolean;
  hasTreadmill: boolean;
  hasTrack: boolean;
  strengthAccess: StrengthAccess;
}

export function makeEquipment(p: Partial<Equipment> = {}): Equipment {
  return {
    hasBike: false,
    hasAeroBars: false,
    hasPowerMeter: false,
    hasSmartTrainer: false,
    poolAccess: false,
    openWaterAccess: false,
    hasWetsuit: false,
    hasDrylandCords: false,
    runOutdoor: true,
    hasTreadmill: false,
    hasTrack: false,
    strengthAccess: 'bodyweightOnly',
    ...p,
  };
}

/** Le sport peut-il être pratiqué en l'état ? */
export function canPractice(e: Equipment, sport: Sport): boolean {
  switch (sport) {
    case 'swim': return e.poolAccess || e.openWaterAccess;
    case 'bike': return e.hasBike;
    case 'run': return e.runOutdoor || e.hasTreadmill || e.hasTrack;
    case 'strength': return e.strengthAccess !== 'none';
    case 'brick': return e.hasBike && (e.runOutdoor || e.hasTreadmill);
  }
}

export interface Race {
  id: string;
  date: Date;
  format: RaceFormat;
  priority: RacePriority;
  title: string;
  /** Objectif de temps total (secondes). Pilote l'ambition du plan et le pacing. */
  goalTimeSeconds?: number;
}

let raceCounter = 0;
export function makeRace(p: Omit<Race, 'id'> & { id?: string }): Race {
  return { id: p.id ?? `race-${++raceCounter}-${Date.now()}`, ...p };
}
