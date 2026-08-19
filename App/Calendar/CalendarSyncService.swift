import Foundation
import EventKit
import TriathlonEngine

/// Synchronise les séances vers le calendrier Apple (EventKit). Idempotent : les
/// événements précédemment créés par l'app (marqueur en notes) sont remplacés.
/// (La synchro Google Agenda via OAuth est un module ultérieur.)
enum CalendarSyncService {
    private static let marker = "[CoachTri]"

    enum SyncError: Error { case notAuthorized }

    static func requestAccess() async -> Bool {
        let store = EKEventStore()
        return (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Remplace les événements « Coach Tri » des 28 prochains jours par les séances.
    static func sync(sessions: [PlannedSession]) async throws {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { throw SyncError.notAuthorized }

        let cal = Calendar(identifier: .gregorian)
        let start = cal.startOfDay(for: .now)
        let end = cal.date(byAdding: .day, value: 28, to: start)!

        // Purge des anciens événements marqués.
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        for event in store.events(matching: predicate) where (event.notes ?? "").contains(marker) {
            try? store.remove(event, span: .thisEvent, commit: false)
        }

        // Création des séances à venir.
        let target = store.defaultCalendarForNewEvents
        for session in sessions where session.date >= start && session.date < end {
            let event = EKEvent(eventStore: store)
            event.calendar = target
            event.title = "🏊🚴🏃 \(session.title)"
            var comps = cal.dateComponents([.year, .month, .day], from: session.date)
            comps.hour = 7; comps.minute = 0
            let startDate = cal.date(from: comps) ?? session.date
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(max(1800, session.estimatedDuration))
            event.notes = "\(sessionNotes(session))\n\n\(marker)"
            try? store.save(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    private static func sessionNotes(_ s: PlannedSession) -> String {
        var lines = ["Charge \(Int(s.estimatedLoad)) · \(Format.minutes(s.estimatedDuration))"]
        if !s.notes.isEmpty { lines.append(s.notes) }
        for step in s.steps.prefix(6) {
            if let cue = step.cue { lines.append("• \(cue)") }
        }
        return lines.joined(separator: "\n")
    }
}
