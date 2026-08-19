import Foundation
import HealthKit
import TriathlonEngine

/// Source Apple Health (Phase 1). Les données Garmin y remontent déjà via l'app
/// Garmin Connect officielle : ce chemin couvre donc Garmin sans API dédiée.
struct AppleHealthProvider: HealthDataProvider {
    let id = "appleHealth"
    let displayName = "Apple Santé"
    let capabilities = ProviderCapabilities(readsActivities: true, readsReadiness: true, writesWorkouts: true)

    private let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: Autorisation

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [.workoutType()]
        let ids: [HKQuantityTypeIdentifier] = [
            .restingHeartRate, .heartRateVariabilitySDNN, .heartRate,
            .bodyMass, .distanceWalkingRunning, .distanceCycling, .distanceSwimming, .activeEnergyBurned
        ]
        ids.forEach { types.insert(HKQuantityType($0)) }
        types.insert(HKCategoryType(.sleepAnalysis))
        return types
    }

    func authorize() async throws {
        guard Self.isAvailable else { throw ProviderError.unavailable }
        try await store.requestAuthorization(toShare: [.workoutType()], read: readTypes)
    }

    // MARK: Import des activités

    func importActivities(since: Date) async throws -> [CompletedActivity] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        let workouts = try await descriptor.result(for: store)
        return workouts.map { map($0) }
    }

    private func map(_ w: HKWorkout) -> CompletedActivity {
        let sport = Self.sport(from: w.workoutActivityType)
        let distanceType: HKQuantityType? = {
            switch sport {
            case .run: return HKQuantityType(.distanceWalkingRunning)
            case .bike: return HKQuantityType(.distanceCycling)
            case .swim: return HKQuantityType(.distanceSwimming)
            default: return nil
            }
        }()
        let distance = distanceType.flatMap { w.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
        return CompletedActivity(
            id: w.uuid, sport: sport, start: w.startDate, duration: w.duration,
            distanceM: distance, source: .appleHealth
        )
    }

    // MARK: Import de la récupération

    func importReadiness(since: Date) async throws -> [DailyReadiness] {
        async let resting = dailyAverage(.restingHeartRate, unit: HKUnit(from: "count/min"), since: since)
        async let hrv = dailyAverage(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), since: since)

        let restingByDay = try await resting
        let hrvByDay = try await hrv
        let cal = Calendar(identifier: .gregorian)

        let days = Set(restingByDay.keys).union(hrvByDay.keys)
        return days.map { day in
            DailyReadiness(date: day,
                           hrRest: restingByDay[day].map { Int($0.rounded()) },
                           hrvMs: hrvByDay[day])
        }.sorted { $0.date < $1.date }
        .map { r in
            var copy = r; copy.date = cal.startOfDay(for: r.date); return copy
        }
    }

    /// Moyenne quotidienne d'un type quantitatif, indexée par début de journée.
    private func dailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async throws -> [Date: Double] {
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        let samples = try await descriptor.result(for: store)
        let cal = Calendar(identifier: .gregorian)
        var sums: [Date: (total: Double, count: Int)] = [:]
        for s in samples {
            let day = cal.startOfDay(for: s.startDate)
            let value = s.quantity.doubleValue(for: unit)
            let entry = sums[day] ?? (0, 0)
            sums[day] = (entry.total + value, entry.count + 1)
        }
        return sums.mapValues { $0.total / Double($0.count) }
    }

    // MARK: Écriture d'une activité réalisée

    func writeCompletedWorkout(_ activity: CompletedActivity) async throws {
        let config = HKWorkoutConfiguration()
        config.activityType = Self.hkType(activity.sport)
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: activity.start)
        try await builder.endCollection(at: activity.start.addingTimeInterval(activity.duration))
        _ = try await builder.finishWorkout()
    }

    // MARK: Correspondances de sport

    static func sport(from type: HKWorkoutActivityType) -> Sport {
        switch type {
        case .swimming, .swimBikeRun: return .swim
        case .cycling: return .bike
        case .running: return .run
        case .traditionalStrengthTraining, .functionalStrengthTraining: return .strength
        default: return .run
        }
    }

    static func hkType(_ sport: Sport) -> HKWorkoutActivityType {
        switch sport {
        case .swim: return .swimming
        case .bike: return .cycling
        case .run: return .running
        case .strength: return .traditionalStrengthTraining
        case .brick: return .mixedCardio
        }
    }
}
