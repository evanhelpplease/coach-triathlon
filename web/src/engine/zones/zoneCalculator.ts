// Portage de Zones/ZoneCalculator.swift.
import type { AthleteProfile } from '../domain/profile';
import { estimatedHRMax } from '../domain/profile';
import { emptyZones, type TrainingZones, type ZoneBoundary, type ZoneSource } from '../domain/zones';
import { trainingPaces } from '../predictions/vdot';

// FC — Karvonen (réserve de FC), 5 zones.
const HR_RESERVE_PERCENTS: Array<{ zone: number; label: string; lo: number; hi: number }> = [
  { zone: 1, label: 'Récupération', lo: 0.5, hi: 0.68 },
  { zone: 2, label: 'Endurance', lo: 0.68, hi: 0.83 },
  { zone: 3, label: 'Tempo', lo: 0.83, hi: 0.9 },
  { zone: 4, label: 'Seuil', lo: 0.9, hi: 0.98 },
  { zone: 5, label: 'VO2max', lo: 0.98, hi: 1.2 },
];

// Puissance — 7 zones de Coggan (% FTP).
const COGGAN_PERCENTS: Array<{ zone: number; label: string; lo: number; hi: number }> = [
  { zone: 1, label: 'Récup active', lo: 0.0, hi: 0.55 },
  { zone: 2, label: 'Endurance', lo: 0.55, hi: 0.75 },
  { zone: 3, label: 'Tempo', lo: 0.75, hi: 0.9 },
  { zone: 4, label: 'Seuil', lo: 0.9, hi: 1.05 },
  { zone: 5, label: 'VO2max', lo: 1.05, hi: 1.2 },
  { zone: 6, label: 'Anaérobie', lo: 1.2, hi: 1.5 },
  { zone: 7, label: 'Neuromusc.', lo: 1.5, hi: 3.0 },
];

export class ZoneCalculator {
  hrZones(hrMax: number, hrRest: number): ZoneBoundary[] {
    const reserve = hrMax - hrRest;
    return HR_RESERVE_PERCENTS.map((z) => ({
      zone: z.zone,
      label: z.label,
      lower: hrRest + z.lo * reserve,
      upper: z.zone === 5 ? Infinity : hrRest + z.hi * reserve,
    }));
  }

  powerZones(ftp: number): ZoneBoundary[] {
    return COGGAN_PERCENTS.map((z) => ({
      zone: z.zone,
      label: z.label,
      lower: z.lo * ftp,
      upper: z.zone === 7 ? Infinity : z.hi * ftp,
    }));
  }

  /** Allures course (s/km) : `lower` = plus rapide (valeur temporelle basse). */
  runPaceZones(vdot: number): ZoneBoundary[] {
    const p = trainingPaces(vdot);
    return [
      { zone: 1, label: 'Facile', lower: p.easySecPerKm, upper: p.easySecPerKm + 40 },
      { zone: 2, label: 'Marathon', lower: p.marathonSecPerKm, upper: p.easySecPerKm },
      { zone: 3, label: 'Seuil', lower: p.thresholdSecPerKm, upper: p.marathonSecPerKm },
      { zone: 4, label: 'Intervalle', lower: p.intervalSecPerKm, upper: p.thresholdSecPerKm },
      { zone: 5, label: 'Répétition', lower: p.repetitionSecPerKm, upper: p.intervalSecPerKm },
    ];
  }

  swimPaceZones(cssSecPer100m: number): ZoneBoundary[] {
    const css = cssSecPer100m;
    return [
      { zone: 1, label: 'Récup', lower: css + 15, upper: css + 40 },
      { zone: 2, label: 'Endurance', lower: css + 6, upper: css + 15 },
      { zone: 3, label: 'Seuil', lower: css - 2, upper: css + 6 },
      { zone: 4, label: 'VO2', lower: css - 8, upper: css - 2 },
      { zone: 5, label: 'Sprint', lower: css - 20, upper: css - 8 },
    ];
  }

  zones(profile: AthleteProfile, on: Date = new Date()): TrainingZones {
    const hrMax = profile.hrMax ?? estimatedHRMax(profile, on);
    const hrRest = profile.hrRest ?? 60;
    let source: ZoneSource = 'test';
    if (profile.hrMax == null || profile.hrRest == null) source = 'estimated';

    const z = emptyZones(on, source);
    z.hr = this.hrZones(hrMax, hrRest);
    if (profile.ftpWatts != null) z.power = this.powerZones(profile.ftpWatts);
    if (profile.vdot != null) z.runPace = this.runPaceZones(profile.vdot);
    if (profile.cssSecPer100m != null) z.swimPace = this.swimPaceZones(profile.cssSecPer100m);
    return z;
  }
}
