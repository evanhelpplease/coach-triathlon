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

    // Sommeil — malus PROGRESSIF (une nuit très courte doit peser lourd).
    if (today.sleepHours != null) {
      const h = today.sleepHours;
      let pen = 0;
      if (h < 3) pen = 55;
      else if (h < 4) pen = 45;
      else if (h < 5) pen = 33;
      else if (h < 6) pen = 22;
      else if (h < 7) pen = 10;
      else if (h < 7.5) pen = 4;
      if (pen > 0) {
        score -= pen;
        reasons.push(`Nuit ${h < 5 ? 'très ' : ''}courte (${h.toFixed(1)} h).`);
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
    let level: ReadinessLevel = score >= 70 ? 'good' : score >= 45 ? 'moderate' : 'low';

    // Garde-fous sécurité : un facteur critique ne peut jamais donner « au top ».
    const s = today.subjective;
    const veryLowSleep = today.sleepHours != null && today.sleepHours < 4;
    const veryBadFeel = !!s && (s.form <= 1 || s.soreness <= 1);
    if ((veryLowSleep || veryBadFeel) && level === 'good') level = 'moderate';
    // Nuit quasi blanche ou ressenti + courbatures au plus bas → repos impératif.
    if ((today.sleepHours != null && today.sleepHours < 3) || (!!s && s.form <= 1 && s.soreness <= 1)) {
      level = 'low';
    }

    if (reasons.length === 0) reasons.push('Bonne récupération, prêt à performer.');
    return { level, score, reasons };
  }
}
