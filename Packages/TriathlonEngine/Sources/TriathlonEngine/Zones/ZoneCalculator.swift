import Foundation

/// Construit des zones individualisées à partir des référentiels de l'athlète.
public struct ZoneCalculator: Sendable {
    public init() {}

    // MARK: FC — méthode de Karvonen (réserve de FC)

    /// 5 zones FC. Bornes en % de la réserve `hrRest + p·(hrMax − hrRest)`.
    static let hrReservePercents: [(zone: Int, label: String, lo: Double, hi: Double)] = [
        (1, "Récupération", 0.50, 0.68),
        (2, "Endurance",    0.68, 0.83),
        (3, "Tempo",        0.83, 0.90),
        (4, "Seuil",        0.90, 0.98),
        (5, "VO2max",       0.98, 1.20)
    ]

    public func hrZones(hrMax: Int, hrRest: Int) -> [ZoneBoundary] {
        let reserve = Double(hrMax - hrRest)
        return Self.hrReservePercents.map { z in
            ZoneBoundary(
                zone: z.zone, label: z.label,
                lower: Double(hrRest) + z.lo * reserve,
                upper: z.zone == 5 ? .infinity : Double(hrRest) + z.hi * reserve
            )
        }
    }

    // MARK: Puissance — 7 zones de Coggan (% FTP)

    static let cogganPercents: [(zone: Int, label: String, lo: Double, hi: Double)] = [
        (1, "Récup active", 0.00, 0.55),
        (2, "Endurance",    0.55, 0.75),
        (3, "Tempo",        0.75, 0.90),
        (4, "Seuil",        0.90, 1.05),
        (5, "VO2max",       1.05, 1.20),
        (6, "Anaérobie",    1.20, 1.50),
        (7, "Neuromusc.",   1.50, 3.00)
    ]

    public func powerZones(ftp: Int) -> [ZoneBoundary] {
        let f = Double(ftp)
        return Self.cogganPercents.map { z in
            ZoneBoundary(
                zone: z.zone, label: z.label,
                lower: z.lo * f,
                upper: z.zone == 7 ? .infinity : z.hi * f
            )
        }
    }

    // MARK: Allures course — dérivées du VDOT

    /// Bornes = plages d'allure (s/km) par zone. Attention : allure plus BASSE = plus rapide,
    /// donc `lower`/`upper` encadrent la plage temporelle (lower = plus rapide).
    public func runPaceZones(vdot: Double) -> [ZoneBoundary] {
        let p = VDOT.trainingPaces(vdot: vdot)
        return [
            ZoneBoundary(zone: 1, label: "Facile",   lower: p.easySecPerKm,        upper: p.easySecPerKm + 40),
            ZoneBoundary(zone: 2, label: "Marathon", lower: p.marathonSecPerKm,    upper: p.easySecPerKm),
            ZoneBoundary(zone: 3, label: "Seuil",    lower: p.thresholdSecPerKm,   upper: p.marathonSecPerKm),
            ZoneBoundary(zone: 4, label: "Intervalle", lower: p.intervalSecPerKm,  upper: p.thresholdSecPerKm),
            ZoneBoundary(zone: 5, label: "Répétition", lower: p.repetitionSecPerKm, upper: p.intervalSecPerKm)
        ]
    }

    // MARK: Allures natation — dérivées de la CSS

    public func swimPaceZones(cssSecPer100m css: Double) -> [ZoneBoundary] {
        return [
            ZoneBoundary(zone: 1, label: "Récup",  lower: css + 15, upper: css + 40),
            ZoneBoundary(zone: 2, label: "Endurance", lower: css + 6,  upper: css + 15),
            ZoneBoundary(zone: 3, label: "Seuil",  lower: css - 2,  upper: css + 6),
            ZoneBoundary(zone: 4, label: "VO2",    lower: css - 8,  upper: css - 2),
            ZoneBoundary(zone: 5, label: "Sprint", lower: css - 20, upper: css - 8)
        ]
    }

    // MARK: Assemblage complet

    public func zones(for profile: AthleteProfile, on date: Date = Date()) -> TrainingZones {
        let hrMax = profile.hrMax ?? profile.estimatedHRMax(on: date)
        let hrRest = profile.hrRest ?? 60
        var source: ZoneSource = .test
        if profile.hrMax == nil || profile.hrRest == nil { source = .estimated }

        var z = TrainingZones(updatedAt: date, source: source)
        z.hr = hrZones(hrMax: hrMax, hrRest: hrRest)
        if let ftp = profile.ftpWatts { z.power = powerZones(ftp: ftp) }
        if let vdot = profile.vdot { z.runPace = runPaceZones(vdot: vdot) }
        if let css = profile.cssSecPer100m { z.swimPace = swimPaceZones(cssSecPer100m: css) }
        return z
    }
}
