import Foundation

/// Génère des séances structurées et détaillées (échauffement / corps / retour
/// au calme) avec cibles issues des zones individualisées, modulées par la phase.
public struct SessionGenerator: Sendable {
    public init(poolMeters: Double = 25) { self.poolMeters = poolMeters }
    public var poolMeters: Double

    public func generate(
        sport: Sport,
        intent: SessionIntent,
        phase: TrainingPhase,
        date: Date,
        zones: TrainingZones,
        profile: AthleteProfile,
        equipment: Equipment
    ) -> PlannedSession {
        var b = SessionBuilder()
        let title: String

        switch sport {
        case .run:   title = buildRun(&b, intent: intent, phase: phase, zones: zones)
        case .bike:  title = buildBike(&b, intent: intent, phase: phase, zones: zones, equipment: equipment)
        case .swim:  title = buildSwim(&b, intent: intent, phase: phase, zones: zones, profile: profile)
        case .strength: title = buildStrength(&b, phase: phase, equipment: equipment)
        case .brick: title = buildBrick(&b, phase: phase, zones: zones, equipment: equipment)
        }

        return PlannedSession(
            date: date, sport: sport, intent: intent, title: title,
            steps: b.steps,
            estimatedLoad: b.load.rounded(),
            estimatedDuration: b.seconds,
            notes: notes(sport: sport, intent: intent, equipment: equipment),
            phase: phase
        )
    }

    // MARK: - Facteur de volume selon la phase

    private func phaseVolume(_ phase: TrainingPhase) -> Double {
        switch phase {
        case .base: return 0.9
        case .build: return 1.1
        case .specific: return 1.2
        case .taper: return 0.6
        case .recovery: return 0.5
        }
    }

    // MARK: - Cibles depuis les zones (avec repli FC/RPE)

    private func runTarget(zone: Int, zones: TrainingZones) -> StepTarget {
        if let z = zones.runPace.first(where: { $0.zone == zone }) {
            return .paceRange(lowSecPerKm: z.lower, highSecPerKm: z.upper)
        }
        // Repli FC : run zone → hr zone approx.
        let hrZone = [2, 2, 4, 5, 5][min(max(zone, 1), 5) - 1]
        return .hrZone(hrZone)
    }

    private func powerTarget(zone: Int, zones: TrainingZones) -> StepTarget {
        if let z = zones.power.first(where: { $0.zone == zone }) {
            let hi = z.upper.isFinite ? z.upper : z.lower * 1.2
            return .powerRange(lowW: z.lower, highW: hi)
        }
        let hrZone = [1, 2, 3, 4, 5, 5, 5][min(max(zone, 1), 7) - 1]
        return .hrZone(hrZone)
    }

    private func swimTarget(zone: Int, zones: TrainingZones) -> StepTarget {
        if let z = zones.swimPace.first(where: { $0.zone == zone }) {
            return .swimPaceRange(lowSecPer100m: z.lower, highSecPer100m: z.upper)
        }
        return .rpe([3, 5, 7, 8, 9][min(max(zone, 1), 5) - 1])
    }

    // MARK: - Course

    private func buildRun(_ b: inout SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones) -> String {
        let vol = phaseVolume(phase)
        b.addTimed(.warmup, seconds: 600, ifValue: PlannedLoad.warmupIF, target: runTarget(zone: 1, zones: zones), cue: "Montée progressive, gammes en fin d'échauffement")
        switch intent {
        case .endurance:
            let main = 2400.0 * vol
            b.addTimed(.work, seconds: main, ifValue: PlannedLoad.workIF(.endurance), target: runTarget(zone: 1, zones: zones), cue: "Allure conversationnelle, cadence 175–180")
        case .tempo:
            b.addTimed(.work, seconds: 1500 * vol, ifValue: PlannedLoad.workIF(.tempo), target: runTarget(zone: 2, zones: zones), cue: "Tempo soutenu mais contrôlé")
        case .threshold:
            let reps = Int((4 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 360, PlannedLoad.workIF(.threshold), runTarget(zone: 3, zones: zones), "Au seuil, relâché"),
                        recovery: (120, runTarget(zone: 1, zones: zones)))
        case .vo2:
            let reps = Int((6 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 180, PlannedLoad.workIF(.vo2), runTarget(zone: 4, zones: zones), "Dur mais régulier"),
                        recovery: (180, runTarget(zone: 1, zones: zones)))
        case .sprint:
            let reps = Int((8 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 20, PlannedLoad.workIF(.sprint), runTarget(zone: 5, zones: zones), "Foulée ample, explosif"),
                        recovery: (100, runTarget(zone: 1, zones: zones)))
        default:
            b.addTimed(.work, seconds: 1800 * vol, ifValue: PlannedLoad.workIF(.recovery), target: runTarget(zone: 1, zones: zones), cue: "Footing très souple")
        }
        b.addTimed(.cooldown, seconds: 300, ifValue: PlannedLoad.recoveryIF, target: runTarget(zone: 1, zones: zones), cue: "Retour au calme")
        return "Course — \(label(intent))"
    }

    // MARK: - Vélo

    private func buildBike(_ b: inout SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones, equipment: Equipment) -> String {
        let vol = phaseVolume(phase)
        let aeroCue = equipment.hasAeroBars ? "Tenir la position aéro sur les efforts" : nil
        b.addTimed(.warmup, seconds: 600, ifValue: PlannedLoad.warmupIF, target: powerTarget(zone: 2, zones: zones), cue: "Montées de cadence 3×30\"")
        switch intent {
        case .endurance:
            b.addTimed(.work, seconds: 3000 * vol, ifValue: PlannedLoad.workIF(.endurance), target: powerTarget(zone: 2, zones: zones), cue: aeroCue ?? "Cadence 85–95")
        case .tempo:
            b.addTimed(.work, seconds: 1800 * vol, ifValue: PlannedLoad.workIF(.tempo), target: powerTarget(zone: 3, zones: zones), cue: aeroCue)
        case .threshold:
            let reps = Int((3 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 600, PlannedLoad.workIF(.threshold), powerTarget(zone: 4, zones: zones), aeroCue ?? "Puissance régulière au seuil"),
                        recovery: (300, powerTarget(zone: 1, zones: zones)))
        case .vo2:
            let reps = Int((5 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 240, PlannedLoad.workIF(.vo2), powerTarget(zone: 5, zones: zones), "Effort maximal soutenable 4 min"),
                        recovery: (240, powerTarget(zone: 1, zones: zones)))
        case .sprint:
            let reps = Int((6 * vol).rounded())
            b.addRepeat(times: reps,
                        work: (.work, 15, PlannedLoad.workIF(.sprint), powerTarget(zone: 6, zones: zones), "Sprint départ arrêté"),
                        recovery: (225, powerTarget(zone: 1, zones: zones)))
        default:
            b.addTimed(.work, seconds: 2400 * vol, ifValue: PlannedLoad.workIF(.recovery), target: powerTarget(zone: 1, zones: zones), cue: "Récup active, jambes légères")
        }
        b.addTimed(.cooldown, seconds: 300, ifValue: PlannedLoad.recoveryIF, target: powerTarget(zone: 1, zones: zones), cue: "Retour au calme")
        return "Vélo — \(label(intent))"
    }

    // MARK: - Natation

    private func buildSwim(_ b: inout SessionBuilder, intent: SessionIntent, phase: TrainingPhase, zones: TrainingZones, profile: AthleteProfile) -> String {
        let css = profile.cssSecPer100m ?? 120
        let lengthsPer100 = Int((100.0 / poolMeters).rounded())
        b.addLengths(.warmup, count: lengthsPer100 * 3, poolMeters: poolMeters, cssSecPer100m: css,
                     ifValue: PlannedLoad.warmupIF, target: swimTarget(zone: 1, zones: zones), cue: "Souple, respiration bilatérale")
        // Éducatifs systématiques.
        b.addLengths(.work, count: lengthsPer100 * 2, poolMeters: poolMeters, cssSecPer100m: css,
                     ifValue: PlannedLoad.workIF(.technique), target: .rpe(4), cue: "Éducatifs : rattrapé, poings fermés")
        let vol = phaseVolume(phase)
        switch intent {
        case .technique:
            b.addLengths(.work, count: lengthsPer100 * 6, poolMeters: poolMeters, cssSecPer100m: css,
                         ifValue: PlannedLoad.workIF(.technique), target: .rpe(5), cue: "Focus technique, tempo maîtrisé")
        case .endurance:
            b.addLengths(.work, count: Int(Double(lengthsPer100 * 12) * vol), poolMeters: poolMeters, cssSecPer100m: css,
                         ifValue: PlannedLoad.workIF(.endurance), target: swimTarget(zone: 2, zones: zones), cue: "Continu régulier")
        case .threshold:
            let reps = Int((8 * vol).rounded())
            for _ in 0..<reps {
                b.addLengths(.work, count: lengthsPer100, poolMeters: poolMeters, cssSecPer100m: css,
                             ifValue: PlannedLoad.workIF(.threshold), target: swimTarget(zone: 3, zones: zones), cue: "100 au seuil (CSS)")
            }
        case .vo2:
            let reps = Int((10 * vol).rounded())
            for _ in 0..<reps {
                b.addLengths(.work, count: max(1, lengthsPer100 / 2), poolMeters: poolMeters, cssSecPer100m: css,
                             ifValue: PlannedLoad.workIF(.vo2), target: swimTarget(zone: 4, zones: zones), cue: "50 rapide")
            }
        default:
            b.addLengths(.work, count: lengthsPer100 * 8, poolMeters: poolMeters, cssSecPer100m: css,
                         ifValue: PlannedLoad.workIF(.endurance), target: swimTarget(zone: 2, zones: zones), cue: "Aérobie")
        }
        b.addLengths(.cooldown, count: lengthsPer100 * 2, poolMeters: poolMeters, cssSecPer100m: css,
                     ifValue: PlannedLoad.recoveryIF, target: swimTarget(zone: 1, zones: zones), cue: "Décrassage")
        return "Natation — \(label(intent))"
    }

    // MARK: - Renforcement

    private func buildStrength(_ b: inout SessionBuilder, phase: TrainingPhase, equipment: Equipment) -> String {
        b.addTimed(.warmup, seconds: 300, ifValue: PlannedLoad.warmupIF, target: .rpe(3), cue: "Mobilité hanches/épaules, activation")
        let rounds = phase == .base ? 4 : 3
        b.addRepeat(times: rounds,
                    work: (.work, 480, PlannedLoad.workIF(.strength),
                           .rpe(equipment.strengthAccess == .gym ? 8 : 7),
                           equipment.strengthAccess == .bodyweightOnly ? "Gainage, fentes, pont fessier, pompes" : "Squat, soulevé de terre, gainage"),
                    recovery: (120, .rpe(2)))
        b.addTimed(.cooldown, seconds: 300, ifValue: PlannedLoad.recoveryIF, target: .rpe(2), cue: "Étirements doux")
        return "Renforcement — préventif"
    }

    // MARK: - Brick (enchaînement vélo → course)

    private func buildBrick(_ b: inout SessionBuilder, phase: TrainingPhase, zones: TrainingZones, equipment: Equipment) -> String {
        let vol = phaseVolume(phase)
        b.addTimed(.warmup, seconds: 600, ifValue: PlannedLoad.warmupIF, target: powerTarget(zone: 2, zones: zones))
        b.addTimed(.work, seconds: 2400 * vol, ifValue: PlannedLoad.workIF(.brick), target: powerTarget(zone: 3, zones: zones),
                   cue: equipment.hasAeroBars ? "Vélo en position aéro, allure course cible" : "Vélo allure course cible")
        b.addTimed(.work, seconds: 1200 * vol, ifValue: PlannedLoad.workIF(.brick), target: runTarget(zone: 2, zones: zones),
                   cue: "Transition rapide, jambes lourdes normal, monter en allure progressivement")
        b.addTimed(.cooldown, seconds: 300, ifValue: PlannedLoad.recoveryIF, target: runTarget(zone: 1, zones: zones))
        return "Brick — enchaînement vélo/course"
    }

    // MARK: - Libellés & consignes

    private func label(_ intent: SessionIntent) -> String {
        switch intent {
        case .recovery: return "récupération"
        case .endurance: return "endurance"
        case .tempo: return "tempo"
        case .threshold: return "seuil"
        case .vo2: return "VO2max"
        case .sprint: return "sprint"
        case .technique: return "technique"
        case .brick: return "brick"
        case .strength: return "force"
        }
    }

    private func notes(sport: Sport, intent: SessionIntent, equipment: Equipment) -> String {
        switch sport {
        case .swim where !equipment.poolAccess && !equipment.openWaterAccess:
            return "Pas d'accès à l'eau : à convertir en travail à sec (voir adaptation matériel)."
        case .bike where equipment.hasSmartTrainer:
            return "Home trainer connecté : séance exécutable en ERG."
        default:
            return ""
        }
    }
}
