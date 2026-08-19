import Foundation

public enum ReadinessLevel: String, Sendable, Codable {
    case good, moderate, low
}

public struct ReadinessAssessment: Sendable, Equatable {
    public var level: ReadinessLevel
    public var score: Double            // 0–100
    public var reasons: [String]        // explications pédagogiques
}

/// Évalue l'état de récupération du jour à partir des données objectives
/// (HRV, FC repos, sommeil) comparées à une ligne de base, et du ressenti.
public struct ReadinessEvaluator: Sendable {
    public init() {}

    /// `history` : jours précédents pour établir la ligne de base HRV / FC repos.
    public func assess(today: DailyReadiness, history: [DailyReadiness]) -> ReadinessAssessment {
        var score = 100.0
        var reasons: [String] = []

        // --- HRV vs ligne de base (moyenne − écart-type) ---
        let hrvs = history.compactMap(\.hrvMs)
        if let hrv = today.hrvMs, hrvs.count >= 3 {
            let mean = hrvs.reduce(0, +) / Double(hrvs.count)
            let sd = standardDeviation(hrvs, mean: mean)
            if hrv < mean - sd {
                score -= 30; reasons.append("VFC nettement sous ta normale : système nerveux fatigué.")
            } else if hrv < mean - 0.5 * sd {
                score -= 12; reasons.append("VFC légèrement basse.")
            }
        }

        // --- FC de repos élevée ---
        let rests = history.compactMap(\.hrRest)
        if let rest = today.hrRest, rests.count >= 3 {
            let mean = Double(rests.reduce(0, +)) / Double(rests.count)
            if Double(rest) > mean + 5 {
                score -= 15; reasons.append("FC de repos élevée (+\(Int(Double(rest) - mean)) bpm).")
            }
        }

        // --- Sommeil ---
        if let sleep = today.sleepHours {
            if sleep < 6 { score -= 20; reasons.append("Nuit courte (\(String(format: "%.1f", sleep)) h).") }
            else if sleep < 7 { score -= 10; reasons.append("Sommeil un peu juste.") }
        }

        // --- Ressenti subjectif (1–5, 5 = au top / aucune courbature) ---
        if let s = today.subjective {
            if s.soreness <= 2 { score -= 15; reasons.append("Courbatures marquées.") }
            if s.form <= 2 { score -= 12; reasons.append("Forme ressentie basse.") }
            if s.motivation <= 2 { score -= 6; reasons.append("Motivation en berne.") }
        }

        // --- Body Battery (si dispo via Garmin/Health) ---
        if let bb = today.bodyBattery, bb < 30 {
            score -= 10; reasons.append("Réserves d'énergie basses (Body Battery \(bb)).")
        }

        score = max(0, min(100, score))
        let level: ReadinessLevel = score >= 70 ? .good : (score >= 45 ? .moderate : .low)
        if reasons.isEmpty { reasons.append("Bonne récupération, prêt à performer.") }
        return ReadinessAssessment(level: level, score: score, reasons: reasons)
    }

    private func standardDeviation(_ xs: [Double], mean: Double) -> Double {
        guard xs.count > 1 else { return 0 }
        let variance = xs.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(xs.count - 1)
        return variance.squareRoot()
    }
}
