import Foundation

/// Modèle VDOT de Jack Daniels (course à pied).
///
/// Basé sur les équations publiées :
/// - Coût en O₂ d'une vitesse v (m/min) :
///   `VO2 = -4.60 + 0.182258·v + 0.000104·v²`
/// - Fraction de VO₂max soutenable pour une durée t (min) :
///   `%max = 0.8 + 0.1894393·e^(-0.012778·t) + 0.2989558·e^(-0.1932605·t)`
/// - `VDOT = VO2(v) / %max(t)` pour une course de durée t à la vitesse v.
public enum VDOT {

    /// Coût énergétique (ml/kg/min) d'une vitesse en m/min.
    public static func vo2Cost(velocityMetersPerMin v: Double) -> Double {
        -4.60 + 0.182258 * v + 0.000104 * v * v
    }

    /// Fraction de VO₂max soutenable pour une durée (minutes).
    public static func fractionOfMax(durationMin t: Double) -> Double {
        0.8
        + 0.1894393 * exp(-0.012778 * t)
        + 0.2989558 * exp(-0.1932605 * t)
    }

    /// Calcule le VDOT à partir d'une performance (distance en m, temps en s).
    public static func vdot(distanceMeters d: Double, timeSeconds t: Double) -> Double {
        precondition(d > 0 && t > 0)
        let minutes = t / 60.0
        let v = d / minutes                     // m/min
        return vo2Cost(velocityMetersPerMin: v) / fractionOfMax(durationMin: minutes)
    }

    /// Prédit le temps (s) sur une distance (m) pour un VDOT donné.
    /// Résolution numérique par bissection : f(t) = VO2(d/t) − VDOT·%max(t)
    /// est décroissante en t, donc la bissection converge.
    public static func predictTimeSeconds(vdot: Double, distanceMeters d: Double) -> Double {
        precondition(vdot > 0 && d > 0)
        func f(_ tSeconds: Double) -> Double {
            let minutes = tSeconds / 60.0
            let v = d / minutes
            return vo2Cost(velocityMetersPerMin: v) - vdot * fractionOfMax(durationMin: minutes)
        }
        // Bornes larges : de 1 min à 10 h.
        var lo = 60.0
        var hi = 36_000.0
        // f(lo) doit être > 0 (trop rapide) et f(hi) < 0 (trop lent).
        for _ in 0..<100 {
            let mid = (lo + hi) / 2
            if f(mid) > 0 { lo = mid } else { hi = mid }
            if hi - lo < 0.01 { break }
        }
        return (lo + hi) / 2
    }

    /// Allures d'entraînement (s/km) dérivées du VDOT, par fraction de VO₂max.
    public struct TrainingPaces: Equatable, Sendable {
        public var easySecPerKm: Double
        public var marathonSecPerKm: Double
        public var thresholdSecPerKm: Double
        public var intervalSecPerKm: Double
        public var repetitionSecPerKm: Double
    }

    /// Vitesse (m/min) soutenable à une fraction donnée de VO₂max.
    /// On inverse `vo2Cost` : 0.000104·v² + 0.182258·v − (4.60 + VO2target) = 0.
    public static func velocityForVO2(_ vo2Target: Double) -> Double {
        let a = 0.000104, b = 0.182258, c = -(4.60 + vo2Target)
        let disc = b * b - 4 * a * c
        return (-b + disc.squareRoot()) / (2 * a)   // racine positive
    }

    public static func trainingPaces(vdot: Double) -> TrainingPaces {
        func pace(atFraction f: Double) -> Double {
            let v = velocityForVO2(vdot * f)         // m/min
            return 1000.0 / (v / 60.0)               // s/km
        }
        return TrainingPaces(
            easySecPerKm: pace(atFraction: 0.70),
            marathonSecPerKm: pace(atFraction: 0.82),
            thresholdSecPerKm: pace(atFraction: 0.88),
            intervalSecPerKm: pace(atFraction: 0.98),
            repetitionSecPerKm: pace(atFraction: 1.05)
        )
    }
}
