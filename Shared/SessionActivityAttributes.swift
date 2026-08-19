import Foundation
import ActivityKit

/// Live Activity « séance en cours » (écran verrouillé + Dynamic Island).
struct SessionActivityAttributes: ActivityAttributes {
    /// État dynamique mis à jour pendant la séance.
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var stepName: String
    }
    /// Données fixes de la séance.
    var title: String
    var sportKey: String
}
