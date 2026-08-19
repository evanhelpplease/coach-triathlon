import Foundation

// MARK: - Nutrition de course

public struct NutritionPlan: Sendable, Equatable {
    public var carbsPerHour: Int        // g/h
    public var totalCarbs: Int          // g
    public var fluidPerHour: Int        // ml/h
    public var sodiumPerHour: Int       // mg/h
    public var summary: String
}

/// Stratégie de ravitaillement personnalisée selon la durée prédite et le poids.
public enum RaceNutrition {
    public static func plan(durationSec: Double, weightKg: Double, format: RaceFormat) -> NutritionPlan {
        let hours = max(0.25, durationSec / 3600)

        // Glucides/h : croissant avec la durée (tolérance digestive).
        let carbsPerHour: Int
        switch hours {
        case ..<1.0:  carbsPerHour = 30
        case ..<2.0:  carbsPerHour = 55
        case ..<3.5:  carbsPerHour = 70
        case ..<6.0:  carbsPerHour = 80
        default:      carbsPerHour = 90
        }
        // Sur les courtes intenses, l'apport avant course prime (peu pendant).
        let total = Int((Double(carbsPerHour) * hours).rounded())

        let fluidPerHour = hours > 4 ? 700 : 550
        let sodiumPerHour = hours > 3 ? 700 : 500

        let summary: String
        if hours < 1.2 {
            summary = "Course courte : privilégie l'apport la veille et 30–60 g de glucides 1 h avant. Pendant : hydratation + éventuellement un gel."
        } else if hours < 3.5 {
            summary = "Vise \(carbsPerHour) g de glucides/h dès la partie vélo (gels, boisson, barres). Bois régulièrement par petites gorgées."
        } else {
            summary = "Format long : \(carbsPerHour) g/h de glucides, \(fluidPerHour) ml/h de liquide, \(sodiumPerHour) mg/h de sodium. Anticipe dès le début, n'attends pas la sensation de faim."
        }
        return NutritionPlan(carbsPerHour: carbsPerHour, totalCarbs: total,
                             fluidPerHour: fluidPerHour, sodiumPerHour: sodiumPerHour, summary: summary)
    }
}

// MARK: - Pacing par discipline

public struct PacingTarget: Sendable, Equatable, Identifiable {
    public var id: String { sportKey + label }
    public var sportKey: String
    public var label: String
    public var value: String
    public var note: String
}

/// Allures/puissances cibles à tenir le jour J, par discipline (pacing).
public enum RacePacing {
    public static func targets(format: RaceFormat, profile: AthleteProfile) -> [PacingTarget] {
        var out: [PacingTarget] = []

        if format.isTriathlon, let css = profile.cssSecPer100m {
            // Nage : légèrement en deçà de la CSS pour sortir de l'eau frais.
            let pace = css + (format == .full ? 6 : 3)
            out.append(.init(sportKey: "swim", label: "Allure natation",
                             value: mmss(pace) + "/100m",
                             note: "Départ contrôlé, respiration régulière. Ne pars pas trop vite."))
        }
        if format.isTriathlon, let ftp = profile.ftpWatts {
            let intensity = bikeIntensity(format)
            let power = Int(Double(ftp) * intensity)
            out.append(.init(sportKey: "bike", label: "Puissance vélo",
                             value: "\(power) W (\(Int(intensity * 100)) % FTP)",
                             note: "Puissance lissée, évite les à-coups. Économise pour la course à pied."))
        }
        if let vdot = profile.vdot {
            let fatigue = format.isTriathlon ? runFatigue(format) : 1.0
            let base = VDOT.trainingPaces(vdot: vdot)
            // Cible = allure marathon (ou seuil pour formats courts) ajustée de la fatigue.
            let racePace = (format.runMeters <= 10_000 ? base.thresholdSecPerKm : base.marathonSecPerKm) * fatigue
            out.append(.init(sportKey: "run", label: "Allure course",
                             value: mmss(racePace) + "/km",
                             note: format.isTriathlon ? "Les jambes seront lourdes au début : monte en allure progressivement." : "Allure régulière, negative split si possible."))
        }
        return out
    }

    static func bikeIntensity(_ f: RaceFormat) -> Double {
        switch f { case .sprint, .xs: return 0.95; case .olympic: return 0.90; case .half: return 0.83; case .full: return 0.72; default: return 0.90 }
    }
    static func runFatigue(_ f: RaceFormat) -> Double {
        switch f { case .sprint, .xs: return 1.03; case .olympic: return 1.05; case .half: return 1.08; case .full: return 1.13; default: return 1.0 }
    }
    static func mmss(_ sec: Double) -> String {
        let s = Int(sec.rounded()); return String(format: "%d:%02d", s / 60, s % 60)
    }
}
