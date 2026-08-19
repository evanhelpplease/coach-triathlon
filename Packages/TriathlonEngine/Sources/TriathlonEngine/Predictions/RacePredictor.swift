import Foundation

/// Résultat de prédiction, décomposé et borné par un intervalle de confiance.
public struct RacePrediction: Sendable, Equatable {
    public var format: RaceFormat
    public var swimSeconds: Double?
    public var t1Seconds: Double?
    public var bikeSeconds: Double?
    public var t2Seconds: Double?
    public var runSeconds: Double
    public var totalSeconds: Double
    /// Demi-largeur relative de l'intervalle de confiance (ex. 0.05 = ±5 %).
    public var confidenceHalfWidth: Double

    public var lowSeconds: Double { totalSeconds * (1 - confidenceHalfWidth) }
    public var highSeconds: Double { totalSeconds * (1 + confidenceHalfWidth) }
}

/// Assemble une prédiction de course à partir des référentiels de l'athlète,
/// en tenant compte du format (intensité soutenable) et du matériel (vélo).
public struct RacePredictor: Sendable {
    public init() {}

    /// Fraction de FTP soutenable sur la partie vélo selon le format.
    static func bikeIntensity(_ f: RaceFormat) -> Double {
        switch f {
        case .sprint, .xs: return 0.95
        case .olympic: return 0.90
        case .half: return 0.83
        case .full: return 0.72
        default: return 0.90
        }
    }

    /// Pénalité d'allure course après le vélo (1.0 = pas de pénalité).
    static func runFatigueFactor(_ f: RaceFormat) -> Double {
        switch f {
        case .sprint, .xs: return 1.03
        case .olympic: return 1.05
        case .half: return 1.08
        case .full: return 1.13
        default: return 1.0
        }
    }

    /// Transitions estimées (s) par format.
    static func transitions(_ f: RaceFormat) -> (t1: Double, t2: Double) {
        switch f {
        case .xs, .sprint: return (60, 45)
        case .olympic: return (90, 60)
        case .half: return (150, 90)
        case .full: return (240, 150)
        default: return (0, 0)
        }
    }

    public func predict(
        format: RaceFormat,
        profile: AthleteProfile,
        equipment: Equipment
    ) -> RacePrediction {
        var missing = 0

        // --- Course (toujours présente) ---
        let vdot = profile.vdot ?? 45              // défaut prudent si inconnu
        if profile.vdot == nil { missing += 1 }
        let openRun = VDOT.predictTimeSeconds(vdot: vdot, distanceMeters: format.runMeters)
        let run = format.isTriathlon ? openRun * Self.runFatigueFactor(format) : openRun

        guard format.isTriathlon else {
            return RacePrediction(
                format: format, swimSeconds: nil, t1Seconds: nil, bikeSeconds: nil,
                t2Seconds: nil, runSeconds: run, totalSeconds: run,
                confidenceHalfWidth: confidence(missing: missing, base: 0.04)
            )
        }

        // --- Natation ---
        let swimDist = format.swimMeters!
        let cssPace = profile.cssSecPer100m ?? 120  // 2:00/100m défaut
        if profile.cssSecPer100m == nil { missing += 1 }
        var swim = CSS.predictTimeSeconds(cssPacePer100m: cssPace, distanceM: swimDist)
        if equipment.hasWetsuit { swim *= 0.96 }    // combinaison ≈ −4 %

        // --- Vélo ---
        let bikeDist = format.bikeMeters!
        let ftp = Double(profile.ftpWatts ?? 200)
        if profile.ftpWatts == nil { missing += 1 }
        let cda = CyclingPowerModel.typicalCdA(
            bikeType: equipment.bikeType ?? .road,
            aeroBars: equipment.hasAeroBars
        )
        let mass = profile.weightKg + (equipment.bikeWeightKg ?? 9.0)
        let model = CyclingPowerModel(totalMassKg: mass, cda: cda)
        let bike = model.predictTimeSeconds(
            distanceM: bikeDist,
            sustainedPowerW: ftp * Self.bikeIntensity(format)
        )

        let tr = Self.transitions(format)
        let total = swim + tr.t1 + bike + tr.t2 + run

        return RacePrediction(
            format: format,
            swimSeconds: swim, t1Seconds: tr.t1,
            bikeSeconds: bike, t2Seconds: tr.t2,
            runSeconds: run, totalSeconds: total,
            confidenceHalfWidth: confidence(missing: missing, base: 0.05)
        )
    }

    /// Plus il manque de référentiels mesurés, plus l'intervalle s'élargit.
    private func confidence(missing: Int, base: Double) -> Double {
        min(0.25, base + Double(missing) * 0.05)
    }
}
