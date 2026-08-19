// Portage de Adaptation/ReadinessEvaluator.swift.
import type { DailyReadiness } from '../domain/activity';

export type ReadinessLevel = 'good' | 'moderate' | 'low';

export interface ReadinessAssessment {
  level: ReadinessLevel;
  score: number; // 0–100
  reasons: string[];
}

function standardDeviation(xs: number[], mean: number): number {
  if (xs.length <= 1) return 0;
  const variance = xs.reduce((s, v) => s + (v - mean) * (v - mean), 0) / (xs.length - 1);
  return Math.sqrt(variance);
}

export class ReadinessEvaluator {
  assess(today: DailyReadiness, history: DailyReadiness[]): ReadinessAssessment {
    let score = 100.0;
    const reasons: string[] = [];

    // HRV vs ligne de base (moyenne − écart-type)
    const hrvs = history.map((h) => h.hrvMs).filter((x): x is number => x != null);
    if (today.hrvMs != null && hrvs.length >= 3) {
      const mean = hrvs.reduce((s, v) => s + v, 0) / hrvs.length;
      const sd = standardDeviation(hrvs, mean);
      if (today.hrvMs < mean - sd) {
        score -= 30;
        reasons.push('VFC nettement sous ta normale : système nerveux fatigué.');
      } else if (today.hrvMs < mean - 0.5 * sd) {
        score -= 12;
        reasons.push('VFC légèrement basse.');
      }
    }

    // FC de repos élevée
    const rests = history.map((h) => h.hrRest).filter((x): x is number => x != null);
    if (today.hrRest != null && rests.length >= 3) {
      const mean = rests.reduce((s, v) => s + v, 0) / rests.length;
      if (today.hrRest > mean + 5) {
        score -= 15;
        reasons.push(`FC de repos élevée (+${Math.trunc(today.hrRest - mean)} bpm).`);
      }
    }

    // Sommeil
    if (today.sleepHours != null) {
      if (today.sleepHours < 6) {
        score -= 20;
        reasons.push(`Nuit courte (${today.sleepHours.toFixed(1)} h).`);
      } else if (today.sleepHours < 7) {
        score -= 10;
        reasons.push('Sommeil un peu juste.');
      }
    }

    // Ressenti subjectif
    if (today.subjective) {
      const s = today.subjective;
      if (s.soreness <= 2) { score -= 15; reasons.push('Courbatures marquées.'); }
      if (s.form <= 2) { score -= 12; reasons.push('Forme ressentie basse.'); }
      if (s.motivation <= 2) { score -= 6; reasons.push('Motivation en berne.'); }
    }

    // Body Battery
    if (today.bodyBattery != null && today.bodyBattery < 30) {
      score -= 10;
      reasons.push(`Réserves d'énergie basses (Body Battery ${today.bodyBattery}).`);
    }

    score = Math.max(0, Math.min(100, score));
    const level: ReadinessLevel = score >= 70 ? 'good' : score >= 45 ? 'moderate' : 'low';
    if (reasons.length === 0) reasons.push('Bonne récupération, prêt à performer.');
    return { level, score, reasons };
  }
}
