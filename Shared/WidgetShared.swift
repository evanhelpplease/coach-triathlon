import Foundation

/// Instantané léger partagé entre l'app et le widget (via App Group).
struct WidgetSnapshot: Codable {
    var hasSession: Bool
    var todayTitle: String
    var todaySportKey: String
    var todayMinutes: Int
    var todayLoad: Int
    var formTSB: Int?
    var formLabel: String
    var raceDays: Int?
    var raceTitle: String?
    var updated: Date

    static let sample = WidgetSnapshot(
        hasSession: true, todayTitle: "Course — seuil", todaySportKey: "run",
        todayMinutes: 52, todayLoad: 61, formTSB: -8, formLabel: "Charge productive",
        raceDays: 84, raceTitle: "Triathlon M", updated: .now
    )
}

/// Stockage partagé (App Group) lu par le widget, écrit par l'app.
enum WidgetStore {
    static let appGroup = "group.com.evanblanchard.coachtriathlon"
    private static let key = "widgetSnapshot"

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
