import Foundation
import SwiftData
import TriathlonEngine

// Modèles SwiftData (persistance + sync iCloud). Chaque propriété a une valeur
// par défaut ou est optionnelle — requis pour la compatibilité CloudKit.

@Model
final class ProfileModel {
    var birthDate: Date = Date(timeIntervalSince1970: 631152000)
    var sexRaw: String = "male"
    var heightCm: Double = 175
    var weightKg: Double = 70
    var hrMax: Int?
    var hrRest: Int?
    var ftpWatts: Int?
    var cssSecPer100m: Double?
    var vdot: Double?
    var swimLevel: Int = 1
    var bikeLevel: Int = 1
    var runLevel: Int = 1
    var weeklyHours: Double = 5
    var goalTypeRaw: String = "race"          // "fun" | "improve" | "race"
    var progressionRaw: String = "balanced"   // "prudent" | "balanced" | "performance"
    var availableWeekdaysMask: Int = 127      // bits weekday 1..7 (dim..sam)
    var maxSessionsPerWeek: Int = 6
    // Restriction de jours par lieu/sport (0 = aucune restriction).
    var swimDaysMask: Int = 0
    var bikeDaysMask: Int = 0
    var runDaysMask: Int = 0
    var strengthDaysMask: Int = 0
    var createdAt: Date = Date.now

    init() {}
}

@Model
final class EquipmentModel {
    var hasBike: Bool = false
    var bikeTypeRaw: String?
    var bikeWeightKg: Double?
    var hasAeroBars: Bool = false
    var hasPowerMeter: Bool = false
    var hasSmartTrainer: Bool = false
    var poolAccess: Bool = false
    var openWaterAccess: Bool = false
    var hasWetsuit: Bool = false
    var hasDrylandCords: Bool = false
    var runOutdoor: Bool = true
    var hasTreadmill: Bool = false
    var hasTrack: Bool = false
    var strengthAccessRaw: String = "bodyweightOnly"
    var updatedAt: Date = Date.now

    init() {}
}

@Model
final class RaceModel {
    var id: UUID = UUID()
    var date: Date = Date.now
    var formatRaw: String = "olympic"
    var priorityRaw: String = "a"
    var title: String = ""
    var location: String = ""
    var targetTimeSec: Double = 0        // 0 = pas d'objectif de temps
    var isOpenGoal: Bool = false         // objectif « progression continue » sans course réelle

    init() {}
}

@Model
final class PlannedSessionModel {
    var id: UUID = UUID()
    var date: Date = Date.now
    var sportRaw: String = "run"
    var intentRaw: String = "endurance"
    var title: String = ""
    var estimatedLoad: Double = 0
    var estimatedDuration: TimeInterval = 0
    var notes: String = ""
    var phaseRaw: String?
    var stepsData: Data?          // JSON de [WorkoutStep]
    var isCompleted: Bool = false

    init() {}
}

@Model
final class DailyCheckinModel {
    var date: Date = Date.now
    var sleepHours: Double?
    var hrRest: Int?
    var hrvMs: Double?
    var form: Int?
    var sleepQuality: Int?
    var soreness: Int?
    var motivation: Int?

    init() {}
}

@Model
final class InjuryModel {
    var id: UUID = UUID()
    var zoneRaw: String = "knee"
    var detailName: String = ""   // blessure précise (catalogue)
    var intensity: Int = 3        // 1–5
    var since: Date = Date.now
    var isActive: Bool = true
    var note: String = ""

    init() {}
}

/// Indisponibilité d'un sport sur une période (ou ponctuelle sur une séance).
@Model
final class UnavailabilityModel {
    var id: UUID = UUID()
    var sportRaw: String = "swim"
    var startDate: Date = Date.now
    var endDate: Date?            // nil = jusqu'à nouvel ordre
    var note: String = ""

    init() {}
}

/// Schéma central de l'application.
enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        ProfileModel.self, EquipmentModel.self, RaceModel.self,
        PlannedSessionModel.self, DailyCheckinModel.self,
        InjuryModel.self, UnavailabilityModel.self
    ]
}
