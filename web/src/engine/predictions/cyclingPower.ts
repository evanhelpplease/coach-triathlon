// Portage de Predictions/CyclingPower.swift — modèle physique puissance ⇄ vitesse.
import type { BikeType } from '../domain/types';

export interface CyclingPowerParams {
  totalMassKg: number;
  cda: number; // coefficient de traînée × surface (m²)
  crr?: number; // résistance au roulement
  airDensity?: number; // ρ (kg/m³)
  drivetrainEfficiency?: number;
  gravity?: number;
}

export class CyclingPowerModel {
  totalMassKg: number;
  cda: number;
  crr: number;
  airDensity: number;
  drivetrainEfficiency: number;
  gravity: number;

  constructor(p: CyclingPowerParams) {
    this.totalMassKg = p.totalMassKg;
    this.cda = p.cda;
    this.crr = p.crr ?? 0.005;
    this.airDensity = p.airDensity ?? 1.225;
    this.drivetrainEfficiency = p.drivetrainEfficiency ?? 0.98;
    this.gravity = p.gravity ?? 9.81;
  }

  /** CdA typique selon le type de vélo / la position aéro. */
  static typicalCdA(bikeType: BikeType, aeroBars: boolean): number {
    switch (bikeType) {
      case 'tt': return aeroBars ? 0.24 : 0.28;
      case 'road': return aeroBars ? 0.29 : 0.32;
      case 'gravel': return 0.36;
      case 'mtb': return 0.42;
      case 'trainer': return 0.32;
    }
  }

  /** Puissance pédale (W) requise pour une vitesse (m/s) et une pente. */
  power(v: number, grade = 0, headwind = 0): number {
    const rolling = this.totalMassKg * this.gravity * this.crr;
    const climbing = this.totalMassKg * this.gravity * grade;
    const apparent = v + headwind;
    const aero = 0.5 * this.airDensity * this.cda * apparent * apparent;
    const pWheel = (rolling + climbing) * v + aero * v;
    return pWheel / this.drivetrainEfficiency;
  }

  /** Vitesse (m/s) atteinte pour une puissance (W) donnée — inversion numérique. */
  speed(targetPower: number, grade = 0, headwind = 0): number {
    if (!(targetPower > 0)) throw new Error('speed: puissance > 0');
    let lo = 0.0;
    let hi = 30.0; // jusqu'à 108 km/h
    for (let i = 0; i < 100; i++) {
      const mid = (lo + hi) / 2;
      if (this.power(mid, grade, headwind) < targetPower) lo = mid;
      else hi = mid;
      if (hi - lo < 1e-4) break;
    }
    return (lo + hi) / 2;
  }

  /** Temps (s) prédit sur une distance (m) à une puissance soutenue donnée. */
  predictTimeSeconds(distanceM: number, sustainedPowerW: number, grade = 0): number {
    const v = this.speed(sustainedPowerW, grade);
    return distanceM / v;
  }
}
