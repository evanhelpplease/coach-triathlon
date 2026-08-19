// Portage de Analysis/PostSessionAnalyzer.swift.
import type { AthleteProfile } from '../domain/profile';
import type { CompletedActivity } from '../domain/activity';
import type { Sport } from '../domain/types';
import { trainingPaces } from '../predictions/vdot';
import { LoadCalculator } from '../load/loadModel';

export interface SessionAnalysis {
  headline: string;
  insights: string[];
}

function sportLabel(s: Sport): string {
  switch (s) {
    case 'swim': return 'Natation';
    case 'bike': return 'Sortie vélo';
    case 'run': return 'Course';
    case 'strength': return 'Renforcement';
    case 'brick': return 'Brick';
  }
}

function durationText(s: number): string {
  const t = Math.round(s);
  const h = Math.trunc(t / 3600);
  const m = Math.trunc((t % 3600) / 60);
  return h > 0 ? `${h} h ${String(m).padStart(2, '0')}` : `${m} min`;
}
function kmText(m: number): string {
  return `${(m / 1000).toFixed(1)} km`;
}

export class PostSessionAnalyzer {
  analyze(a: CompletedActivity, profile: AthleteProfile, history: CompletedActivity[]): SessionAnalysis {
    const insights: string[] = [];
    const intensity = this.relativeIntensity(a, profile);

    let zoneWord: string;
    if (intensity == null) zoneWord = 'réalisée';
    else if (intensity >= 0.98) zoneWord = 'intense, proche du seuil';
    else if (intensity >= 0.88) zoneWord = 'au tempo';
    else if (intensity >= 0.75) zoneWord = 'en endurance active';
    else zoneWord = 'en endurance fondamentale';

    const headline = `${sportLabel(a.sport)} ${zoneWord} — ${durationText(a.duration)}${a.distanceM != null ? `, ${kmText(a.distanceM)}` : ''}.`;

    if (a.hrDriftPct != null) {
      const drift = a.hrDriftPct;
      if (drift < 5) insights.push(`Dérive cardiaque faible (${Math.trunc(drift)} %) : bonne endurance aérobie, effort bien tenu.`);
      else if (drift < 8) insights.push(`Dérive cardiaque modérée (${Math.trunc(drift)} %).`);
      else insights.push(`Dérive cardiaque élevée (${Math.trunc(drift)} %) : fatigue, chaleur ou allure trop rapide en début de séance.`);
    }

    const sameSport = history.filter((x) => x.sport === a.sport && x.id !== a.id);
    const trend = this.paceTrend(a, sameSport);
    if (trend) insights.push(trend);

    if (a.distanceM != null) {
      const prevDistances = sameSport.map((x) => x.distanceM).filter((x): x is number => x != null);
      if (prevDistances.length > 0 && a.distanceM > Math.max(...prevDistances)) {
        insights.push(`C'est ta plus longue ${sportLabel(a.sport).toLowerCase()} enregistrée 💪.`);
      }
    }

    const load = new LoadCalculator().load(a, profile);
    insights.push(`Charge estimée : ${Math.round(load)}.`);

    if (insights.length === 0) insights.push('Séance enregistrée. Continue comme ça !');
    return { headline, insights };
  }

  private relativeIntensity(a: CompletedActivity, profile: AthleteProfile): number | null {
    switch (a.sport) {
      case 'bike': {
        const p = a.normalizedPowerW ?? a.avgPowerW;
        if (p == null || profile.ftpWatts == null || profile.ftpWatts <= 0) return null;
        return p / profile.ftpWatts;
      }
      case 'run': {
        if (a.avgPaceSecPerKm == null || a.avgPaceSecPerKm <= 0 || profile.vdot == null) return null;
        const thr = trainingPaces(profile.vdot).thresholdSecPerKm;
        return 1000.0 / a.avgPaceSecPerKm / (1000.0 / thr);
      }
      case 'swim': {
        if (a.distanceM == null || a.distanceM <= 0 || profile.cssSecPer100m == null) return null;
        const speed = a.distanceM / a.duration;
        return speed / (100.0 / profile.cssSecPer100m);
      }
      default:
        return null;
    }
  }

  private paceTrend(a: CompletedActivity, sameSport: CompletedActivity[]): string | null {
    if (sameSport.length < 2) return null;
    if (a.sport === 'run') {
      const paces = sameSport.map((x) => x.avgPaceSecPerKm).filter((x): x is number => x != null);
      if (a.avgPaceSecPerKm == null || paces.length === 0) return null;
      const mean = paces.reduce((s, v) => s + v, 0) / paces.length;
      if (a.avgPaceSecPerKm < mean - 3) return `Allure plus rapide que ta moyenne récente : ta forme progresse (−${Math.trunc(mean - a.avgPaceSecPerKm)} s/km).`;
      if (a.avgPaceSecPerKm > mean + 6) return "Allure plus lente que d'habitude : séance facile ou fatigue.";
      return null;
    }
    if (a.sport === 'bike') {
      const powers = sameSport.map((x) => x.normalizedPowerW ?? x.avgPowerW).filter((x): x is number => x != null);
      const p = a.normalizedPowerW ?? a.avgPowerW;
      if (p == null || powers.length === 0) return null;
      const mean = powers.reduce((s, v) => s + v, 0) / powers.length;
      if (p > mean + 5) return 'Puissance au-dessus de ta moyenne récente : belle montée en forme.';
      return null;
    }
    return null;
  }
}
