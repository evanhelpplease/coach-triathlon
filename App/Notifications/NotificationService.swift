import Foundation
import UserNotifications
import TriathlonEngine

/// Notifications locales : rappels de séance du jour + alerte de récupération.
enum NotificationService {
    private static let center = UNUserNotificationCenter.current()
    private static let prefix = "coachtri-session-"

    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reprogramme les rappels pour les séances des 7 prochains jours (matin, 7 h).
    @MainActor
    static func scheduleReminders(for sessions: [PlannedSession]) async {
        cancelAll()
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: .now)
        let horizon = cal.date(byAdding: .day, value: 7, to: today)!

        for session in sessions where session.date >= today && session.date < horizon {
            let content = UNMutableNotificationContent()
            content.title = "Séance du jour : \(session.title)"
            content.body = "\(Format.minutes(session.estimatedDuration)) · charge \(Int(session.estimatedLoad)). Bonne séance ! 💪"
            content.sound = .default

            var comps = cal.dateComponents([.year, .month, .day], from: session.date)
            comps.hour = 7; comps.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = prefix + ISO8601DateFormatter().string(from: session.date)
            try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    static func cancelAll() {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
