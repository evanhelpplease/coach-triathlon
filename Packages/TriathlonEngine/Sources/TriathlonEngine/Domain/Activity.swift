import Foundation

/// Activité réellement réalisée, importée depuis Health/Garmin ou saisie.
public struct CompletedActivity: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var sport: Sport
    public var start: Date
    public var duration: TimeInterval
    public var distanceM: Double?
    public var avgHr: Int?
    public var maxHr: Int?
    public var avgPowerW: Int?
    public var normalizedPowerW: Int?
    public var avgPaceSecPerKm: Double?
    public var hrDriftPct: Double?
    public var poolLengths: Int?
    public var rpe: Int?
    public var source: DataSource

    public init(
        id: UUID = UUID(),
        sport: Sport,
        start: Date,
        duration: TimeInterval,
        distanceM: Double? = nil,
        avgHr: Int? = nil,
        maxHr: Int? = nil,
        avgPowerW: Int? = nil,
        normalizedPowerW: Int? = nil,
        avgPaceSecPerKm: Double? = nil,
        hrDriftPct: Double? = nil,
        poolLengths: Int? = nil,
        rpe: Int? = nil,
        source: DataSource = .manual
    ) {
        self.id = id
        self.sport = sport
        self.start = start
        self.duration = duration
        self.distanceM = distanceM
        self.avgHr = avgHr
        self.maxHr = maxHr
        self.avgPowerW = avgPowerW
        self.normalizedPowerW = normalizedPowerW
        self.avgPaceSecPerKm = avgPaceSecPerKm
        self.hrDriftPct = hrDriftPct
        self.poolLengths = poolLengths
        self.rpe = rpe
        self.source = source
    }
}

/// Check-in subjectif quotidien (1–5, 5 = au top).
public struct SubjectiveCheckin: Codable, Sendable, Equatable {
    public var form: Int
    public var sleepQuality: Int
    public var soreness: Int          // 5 = aucune courbature
    public var motivation: Int
    public init(form: Int, sleepQuality: Int, soreness: Int, motivation: Int) {
        self.form = form
        self.sleepQuality = sleepQuality
        self.soreness = soreness
        self.motivation = motivation
    }
}

/// État de récupération d'un jour donné (objectif + subjectif).
public struct DailyReadiness: Codable, Sendable, Equatable {
    public var date: Date
    public var sleepHours: Double?
    public var hrRest: Int?
    public var hrvMs: Double?
    public var bodyBattery: Int?
    public var subjective: SubjectiveCheckin?

    public init(
        date: Date,
        sleepHours: Double? = nil,
        hrRest: Int? = nil,
        hrvMs: Double? = nil,
        bodyBattery: Int? = nil,
        subjective: SubjectiveCheckin? = nil
    ) {
        self.date = date
        self.sleepHours = sleepHours
        self.hrRest = hrRest
        self.hrvMs = hrvMs
        self.bodyBattery = bodyBattery
        self.subjective = subjective
    }
}
