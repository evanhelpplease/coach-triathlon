import Foundation

/// État du matériel disponible à un instant T (historisé côté persistance).
public struct Equipment: Codable, Sendable, Equatable {
    public var hasBike: Bool
    public var bikeType: BikeType?
    public var bikeWeightKg: Double?
    public var hasAeroBars: Bool
    public var hasPowerMeter: Bool
    public var hasSmartTrainer: Bool

    public var poolAccess: Bool
    public var openWaterAccess: Bool
    public var hasWetsuit: Bool
    public var hasDrylandCords: Bool     // élastiques de traction à sec

    public var runOutdoor: Bool
    public var hasTreadmill: Bool
    public var hasTrack: Bool

    public enum StrengthAccess: String, Codable, Sendable {
        case gym, homeWeights, bodyweightOnly, none
    }
    public var strengthAccess: StrengthAccess

    public init(
        hasBike: Bool = false,
        bikeType: BikeType? = nil,
        bikeWeightKg: Double? = nil,
        hasAeroBars: Bool = false,
        hasPowerMeter: Bool = false,
        hasSmartTrainer: Bool = false,
        poolAccess: Bool = false,
        openWaterAccess: Bool = false,
        hasWetsuit: Bool = false,
        hasDrylandCords: Bool = false,
        runOutdoor: Bool = true,
        hasTreadmill: Bool = false,
        hasTrack: Bool = false,
        strengthAccess: StrengthAccess = .bodyweightOnly
    ) {
        self.hasBike = hasBike
        self.bikeType = bikeType
        self.bikeWeightKg = bikeWeightKg
        self.hasAeroBars = hasAeroBars
        self.hasPowerMeter = hasPowerMeter
        self.hasSmartTrainer = hasSmartTrainer
        self.poolAccess = poolAccess
        self.openWaterAccess = openWaterAccess
        self.hasWetsuit = hasWetsuit
        self.hasDrylandCords = hasDrylandCords
        self.runOutdoor = runOutdoor
        self.hasTreadmill = hasTreadmill
        self.hasTrack = hasTrack
        self.strengthAccess = strengthAccess
    }

    /// Le sport peut-il être pratiqué en l'état ?
    public func canPractice(_ sport: Sport) -> Bool {
        switch sport {
        case .swim: return poolAccess || openWaterAccess
        case .bike: return hasBike
        case .run: return runOutdoor || hasTreadmill || hasTrack
        case .strength: return strengthAccess != .none
        case .brick: return hasBike && (runOutdoor || hasTreadmill)
        }
    }
}

public struct Race: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var format: RaceFormat
    public var priority: RacePriority
    public var title: String

    public init(id: UUID = UUID(), date: Date, format: RaceFormat, priority: RacePriority, title: String) {
        self.id = id
        self.date = date
        self.format = format
        self.priority = priority
        self.title = title
    }
}
