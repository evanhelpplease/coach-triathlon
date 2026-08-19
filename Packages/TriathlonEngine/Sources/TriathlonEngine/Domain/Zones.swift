import Foundation

/// Une borne de zone. Les unités dépendent du contexte :
/// - FC : battements/min
/// - allure course : secondes/km
/// - allure natation : secondes/100 m
/// - puissance : watts
public struct ZoneBoundary: Codable, Sendable, Equatable {
    public var zone: Int          // 1...N
    public var label: String      // ex. "Endurance", "Seuil"
    public var lower: Double      // borne basse (incluse)
    public var upper: Double      // borne haute (exclue) ; .infinity pour la dernière

    public init(zone: Int, label: String, lower: Double, upper: Double) {
        self.zone = zone
        self.label = label
        self.lower = lower
        self.upper = upper
    }

    public func contains(_ value: Double) -> Bool {
        value >= lower && value < upper
    }
}

public enum ZoneSource: String, Codable, Sendable {
    case test, estimated, autoRecalibrated
}

/// Jeu complet de zones individualisées.
/// Pour les allures, une valeur plus BASSE = plus rapide, donc l'ordre des
/// bornes est inversé par rapport à la FC/puissance (documenté par zone).
public struct TrainingZones: Codable, Sendable, Equatable {
    public var hr: [ZoneBoundary]        // bpm, croissant
    public var runPace: [ZoneBoundary]   // s/km, une borne = plage d'allure par zone
    public var swimPace: [ZoneBoundary]  // s/100m
    public var power: [ZoneBoundary]     // W, croissant
    public var updatedAt: Date
    public var source: ZoneSource

    public init(
        hr: [ZoneBoundary] = [],
        runPace: [ZoneBoundary] = [],
        swimPace: [ZoneBoundary] = [],
        power: [ZoneBoundary] = [],
        updatedAt: Date = Date(),
        source: ZoneSource = .estimated
    ) {
        self.hr = hr
        self.runPace = runPace
        self.swimPace = swimPace
        self.power = power
        self.updatedAt = updatedAt
        self.source = source
    }
}
