import Foundation

/// Résumé intelligent d'une séance réalisée, en langage naturel (français).
public struct SessionAnalysis: Sendable, Equatable {
    public var headline: String
    public var insights: [String]
    public init(headline: String, insights: [String]) {
        self.headline = headline
        self.insights = insights
    }
}

/// Analyse une activité réalisée : intensité, dérive cardiaque, tendance vs
/// l'historique, charge. Fonction pure, indépendante de l'UI.
public struct PostSessionAnalyzer: Sendable {
    public init() {}

    public func analyze(activity a: CompletedActivity, profile: AthleteProfile,
                        history: [CompletedActivity]) -> SessionAnalysis {
        var insights: [String] = []
        let intensity = relativeIntensity(a, profile: profile)

        // Intensité relative.
        let zoneWord: String
        switch intensity {
        case let x? where x >= 0.98: zoneWord = "intense, proche du seuil"
        case let x? where x >= 0.88: zoneWord = "au tempo"
        case let x? where x >= 0.75: zoneWord = "en endurance active"
        case .some: zoneWord = "en endurance fondamentale"
        case nil: zoneWord = "réalisée"
        }
        let headline = "\(sportLabel(a.sport)) \(zoneWord) — \(Self.duration(a.duration))\(a.distanceM.map { ", \(Self.km($0))" } ?? "")."

        // Dérive cardiaque.
        if let drift = a.hrDriftPct {
            if drift < 5 { insights.append("Dérive cardiaque faible (\(Int(drift)) %) : bonne endurance aérobie, effort bien tenu.") }
            else if drift < 8 { insights.append("Dérive cardiaque modérée (\(Int(drift)) %).") }
            else { insights.append("Dérive cardiaque élevée (\(Int(drift)) %) : fatigue, chaleur ou allure trop rapide en début de séance.") }
        }

        // Tendance vs historique (même sport).
        let sameSport = history.filter { $0.sport == a.sport && $0.id != a.id }
        if let trend = paceTrend(a, sameSport: sameSport) {
            insights.append(trend)
        }

        // Record de distance.
        if let dist = a.distanceM, let maxPrev = sameSport.compactMap(\.distanceM).max(), dist > maxPrev {
            insights.append("C'est ta plus longue \(sportLabel(a.sport).lowercased()) enregistrée 💪.")
        }

        // Charge.
        let load = LoadCalculator().load(for: a, profile: profile)
        insights.append("Charge estimée : \(Int(load.rounded())).")

        if insights.isEmpty { insights.append("Séance enregistrée. Continue comme ça !") }
        return SessionAnalysis(headline: headline, insights: insights)
    }

    // MARK: Intensité relative au seuil (0…~1.1)

    private func relativeIntensity(_ a: CompletedActivity, profile: AthleteProfile) -> Double? {
        switch a.sport {
        case .bike:
            guard let p = a.normalizedPowerW ?? a.avgPowerW, let ftp = profile.ftpWatts, ftp > 0 else { return nil }
            return Double(p) / Double(ftp)
        case .run:
            guard let pace = a.avgPaceSecPerKm, pace > 0, let vdot = profile.vdot else { return nil }
            let thr = VDOT.trainingPaces(vdot: vdot).thresholdSecPerKm
            return (1000.0 / pace) / (1000.0 / thr)   // rapport de vitesses
        case .swim:
            guard let dist = a.distanceM, dist > 0, let css = profile.cssSecPer100m else { return nil }
            let speed = dist / a.duration
            return speed / (100.0 / css)
        default:
            return nil
        }
    }

    private func paceTrend(_ a: CompletedActivity, sameSport: [CompletedActivity]) -> String? {
        guard sameSport.count >= 2 else { return nil }
        switch a.sport {
        case .run:
            let paces = sameSport.compactMap(\.avgPaceSecPerKm)
            guard let pace = a.avgPaceSecPerKm, !paces.isEmpty else { return nil }
            let mean = paces.reduce(0, +) / Double(paces.count)
            if pace < mean - 3 { return "Allure plus rapide que ta moyenne récente : ta forme progresse (−\(Int(mean - pace)) s/km)." }
            if pace > mean + 6 { return "Allure plus lente que d'habitude : séance facile ou fatigue." }
            return nil
        case .bike:
            let powers = sameSport.compactMap { $0.normalizedPowerW ?? $0.avgPowerW }
            guard let p = a.normalizedPowerW ?? a.avgPowerW, !powers.isEmpty else { return nil }
            let mean = Double(powers.reduce(0, +)) / Double(powers.count)
            if Double(p) > mean + 5 { return "Puissance au-dessus de ta moyenne récente : belle montée en forme." }
            return nil
        default:
            return nil
        }
    }

    // MARK: Formatage minimal (indépendant de l'app)

    static func duration(_ s: TimeInterval) -> String {
        let t = Int(s.rounded()); let h = t / 3600, m = (t % 3600) / 60
        return h > 0 ? "\(h) h \(String(format: "%02d", m))" : "\(m) min"
    }
    static func km(_ m: Double) -> String { String(format: "%.1f km", m / 1000) }

    private func sportLabel(_ s: Sport) -> String {
        switch s {
        case .swim: return "Natation"; case .bike: return "Sortie vélo"; case .run: return "Course"
        case .strength: return "Renforcement"; case .brick: return "Brick"
        }
    }
}
