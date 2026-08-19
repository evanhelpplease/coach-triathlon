import Foundation
import TriathlonEngine

/// Capacités déclarées d'une source de données (permet de fusionner intelligemment).
struct ProviderCapabilities: Sendable {
    var readsActivities: Bool
    var readsReadiness: Bool          // sommeil, FC repos, VFC
    var writesWorkouts: Bool
}

/// Abstraction d'une source santé. Apple Health, Garmin (via Health en Phase 1,
/// API directe en Phase 3) et la saisie manuelle sont interchangeables ET cumulables.
protocol HealthDataProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    var capabilities: ProviderCapabilities { get }

    func authorize() async throws
    func importActivities(since: Date) async throws -> [CompletedActivity]
    func importReadiness(since: Date) async throws -> [DailyReadiness]
    func writeCompletedWorkout(_ activity: CompletedActivity) async throws
}

enum ProviderError: Error { case unavailable, notAuthorized, unsupported }

/// Fusionne plusieurs sources : déduplique les activités (même sport, chevauchement
/// temporel) en gardant la plus riche, et agrège les données de récupération par jour.
struct ProviderCoordinator: Sendable {
    let providers: [HealthDataProvider]

    func importActivities(since: Date) async -> [CompletedActivity] {
        var all: [CompletedActivity] = []
        for p in providers where p.capabilities.readsActivities {
            if let acts = try? await p.importActivities(since: since) { all.append(contentsOf: acts) }
        }
        return dedupe(all)
    }

    func importReadiness(since: Date) async -> [DailyReadiness] {
        var byDay: [Date: DailyReadiness] = [:]
        let cal = Calendar(identifier: .gregorian)
        for p in providers where p.capabilities.readsReadiness {
            guard let items = try? await p.importReadiness(since: since) else { continue }
            for r in items {
                let day = cal.startOfDay(for: r.date)
                byDay[day] = merge(byDay[day], r)   // la source la plus riche l'emporte champ par champ
            }
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    /// Déduplication : deux activités du même sport à moins de 5 min d'écart = la même.
    private func dedupe(_ activities: [CompletedActivity]) -> [CompletedActivity] {
        var kept: [CompletedActivity] = []
        for a in activities.sorted(by: { $0.start < $1.start }) {
            if let idx = kept.firstIndex(where: { $0.sport == a.sport && abs($0.start.timeIntervalSince(a.start)) < 300 }) {
                kept[idx] = richer(kept[idx], a)
            } else {
                kept.append(a)
            }
        }
        return kept
    }

    private func richer(_ a: CompletedActivity, _ b: CompletedActivity) -> CompletedActivity {
        func score(_ x: CompletedActivity) -> Int {
            [x.avgPowerW != nil, x.avgHr != nil, x.avgPaceSecPerKm != nil, x.distanceM != nil].filter { $0 }.count
        }
        return score(b) > score(a) ? b : a
    }

    private func merge(_ existing: DailyReadiness?, _ new: DailyReadiness) -> DailyReadiness {
        guard var e = existing else { return new }
        e.sleepHours = e.sleepHours ?? new.sleepHours
        e.hrRest = e.hrRest ?? new.hrRest
        e.hrvMs = e.hrvMs ?? new.hrvMs
        e.bodyBattery = e.bodyBattery ?? new.bodyBattery
        e.subjective = e.subjective ?? new.subjective
        return e
    }
}
