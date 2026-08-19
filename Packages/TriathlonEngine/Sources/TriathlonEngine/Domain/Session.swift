import Foundation

public enum StepKind: String, Codable, Sendable {
    case warmup, work, recovery, rest, cooldown, repeatBlock
}

/// Cible d'un pas de séance.
public enum StepTarget: Codable, Sendable, Equatable {
    case hrZone(Int)
    case paceRange(lowSecPerKm: Double, highSecPerKm: Double)
    case swimPaceRange(lowSecPer100m: Double, highSecPer100m: Double)
    case powerRange(lowW: Double, highW: Double)
    case rpe(Int)                 // 1–10
    case free
}

/// Durée d'un pas : temps, distance, ou longueurs de bassin.
public enum StepDuration: Codable, Sendable, Equatable {
    case time(seconds: TimeInterval)
    case distance(meters: Double)
    case lengths(count: Int, poolMeters: Double)

    /// Durée estimée en secondes, pour le calcul de charge et l'agenda.
    public func estimatedSeconds(paceSecPerKm: Double?) -> TimeInterval {
        switch self {
        case .time(let s): return s
        case .distance(let m):
            guard let pace = paceSecPerKm else { return m / 3.0 } // défaut ~3 m/s
            return (m / 1000.0) * pace
        case .lengths(let count, let poolMeters):
            let m = Double(count) * poolMeters
            let pace = paceSecPerKm ?? (95.0 * 10) // ~1:35/100m → s/km équiv.
            return (m / 1000.0) * pace
        }
    }
}

public struct WorkoutStep: Codable, Sendable, Equatable {
    public var kind: StepKind
    public var duration: StepDuration
    public var target: StepTarget
    public var cue: String?
    public var repeats: Int?          // pour repeatBlock
    public var children: [WorkoutStep]?

    public init(
        kind: StepKind,
        duration: StepDuration,
        target: StepTarget = .free,
        cue: String? = nil,
        repeats: Int? = nil,
        children: [WorkoutStep]? = nil
    ) {
        self.kind = kind
        self.duration = duration
        self.target = target
        self.cue = cue
        self.repeats = repeats
        self.children = children
    }
}

public struct PlannedSession: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var date: Date
    public var sport: Sport
    public var intent: SessionIntent
    public var title: String
    public var steps: [WorkoutStep]
    public var estimatedLoad: Double        // charge (TSS-like)
    public var estimatedDuration: TimeInterval
    public var notes: String
    public var phase: TrainingPhase?

    public init(
        id: UUID = UUID(),
        date: Date,
        sport: Sport,
        intent: SessionIntent,
        title: String,
        steps: [WorkoutStep] = [],
        estimatedLoad: Double = 0,
        estimatedDuration: TimeInterval = 0,
        notes: String = "",
        phase: TrainingPhase? = nil
    ) {
        self.id = id
        self.date = date
        self.sport = sport
        self.intent = intent
        self.title = title
        self.steps = steps
        self.estimatedLoad = estimatedLoad
        self.estimatedDuration = estimatedDuration
        self.notes = notes
        self.phase = phase
    }
}
