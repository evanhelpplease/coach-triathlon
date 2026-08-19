import Foundation

/// Critical Swim Speed (natation).
///
/// À partir de deux tests (typiquement 400 m et 200 m) :
/// `CSS (m/s) = (D_long − D_court) / (T_long − T_court)`
public enum CSS {

    /// Vitesse critique en m/s à partir de deux contre-la-montre.
    public static func speedMetersPerSec(
        longDistanceM: Double, longTimeSec: Double,
        shortDistanceM: Double, shortTimeSec: Double
    ) -> Double {
        precondition(longDistanceM > shortDistanceM && longTimeSec > shortTimeSec)
        return (longDistanceM - shortDistanceM) / (longTimeSec - shortTimeSec)
    }

    /// Allure critique en secondes / 100 m.
    public static func pacePer100m(
        longDistanceM: Double, longTimeSec: Double,
        shortDistanceM: Double, shortTimeSec: Double
    ) -> Double {
        let v = speedMetersPerSec(
            longDistanceM: longDistanceM, longTimeSec: longTimeSec,
            shortDistanceM: shortDistanceM, shortTimeSec: shortTimeSec
        )
        return 100.0 / v
    }

    /// Convertit une allure (s/100 m) en vitesse (m/s).
    public static func speed(fromPacePer100m pace: Double) -> Double { 100.0 / pace }

    /// Prédit un temps (s) sur une distance (m) à partir de la CSS,
    /// avec une légère dérive de fatigue au-delà de la distance critique.
    public static func predictTimeSeconds(cssPacePer100m pace: Double, distanceM d: Double) -> Double {
        let v = speed(fromPacePer100m: pace)
        // Facteur de fatigue : la vitesse tenue baisse ~2 %/doublement au-delà de 400 m.
        let ref = 400.0
        let drift = d > ref ? pow(d / ref, 0.02) : 1.0
        return d / v * drift
    }
}
