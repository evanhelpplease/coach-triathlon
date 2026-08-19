import Foundation

/// Estimation de la charge prévue d'une séance à partir de facteurs d'intensité.
/// `charge = Σ durée_h · IF² · 100` (analogue au TSS : 1 h à IF 1.0 = 100).
enum PlannedLoad {
    /// Facteur d'intensité représentatif par intention de séance (portion "travail").
    static func workIF(_ intent: SessionIntent) -> Double {
        switch intent {
        case .recovery: return 0.55
        case .endurance: return 0.68
        case .tempo: return 0.85
        case .threshold: return 0.95
        case .vo2: return 1.08
        case .sprint: return 1.20
        case .technique: return 0.62
        case .brick: return 0.82
        case .strength: return 0.75
        }
    }

    static let warmupIF = 0.60
    static let recoveryIF = 0.50
}

/// Petit constructeur qui accumule les pas d'une séance et sa charge estimée.
struct SessionBuilder {
    private(set) var steps: [WorkoutStep] = []
    private(set) var load: Double = 0
    private(set) var seconds: TimeInterval = 0

    /// Ajoute un pas temporel en cumulant charge & durée.
    mutating func addTimed(_ kind: StepKind, seconds s: TimeInterval, ifValue: Double,
                           target: StepTarget, cue: String? = nil) {
        steps.append(WorkoutStep(kind: kind, duration: .time(seconds: s), target: target, cue: cue))
        load += (s / 3600.0) * ifValue * ifValue * 100.0
        seconds += s
    }

    /// Ajoute un bloc répété (chaque enfant est temporel).
    mutating func addRepeat(times: Int, work: (kind: StepKind, sec: TimeInterval, ifV: Double, target: StepTarget, cue: String?),
                            recovery: (sec: TimeInterval, target: StepTarget)?) {
        var children: [WorkoutStep] = [
            WorkoutStep(kind: work.kind, duration: .time(seconds: work.sec), target: work.target, cue: work.cue)
        ]
        if let r = recovery {
            children.append(WorkoutStep(kind: .recovery, duration: .time(seconds: r.sec), target: r.target))
        }
        steps.append(WorkoutStep(kind: .repeatBlock, duration: .time(seconds: 0), target: .free, repeats: times, children: children))
        load += Double(times) * (work.sec / 3600.0) * work.ifV * work.ifV * 100.0
        seconds += Double(times) * work.sec
        if let r = recovery {
            load += Double(times) * (r.sec / 3600.0) * PlannedLoad.recoveryIF * PlannedLoad.recoveryIF * 100.0
            seconds += Double(times) * r.sec
        }
    }

    /// Ajoute des longueurs de bassin (natation).
    mutating func addLengths(_ kind: StepKind, count: Int, poolMeters: Double, cssSecPer100m css: Double,
                             ifValue: Double, target: StepTarget, cue: String? = nil) {
        steps.append(WorkoutStep(kind: kind, duration: .lengths(count: count, poolMeters: poolMeters), target: target, cue: cue))
        let meters = Double(count) * poolMeters
        let s = meters / 100.0 * css
        load += (s / 3600.0) * ifValue * ifValue * 100.0
        seconds += s
    }
}
