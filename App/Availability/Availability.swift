import Foundation
import TriathlonEngine

/// Indisponibilité d'un sport sur une période (ou ponctuelle sur une journée).
/// « Jusqu'à date indéterminée, pas de piscine » = end nil.
/// « Pas de vélo sur la séance de jeudi » = période d'un jour.
struct Unavailability: Identifiable, Sendable {
    var id: UUID
    var sport: Sport
    var start: Date
    var end: Date?
    var note: String

    func isActive(on date: Date, calendar: Calendar = .init(identifier: .gregorian)) -> Bool {
        let day = calendar.startOfDay(for: date)
        let from = calendar.startOfDay(for: start)
        guard day >= from else { return false }
        if let end { return day <= calendar.startOfDay(for: end) }
        return true // indéterminé
    }
}

enum Availability {
    /// Équipement effectif à une date : équipement de base moins les sports indisponibles.
    static func effectiveEquipment(base: Equipment, unavailabilities: [Unavailability], on date: Date) -> Equipment {
        var e = base
        for u in unavailabilities where u.isActive(on: date) {
            switch u.sport {
            case .swim:
                e.poolAccess = false; e.openWaterAccess = false
            case .bike, .brick:
                e.hasBike = false
            case .run:
                e.runOutdoor = false; e.hasTreadmill = false; e.hasTrack = false
            case .strength:
                e.strengthAccess = .none
            }
        }
        return e
    }
}
