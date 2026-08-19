import Foundation

/// Modèle physique puissance ⇄ vitesse en cyclisme.
///
/// `P_roue = (m·g·Crr + m·g·pente)·v + ½·ρ·CdA·(v+vent)²·v`
/// `P_pédale = P_roue / rendement`
public struct CyclingPowerModel: Sendable, Equatable {
    public var totalMassKg: Double        // cycliste + vélo + équipement
    public var cda: Double                // coefficient de traînée × surface (m²)
    public var crr: Double                // résistance au roulement
    public var airDensity: Double         // ρ (kg/m³)
    public var drivetrainEfficiency: Double
    public var gravity: Double

    public init(
        totalMassKg: Double,
        cda: Double,
        crr: Double = 0.005,
        airDensity: Double = 1.225,
        drivetrainEfficiency: Double = 0.98,
        gravity: Double = 9.81
    ) {
        self.totalMassKg = totalMassKg
        self.cda = cda
        self.crr = crr
        self.airDensity = airDensity
        self.drivetrainEfficiency = drivetrainEfficiency
        self.gravity = gravity
    }

    /// CdA typique selon le type de vélo / la position aéro.
    public static func typicalCdA(bikeType: BikeType, aeroBars: Bool) -> Double {
        switch bikeType {
        case .tt: return aeroBars ? 0.24 : 0.28
        case .road: return aeroBars ? 0.29 : 0.32
        case .gravel: return 0.36
        case .mtb: return 0.42
        case .trainer: return 0.32
        }
    }

    /// Puissance pédale (W) requise pour une vitesse (m/s) et une pente (fraction, ex. 0.03).
    public func power(forSpeed v: Double, grade: Double = 0, headwind: Double = 0) -> Double {
        let rolling = totalMassKg * gravity * crr
        let climbing = totalMassKg * gravity * grade
        let apparent = v + headwind
        let aero = 0.5 * airDensity * cda * apparent * apparent
        let pWheel = (rolling + climbing) * v + aero * v
        return pWheel / drivetrainEfficiency
    }

    /// Vitesse (m/s) atteinte pour une puissance (W) donnée — inversion numérique.
    public func speed(forPower target: Double, grade: Double = 0, headwind: Double = 0) -> Double {
        precondition(target > 0)
        var lo = 0.0, hi = 30.0            // jusqu'à 108 km/h
        for _ in 0..<100 {
            let mid = (lo + hi) / 2
            if power(forSpeed: mid, grade: grade, headwind: headwind) < target { lo = mid } else { hi = mid }
            if hi - lo < 1e-4 { break }
        }
        return (lo + hi) / 2
    }

    /// Temps (s) prédit sur une distance (m) à une puissance soutenue donnée.
    public func predictTimeSeconds(distanceM d: Double, sustainedPowerW p: Double, grade: Double = 0) -> Double {
        let v = speed(forPower: p, grade: grade)
        return d / v
    }
}
