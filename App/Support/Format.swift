import Foundation

/// Formatage cohérent des durées, allures et distances (français, métrique).
enum Format {
    /// `h:mm:ss` ou `mm:ss` selon la durée.
    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// Durée courte en minutes : `72 min` ou `1 h 12`.
    static func minutes(_ seconds: TimeInterval) -> String {
        let m = Int((seconds / 60).rounded())
        return m >= 60 ? "\(m / 60) h \(String(format: "%02d", m % 60))" : "\(m) min"
    }

    /// Allure course `m:ss/km`.
    static func runPace(_ secPerKm: Double) -> String {
        let s = Int(secPerKm.rounded())
        return String(format: "%d:%02d/km", s / 60, s % 60)
    }

    /// Allure natation `m:ss/100m`.
    static func swimPace(_ secPer100m: Double) -> String {
        let s = Int(secPer100m.rounded())
        return String(format: "%d:%02d/100m", s / 60, s % 60)
    }

    static func distanceKm(_ meters: Double) -> String {
        String(format: "%.1f km", meters / 1000)
    }

    static let fr = Locale(identifier: "fr_FR")

    /// « Mercredi 5 août » (les format styles n'héritent pas de la locale d'environnement).
    static func longDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(fr)).capitalized
    }

    /// « Vendredi 7 août ».
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month().locale(fr)).capitalized
    }
}
