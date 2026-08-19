import Foundation
import TriathlonEngine

/// Génère des séances de TEST de terrain pour établir les référentiels manquants
/// (VMA course, FTP vélo, CSS natation). Insérées tôt dans le plan.
enum TestSessions {

    static func make(for sport: Sport, date: Date, poolMeters: Double = 25) -> PlannedSession {
        switch sport {
        case .run:  return runVMA(date: date)
        case .bike: return bikeFTP(date: date)
        case .swim: return swimCSS(date: date, poolMeters: poolMeters)
        default:    return runVMA(date: date)
        }
    }

    static func isTest(_ session: PlannedSession) -> Bool {
        session.title.hasPrefix("Test ")
    }

    // MARK: Course — test VMA (6 min max)

    private static func runVMA(date: Date) -> PlannedSession {
        let steps = [
            WorkoutStep(kind: .warmup, duration: .time(seconds: 900), target: .rpe(4),
                        cue: "Échauffement progressif 15 min + 3 lignes droites"),
            WorkoutStep(kind: .work, duration: .time(seconds: 360), target: .rpe(10),
                        cue: "6 min à la vitesse MAX que tu peux tenir régulièrement — note la distance parcourue"),
            WorkoutStep(kind: .cooldown, duration: .time(seconds: 600), target: .rpe(3),
                        cue: "Retour au calme 10 min")
        ]
        return PlannedSession(
            date: date, sport: .run, intent: .vo2, title: "Test VMA (6 min)",
            steps: steps, estimatedLoad: 55, estimatedDuration: 1860,
            notes: "VMA ≈ distance(m) / 100. Saisis ensuite ta VMA dans le profil : le plan se recalibre.",
            phase: .base
        )
    }

    // MARK: Vélo — test FTP (20 min)

    private static func bikeFTP(date: Date) -> PlannedSession {
        let steps = [
            WorkoutStep(kind: .warmup, duration: .time(seconds: 1200), target: .rpe(4),
                        cue: "20 min échauffement dont 3×1 min vifs"),
            WorkoutStep(kind: .work, duration: .time(seconds: 1200), target: .rpe(9),
                        cue: "20 min à la puissance/allure MAX soutenable et RÉGULIÈRE — note la puissance moyenne"),
            WorkoutStep(kind: .cooldown, duration: .time(seconds: 600), target: .rpe(3),
                        cue: "10 min retour au calme")
        ]
        return PlannedSession(
            date: date, sport: .bike, intent: .threshold, title: "Test FTP (20 min)",
            steps: steps, estimatedLoad: 70, estimatedDuration: 3000,
            notes: "FTP ≈ 95 % de la puissance moyenne des 20 min. Saisis-la dans le profil.",
            phase: .base
        )
    }

    // MARK: Natation — test CSS (400 m + 200 m)

    private static func swimCSS(date: Date, poolMeters: Double) -> PlannedSession {
        let lengths400 = Int((400 / poolMeters).rounded())
        let lengths200 = Int((200 / poolMeters).rounded())
        let steps = [
            WorkoutStep(kind: .warmup, duration: .lengths(count: max(1, Int(300 / poolMeters)), poolMeters: poolMeters),
                        target: .rpe(4), cue: "300 m souple + éducatifs"),
            WorkoutStep(kind: .work, duration: .lengths(count: lengths400, poolMeters: poolMeters),
                        target: .rpe(9), cue: "400 m contre-la-montre — note ton temps"),
            WorkoutStep(kind: .rest, duration: .time(seconds: 300), target: .free, cue: "5 min récup complète"),
            WorkoutStep(kind: .work, duration: .lengths(count: lengths200, poolMeters: poolMeters),
                        target: .rpe(9), cue: "200 m contre-la-montre — note ton temps"),
            WorkoutStep(kind: .cooldown, duration: .lengths(count: max(1, Int(200 / poolMeters)), poolMeters: poolMeters),
                        target: .rpe(3), cue: "200 m décrassage")
        ]
        return PlannedSession(
            date: date, sport: .swim, intent: .threshold, title: "Test CSS (400 m + 200 m)",
            steps: steps, estimatedLoad: 45, estimatedDuration: 2400,
            notes: "CSS (s/100m) = 100 × (400−200) / (T400−T200). Saisis tes deux temps dans le profil.",
            phase: .base
        )
    }
}
