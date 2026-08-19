import Foundation

/// Une semaine planifiée du macrocycle.
public struct PlannedWeek: Sendable, Equatable {
    public var index: Int              // 0 = première semaine
    public var startDate: Date
    public var phase: TrainingPhase
    public var targetLoad: Double      // charge hebdo cible (TSS-like)
    public var isDeload: Bool
    public var rationale: String
}

/// Périodiseur minimal : rétro-planifie base → build → spécifique → affûtage
/// vers une course A, avec une semaine de décharge toutes les 4 semaines et
/// une progression de charge bornée (~+8 %/sem hors décharge).
public struct Periodizer: Sendable {
    public init() {}

    /// Nombre de semaines d'affûtage selon le format.
    static func taperWeeks(_ format: RaceFormat) -> Int {
        switch format {
        case .full: return 3
        case .half, .marathon: return 2
        default: return 1
        }
    }

    public struct Config: Sendable {
        public var startingWeeklyLoad: Double   // charge de départ soutenable
        public var weeklyRampRate: Double       // ex. 0.08 = +8 %/sem
        public var deloadEvery: Int             // ex. 4
        public var deloadFactor: Double         // ex. 0.6 → −40 %
        public init(
            startingWeeklyLoad: Double = 300,
            weeklyRampRate: Double = 0.08,
            deloadEvery: Int = 4,
            deloadFactor: Double = 0.6
        ) {
            self.startingWeeklyLoad = startingWeeklyLoad
            self.weeklyRampRate = weeklyRampRate
            self.deloadEvery = deloadEvery
            self.deloadFactor = deloadFactor
        }

        /// Réglages selon la volonté de progression : la performance monte plus vite
        /// (progrès rapides, risque de blessure accru) ; le prudent décharge plus souvent.
        public static func forProgression(_ level: ProgressionLevel, startingWeeklyLoad: Double = 300) -> Config {
            switch level {
            case .prudent:     return .init(startingWeeklyLoad: startingWeeklyLoad, weeklyRampRate: 0.05, deloadEvery: 3, deloadFactor: 0.55)
            case .balanced:    return .init(startingWeeklyLoad: startingWeeklyLoad, weeklyRampRate: 0.08, deloadEvery: 4, deloadFactor: 0.60)
            case .performance: return .init(startingWeeklyLoad: startingWeeklyLoad, weeklyRampRate: 0.11, deloadEvery: 4, deloadFactor: 0.65)
            }
        }
    }

    /// Construit le plan hebdomadaire entre `start` et la date de course.
    public func plan(
        start: Date,
        race: Race,
        config: Config = Config(),
        calendar: Calendar = .init(identifier: .gregorian)
    ) -> [PlannedWeek] {
        let days = calendar.dateComponents([.day], from: start, to: race.date).day ?? 0
        let totalWeeks = max(1, Int((Double(days) / 7.0).rounded(.up)))
        let taper = min(Self.taperWeeks(race.format), max(1, totalWeeks - 1))
        let buildAndBase = totalWeeks - taper

        // Répartition base/build/spécifique sur les semaines hors affûtage.
        let baseCount = Int((Double(buildAndBase) * 0.5).rounded())
        let buildCount = Int((Double(buildAndBase) * 0.3).rounded())
        // Le reste (spécifique) est déduit implicitement par les seuils ci-dessous.

        func phase(for weekIndex: Int) -> TrainingPhase {
            if weekIndex >= totalWeeks - taper { return .taper }
            if weekIndex < baseCount { return .base }
            if weekIndex < baseCount + buildCount { return .build }
            return .specific
        }

        var weeks: [PlannedWeek] = []
        var progressiveLoad = config.startingWeeklyLoad

        for w in 0..<totalWeeks {
            let ph = phase(for: w)
            let isDeload = (w + 1) % config.deloadEvery == 0 && ph != .taper
            let weekStart = calendar.date(byAdding: .day, value: w * 7, to: start) ?? start

            var load: Double
            switch ph {
            case .taper:
                // Décroissance progressive de l'affûtage vers la course.
                let posInTaper = w - (totalWeeks - taper)          // 0..taper-1
                let factor = 0.6 - 0.15 * Double(posInTaper)
                load = progressiveLoad * max(0.3, factor)
            default:
                if isDeload {
                    load = progressiveLoad * config.deloadFactor
                } else {
                    load = progressiveLoad
                    progressiveLoad *= (1 + config.weeklyRampRate) // rampe pour la suite
                }
            }

            weeks.append(PlannedWeek(
                index: w,
                startDate: weekStart,
                phase: ph,
                targetLoad: load.rounded(),
                isDeload: isDeload,
                rationale: rationale(phase: ph, isDeload: isDeload, format: race.format)
            ))
        }
        return weeks
    }

    private func rationale(phase: TrainingPhase, isDeload: Bool, format: RaceFormat) -> String {
        if isDeload { return "Semaine de décharge : on assimile le travail, la forme remonte." }
        switch phase {
        case .base: return "Base : volume aérobie et technique, fondations posées."
        case .build: return "Build : on introduit le seuil et l'intensité spécifique."
        case .specific: return "Spécifique : allure course et enchaînements ciblés."
        case .taper: return "Affûtage : charge réduite, fraîcheur maximale pour le jour J."
        case .recovery: return "Récupération."
        }
    }
}
