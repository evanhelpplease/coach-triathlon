import Foundation
import ActivityKit
import TriathlonEngine

/// Démarre / arrête la Live Activity « séance en cours ».
enum SessionLiveActivityManager {
    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static var isRunning: Bool {
        !Activity<SessionActivityAttributes>.activities.isEmpty
    }

    @discardableResult
    static func start(session: PlannedSession) -> Bool {
        guard isSupported, !isRunning else { return false }
        let attributes = SessionActivityAttributes(title: session.title, sportKey: session.sport.rawValue)
        let firstStep = session.steps.first?.cue ?? "C'est parti !"
        let state = SessionActivityAttributes.ContentState(startedAt: .now, stepName: firstStep)
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            return true
        } catch {
            return false
        }
    }

    static func end() {
        Task {
            for activity in Activity<SessionActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
