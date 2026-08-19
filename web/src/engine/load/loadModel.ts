// Portage de Load/LoadModel.swift — charge (TSS-like), CTL/ATL/TSB/ACWR.
import type { AthleteProfile } from '../domain/profile';
import { estimatedHRMax } from '../domain/profile';
import type { CompletedActivity } from '../domain/activity';
import type { BiologicalSex } from '../domain/types';
import { trainingPaces } from '../predictions/vdot';

export class LoadCalculator {
  /** TSS vélo : (durée·NP·IF)/(FTP·3600)·100, IF = NP/FTP. */
  cyclingTSS(durationSec: number, normalizedPowerW: number, ftpW: number): number {
    if (!(ftpW > 0)) return 0;
    const intensity = normalizedPowerW / ftpW;
    return ((durationSec * normalizedPowerW * intensity) / (ftpW * 3600.0)) * 100.0;
  }

  /** Charge course/nat depuis l'allure vs allure au seuil. 1 h au seuil = 100. */
  paceTSS(durationSec: number, avgSpeed: number, thresholdSpeed: number): number {
    if (!(thresholdSpeed > 0)) return 0;
    const intensity = avgSpeed / thresholdSpeed;
    return (durationSec / 3600.0) * intensity * intensity * 100.0;
  }

  /** TRIMP de Banister (repli FC). */
  trimp(durationSec: number, avgHr: number, hrRest: number, hrMax: number, sex: BiologicalSex): number {
    if (!(hrMax > hrRest)) return 0;
    const hrr = (avgHr - hrRest) / (hrMax - hrRest);
    const clamped = Math.max(0, Math.min(1, hrr));
    const k = sex === 'female' ? 1.67 : 1.92;
    const b = sex === 'female' ? 0.86 : 0.64;
    const minutes = durationSec / 60.0;
    return minutes * clamped * b * Math.exp(k * clamped) * 1.92;
  }

  /** Charge d'une activité, avec repli progressif puissance → allure → FC → RPE. */
  load(a: CompletedActivity, profile: AthleteProfile): number {
    // 1) Puissance (vélo)
    if (a.sport === 'bike') {
      const np = a.normalizedPowerW ?? a.avgPowerW;
      if (np != null && profile.ftpWatts != null) {
        return this.cyclingTSS(a.duration, np, profile.ftpWatts);
      }
    }
    // 2) Allure (course)
    if (a.sport === 'run' && a.avgPaceSecPerKm != null && a.avgPaceSecPerKm > 0 && profile.vdot != null) {
      const thr = trainingPaces(profile.vdot).thresholdSecPerKm;
      return this.paceTSS(a.duration, 1000.0 / a.avgPaceSecPerKm, 1000.0 / thr);
    }
    // 3) Allure (natation) via CSS
    if (a.sport === 'swim' && a.distanceM != null && a.distanceM > 0 && profile.cssSecPer100m != null) {
      const avgSpeed = a.distanceM / a.duration;
      const thr = 100.0 / profile.cssSecPer100m;
      return this.paceTSS(a.duration, avgSpeed, thr);
    }
    // 4) FC (TRIMP)
    if (a.avgHr != null && profile.hrRest != null) {
      const max = profile.hrMax ?? estimatedHRMax(profile);
      return this.trimp(a.duration, a.avgHr, profile.hrRest, max, profile.sex);
    }
    // 5) Dernier repli : durée pondérée par un RPE.
    const rpe = a.rpe ?? 5;
    return (a.duration / 3600.0) * rpe * 12.0;
  }
}

export interface LoadPoint {
  date: Date;
  dailyLoad: number;
  ctl: number; // fitness (τ=42j)
  atl: number; // fatigue (τ=7j)
  tsb: number; // forme = CTL(veille) − ATL(veille)
  acwr: number; // charge aiguë 7j / chronique 28j
}

const CTL_TAU = 42.0;
const ATL_TAU = 7.0;

export class LoadSeries {
  /** Série CTL/ATL/TSB/ACWR à partir des charges quotidiennes (triées, un point/jour). */
  series(dailyLoads: Array<{ date: Date; load: number }>, startCTL = 0, startATL = 0): LoadPoint[] {
    const alphaCTL = 1 - Math.exp(-1.0 / CTL_TAU);
    const alphaATL = 1 - Math.exp(-1.0 / ATL_TAU);

    let ctl = startCTL;
    let atl = startATL;
    const points: LoadPoint[] = [];
    let window: number[] = [];

    dailyLoads.forEach((day, i) => {
      const tsb = ctl - atl; // forme de la veille

      ctl += alphaCTL * (day.load - ctl);
      atl += alphaATL * (day.load - atl);

      window.push(day.load);
      if (window.length > 28) window = window.slice(window.length - 28);
      const acute = window.slice(-7).reduce((s, v) => s + v, 0) / 7.0;
      const chronicCount = Math.min(window.length, 28);
      const chronic = window.slice(-28).reduce((s, v) => s + v, 0) / chronicCount;
      const acwr = chronic > 0 ? acute / chronic : 0;

      points.push({
        date: day.date,
        dailyLoad: day.load,
        ctl,
        atl,
        tsb: i === 0 ? 0 : tsb,
        acwr,
      });
    });
    return points;
  }
}
