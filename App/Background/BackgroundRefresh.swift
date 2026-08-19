import Foundation
import BackgroundTasks
import SwiftData
import TriathlonEngine

/// Rafraîchissement en arrière-plan : reprogramme les rappels de séance (et, à
/// terme, réimporte les activités). Déclenché par `BGAppRefreshTask`.
enum BackgroundRefresh {
    static let id = "com.evanblanchard.coachtriathlon.refresh"

    /// Référence au conteneur de l'app (évite d'en créer un second sur le même store).
    static var container: ModelContainer?

    /// Programme le prochain rafraîchissement (~4 h plus tard).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Travail exécuté au réveil : reprogramme la tâche suivante + les rappels.
    @MainActor
    static func handle() async {
        schedule()
        guard let container else { return }
        let context = ModelContext(container)
        let sessions = (try? context.fetch(FetchDescriptor<PlannedSessionModel>())) ?? []
        if UserDefaults.standard.bool(forKey: "remindersOn") {
            await NotificationService.scheduleReminders(for: sessions.map { $0.domain })
        }
    }
}
