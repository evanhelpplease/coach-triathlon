import Foundation
import TriathlonEngine

/// Source de démo : données réalistes générées, pour tester toute l'app sans
/// aucun compte ni permission (mode démo / previews / simulateur).
struct MockHealthProvider: HealthDataProvider {
    let id = "mock"
    let displayName = "Démo"
    let capabilities = ProviderCapabilities(readsActivities: true, readsReadiness: true, writesWorkouts: true)

    func authorize() async throws {}

    func importActivities(since: Date) async throws -> [CompletedActivity] {
        let cal = Calendar(identifier: .gregorian)
        var out: [CompletedActivity] = []
        for day in 0..<14 {
            guard let date = cal.date(byAdding: .day, value: -day, to: .now) else { continue }
            if day % 3 == 0 {
                out.append(CompletedActivity(sport: .run, start: date, duration: 3000,
                                             distanceM: 8500, avgHr: 148, avgPaceSecPerKm: 353,
                                             hrDriftPct: 3.2, rpe: 6, source: .appleHealth))
            } else if day % 3 == 1 {
                out.append(CompletedActivity(sport: .bike, start: date, duration: 4200,
                                             distanceM: 34000, avgHr: 142, avgPowerW: 205,
                                             normalizedPowerW: 218, rpe: 5, source: .appleHealth))
            } else {
                out.append(CompletedActivity(sport: .swim, start: date, duration: 2400,
                                             distanceM: 2200, avgHr: 135, poolLengths: 88, rpe: 5, source: .appleHealth))
            }
        }
        return out.filter { $0.start >= since }
    }

    func importReadiness(since: Date) async throws -> [DailyReadiness] {
        let cal = Calendar(identifier: .gregorian)
        return (0..<14).compactMap { day in
            guard let date = cal.date(byAdding: .day, value: -day, to: .now) else { return nil }
            let jitter = Double((day * 7) % 11) - 5
            return DailyReadiness(date: date, sleepHours: 7.5 + jitter / 10,
                                  hrRest: 48 + (day % 4), hrvMs: 78 + jitter,
                                  bodyBattery: 70 - (day % 5) * 4, subjective: nil)
        }.filter { $0.date >= since }
    }

    func writeCompletedWorkout(_ activity: CompletedActivity) async throws {}
}
