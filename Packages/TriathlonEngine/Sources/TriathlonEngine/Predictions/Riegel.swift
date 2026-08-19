import Foundation

/// Modèle de Riegel pour extrapoler un temps entre deux distances :
/// `T2 = T1 · (D2/D1)^b`, avec b ≈ 1.06 pour la course d'endurance.
public enum Riegel {
    public static let defaultExponent = 1.06

    public static func predictTimeSeconds(
        knownDistanceMeters d1: Double,
        knownTimeSeconds t1: Double,
        targetDistanceMeters d2: Double,
        exponent b: Double = defaultExponent
    ) -> Double {
        precondition(d1 > 0 && t1 > 0 && d2 > 0)
        return t1 * pow(d2 / d1, b)
    }

    /// Estime l'exposant de fatigue propre à l'athlète à partir de deux perfs.
    public static func fittedExponent(
        d1: Double, t1: Double, d2: Double, t2: Double
    ) -> Double {
        precondition(d1 > 0 && t1 > 0 && d2 > 0 && t2 > 0 && d1 != d2)
        return log(t2 / t1) / log(d2 / d1)
    }
}
