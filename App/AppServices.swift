import Foundation
import SwiftData
import Observation
import TriathlonEngine

/// Source de données santé sélectionnée.
enum SourceMode: String, CaseIterable {
    case demo, appleHealth, garminDemo
}

/// Conteneur de services injecté dans l'environnement SwiftUI.
@Observable
final class AppServices {
    /// Source active (démo par défaut, aucune permission requise).
    var sourceMode: SourceMode = .demo
    /// Module Garmin réel connecté via OAuth (nécessite des identifiants développeur).
    var garminConnected: Bool = false

    let planBuilder = PlanBuilder()

    /// Rétro-compat : `useMockData` reflète la source démo.
    var useMockData: Bool {
        get { sourceMode == .demo }
        set { sourceMode = newValue ? .demo : .appleHealth }
    }

    /// Sources actives, cumulables (Apple Santé + Garmin fusionnés par le coordinateur).
    var providers: [HealthDataProvider] {
        switch sourceMode {
        case .demo:       return [MockHealthProvider()]
        case .garminDemo: return [GarminMockProvider()]
        case .appleHealth:
            var list: [HealthDataProvider] = []
            if AppleHealthProvider.isAvailable { list.append(AppleHealthProvider()) }
            if garminConnected { list.append(GarminProvider()) }
            return list.isEmpty ? [MockHealthProvider()] : list
        }
    }

    /// (Re)génère le plan périodisé et remplace les séances persistées.
    /// Les disponibilités sont lues sur le profil ; des séances de TEST sont insérées
    /// tôt pour chaque discipline sans référentiel mesuré.
    @MainActor
    func regeneratePlan(profile: ProfileModel, equipment: EquipmentModel, context: ModelContext) {
        // Purge les séances existantes.
        if let existing = try? context.fetch(FetchDescriptor<PlannedSessionModel>()) {
            existing.forEach(context.delete)
        }
        let cal = Calendar(identifier: .gregorian)

        // Toutes les courses réelles (sinon l'objectif ouvert « progression continue »).
        let allRaces = (try? context.fetch(FetchDescriptor<RaceModel>())) ?? []
        let realRaces = allRaces.filter { !$0.isOpenGoal }
        let races = (realRaces.isEmpty ? allRaces : realRaces).map { $0.domain }
        guard !races.isEmpty else { return }

        let config = PlanBuilder.Config(
            progression: profile.progression,
            startingWeeklyLoad: max(150, profile.weeklyHours * 40)
        )
        let plan = planBuilder.build(
            profile: profile.domain, equipment: equipment.domain, races: races,
            start: cal.startOfDay(for: .now),
            availability: profile.availability, config: config
        )
        var sessions = plan.sessions
        insertTestSessions(&sessions, missing: profile.missingReferentials,
                           poolMeters: 25, calendar: cal)
        for session in sessions {
            context.insert(PlannedSessionModel(session))
        }
        try? context.save()
    }

    /// Remplace la première séance de chaque discipline « à tester » (dans les 12
    /// premiers jours) par une séance de test de terrain.
    private func insertTestSessions(_ sessions: inout [PlannedSession], missing: Set<Sport>,
                                    poolMeters: Double, calendar cal: Calendar) {
        guard !missing.isEmpty else { return }
        let horizon = cal.date(byAdding: .day, value: 12, to: cal.startOfDay(for: .now)) ?? .now
        for sport in [Sport.run, .bike, .swim] where missing.contains(sport) {
            if let idx = sessions.firstIndex(where: { $0.sport == sport && $0.date <= horizon }) {
                let test = TestSessions.make(for: sport, date: sessions[idx].date, poolMeters: poolMeters)
                var replaced = test
                replaced.id = sessions[idx].id
                sessions[idx] = replaced
            }
        }
        sessions.sort { $0.date < $1.date }
    }

    /// Instantané des données santé (activités + récupération), chargé UNE fois de
    /// façon asynchrone puis réutilisé par les calculs purs et réactifs.
    func fetchHealth() async -> HealthSnapshot {
        let cal = Calendar(identifier: .gregorian)
        let coordinator = ProviderCoordinator(providers: providers)
        let since = cal.date(byAdding: .day, value: -120, to: .now) ?? .now
        let activities = await coordinator.importActivities(since: since)
        let readiness = await coordinator.importReadiness(since: cal.date(byAdding: .day, value: -30, to: .now) ?? .now)
        return HealthSnapshot(activities: activities, readiness: readiness)
    }

    /// Métrique de forme du jour (dernier point de la série de charge).
    func formPoint(snapshot: HealthSnapshot, profile: AthleteProfile) -> LoadPoint? {
        Self.dailySeries(from: snapshot.activities, profile: profile).last
    }

    /// Passe d'adaptation du jour — fonction PURE de (plan de base, état du jour),
    /// jamais persistée : recalculée à chaque changement de donnée (réactive) et
    /// idempotente (aucun effet cumulatif : double allègement, décharge en boucle…).
    func adapt(
        base: [PlannedSession],
        profile: AthleteProfile,
        equipment: Equipment,
        injuries: [InjuryRecord],
        localCheckins: [DailyReadiness],
        snapshot: HealthSnapshot
    ) -> AdaptationOutcome {
        let cal = Calendar(identifier: .gregorian)
        let today0 = cal.startOfDay(for: .now)
        let activities = snapshot.activities
        let healthReadiness = snapshot.readiness

        // État du jour : le check-in subjectif prime, complété par les données santé.
        let localToday = localCheckins.first { cal.isDate($0.date, inSameDayAs: today0) }
        let healthToday = healthReadiness.first { cal.isDate($0.date, inSameDayAs: today0) }
        let readinessToday = Self.mergeReadiness(local: localToday, health: healthToday, day: today0)

        let history = (healthReadiness + localCheckins).sorted { $0.date < $1.date }

        let upcoming = base.filter { $0.date >= today0 }
        let past = base.filter { $0.date < today0 }
        let missed = Adapter.detectMissed(pastPlanned: past, completed: activities)
        let recentLoad = Self.dailySeries(from: activities, profile: profile)
        let zones = ZoneCalculator().zones(for: profile, on: .now)

        let ctx = AdaptationContext(
            today: today0, upcoming: upcoming, missed: missed, recentLoad: recentLoad,
            readinessToday: readinessToday, readinessHistory: history,
            injuries: injuries, equipment: equipment, profile: profile, zones: zones
        )
        let result = Adapter().adapt(ctx)
        let todaySession = result.plan.first { cal.isDate($0.date, inSameDayAs: today0) }
        return AdaptationOutcome(todaySession: todaySession, events: result.events, adaptedPlan: result.plan)
    }

    /// Applique les indisponibilités à un plan (fonction pure, pour l'affichage du Plan) :
    /// chaque séance est convertie si son sport est indisponible à sa date.
    func adjustedForAvailability(_ sessions: [PlannedSession], profile: AthleteProfile,
                                 baseEquipment: Equipment, unavailabilities: [Unavailability]) -> [PlannedSession] {
        sessions.map { s in
            let eq = Availability.effectiveEquipment(base: baseEquipment, unavailabilities: unavailabilities, on: s.date)
            return Self.materialize(s, profile: profile, equipment: eq)
        }
    }

    /// Substitue + re-matérialise une séance si son sport n'est pas praticable avec `equipment`.
    static func materialize(_ session: PlannedSession, profile: AthleteProfile, equipment: Equipment) -> PlannedSession {
        let sub = EquipmentSubstitution().substitute(session, equipment: equipment)
        guard sub.changed else { return session }
        let zones = ZoneCalculator().zones(for: profile)
        var repl = SessionGenerator().generate(sport: sub.session.sport, intent: session.intent,
                                               phase: session.phase ?? .base, date: session.date,
                                               zones: zones, profile: profile, equipment: equipment)
        repl.id = session.id
        repl.title = sub.session.title
        repl.notes = sub.explanation
        return repl
    }

    private static func mergeReadiness(local: DailyReadiness?, health: DailyReadiness?, day: Date) -> DailyReadiness? {
        guard local != nil || health != nil else { return nil }
        var r = health ?? DailyReadiness(date: day)
        if let l = local {
            r.subjective = l.subjective ?? r.subjective
            r.sleepHours = l.sleepHours ?? r.sleepHours
            r.hrRest = r.hrRest ?? l.hrRest
            r.hrvMs = r.hrvMs ?? l.hrvMs
        }
        r.date = day
        return r
    }

    /// Dernières séances réalisées avec leur analyse en langage naturel.
    func recentAnalyses(profile: AthleteProfile) async -> [(activity: CompletedActivity, analysis: SessionAnalysis)] {
        let snap = await fetchHealth()
        let analyzer = PostSessionAnalyzer()
        return snap.activities.sorted { $0.start > $1.start }.prefix(15).map {
            ($0, analyzer.analyze(activity: $0, profile: profile, history: snap.activities))
        }
    }

    /// Records personnels calculés sur l'ensemble des activités.
    func records(profile: AthleteProfile) async -> [PersonalRecord] {
        let snap = await fetchHealth()
        return PersonalRecords().compute(from: snap.activities)
    }

    /// Analyse complète : série CTL/ATL/TSB + charge hebdo par sport.
    func loadAnalytics(profile: AthleteProfile) async -> TrainingAnalytics? {
        let since = Calendar(identifier: .gregorian).date(byAdding: .day, value: -120, to: .now) ?? .now
        let activities = await ProviderCoordinator(providers: providers).importActivities(since: since)
        guard !activities.isEmpty else { return nil }
        let points = Self.dailySeries(from: activities, profile: profile)
        let bars = Self.weeklyBars(from: activities, profile: profile)
        return TrainingAnalytics(points: points, bars: bars, latest: points.last)
    }

    /// Série de charge quotidienne continue (un point/jour, 0 les jours de repos).
    static func dailySeries(from activities: [CompletedActivity], profile: AthleteProfile) -> [LoadPoint] {
        let calc = LoadCalculator()
        let cal = Calendar(identifier: .gregorian)
        var byDay: [Date: Double] = [:]
        for a in activities {
            byDay[cal.startOfDay(for: a.start), default: 0] += calc.load(for: a, profile: profile)
        }
        guard let first = byDay.keys.min() else { return [] }
        let today = cal.startOfDay(for: .now)
        var days: [(date: Date, load: Double)] = []
        var d = first
        while d <= today {
            days.append((d, byDay[d] ?? 0))
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return LoadSeries().series(dailyLoads: days)
    }

    /// Charge hebdomadaire ventilée par sport (barres empilées).
    static func weeklyBars(from activities: [CompletedActivity], profile: AthleteProfile) -> [SportLoadBar] {
        let calc = LoadCalculator()
        let cal = Calendar(identifier: .gregorian)
        var map: [Date: [Sport: Double]] = [:]
        for a in activities {
            guard let week = cal.dateInterval(of: .weekOfYear, for: a.start)?.start else { continue }
            map[week, default: [:]][a.sport, default: 0] += calc.load(for: a, profile: profile)
        }
        return map.flatMap { week, bySport in
            bySport.map { SportLoadBar(weekStart: week, sportKey: $0.key.rawValue, load: $0.value.rounded()) }
        }.sorted { $0.weekStart < $1.weekStart }
    }
}

// MARK: - Types d'analyse

/// Données santé importées à un instant T (base des calculs purs et réactifs).
struct HealthSnapshot: Sendable {
    var activities: [CompletedActivity]
    var readiness: [DailyReadiness]
}

struct TrainingAnalytics {
    var points: [LoadPoint]
    var bars: [SportLoadBar]
    var latest: LoadPoint?
}

struct AdaptationOutcome {
    var todaySession: PlannedSession?
    var events: [AdaptationEvent]
    var adaptedPlan: [PlannedSession]

    /// Événements pertinents à afficher aujourd'hui (ajustements du jour + rattrapages).
    var todayEvents: [AdaptationEvent] {
        let cal = Calendar(identifier: .gregorian)
        return events.filter { cal.isDateInToday($0.date) || $0.kind == .rescheduled }
    }
}

struct SportLoadBar: Identifiable {
    let id = UUID()
    var weekStart: Date
    var sportKey: String
    var load: Double

    var sportLabel: String {
        switch sportKey {
        case "swim": return "Natation"
        case "bike": return "Vélo"
        case "run": return "Course"
        case "strength": return "Renfo"
        case "brick": return "Brick"
        default: return sportKey
        }
    }
}
