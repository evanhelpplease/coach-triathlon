import XCTest
@testable import TriathlonEngine

private func testProfile() -> AthleteProfile {
    AthleteProfile(
        birthDate: Date(timeIntervalSince1970: 631152000), sex: .male,
        heightCm: 180, weightKg: 72, hrMax: 190, hrRest: 48,
        ftpWatts: 250, cssSecPer100m: 95, vdot: 50
    )
}
private func fullEquipment() -> Equipment {
    Equipment(hasBike: true, bikeType: .road, hasAeroBars: true,
              poolAccess: true, runOutdoor: true, strengthAccess: .homeWeights)
}
private func testZones() -> TrainingZones {
    ZoneCalculator().zones(for: testProfile())
}

private func hasLengths(_ steps: [WorkoutStep]) -> Bool {
    steps.contains {
        if case .lengths = $0.duration { return true }
        return false
    }
}

final class SessionGeneratorTests: XCTestCase {
    let gen = SessionGenerator()
    let today = Date(timeIntervalSince1970: 1_700_000_000)

    func testRunThresholdHasStructure() {
        let s = gen.generate(sport: .run, intent: .threshold, phase: .build,
                             date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        XCTAssertEqual(s.steps.first?.kind, .warmup)
        XCTAssertEqual(s.steps.last?.kind, .cooldown)
        XCTAssertTrue(s.steps.contains { $0.kind == .repeatBlock })
        XCTAssertGreaterThan(s.estimatedLoad, 0)
        XCTAssertGreaterThan(s.estimatedDuration, 0)
    }

    func testBuildPhaseHasMoreLoadThanBase() {
        let base = gen.generate(sport: .run, intent: .endurance, phase: .base, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        let build = gen.generate(sport: .run, intent: .endurance, phase: .build, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        XCTAssertGreaterThan(build.estimatedLoad, base.estimatedLoad)
    }

    func testSwimUsesLengths() {
        let s = gen.generate(sport: .swim, intent: .technique, phase: .base, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        XCTAssertTrue(hasLengths(s.steps))
    }

    func testBikeThresholdUsesPowerTarget() {
        let s = gen.generate(sport: .bike, intent: .threshold, phase: .build, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        let repeatBlock = s.steps.first { $0.kind == .repeatBlock }
        let work = repeatBlock?.children?.first { $0.kind == .work }
        if case .powerRange = work?.target { } else { XCTFail("cible puissance attendue") }
    }

    func testVO2LoadHigherThanEndurance() {
        let end = gen.generate(sport: .bike, intent: .endurance, phase: .build, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        let vo2 = gen.generate(sport: .bike, intent: .vo2, phase: .build, date: today, zones: testZones(), profile: testProfile(), equipment: fullEquipment())
        // À durée comparable, la VO2 (IF plus élevé) doit peser plus par unité de temps.
        XCTAssertGreaterThan(vo2.estimatedLoad / vo2.estimatedDuration, end.estimatedLoad / end.estimatedDuration)
    }
}

final class ReadinessEvaluatorTests: XCTestCase {
    let eval = ReadinessEvaluator()

    func baseHistory() -> [DailyReadiness] {
        (0..<7).map { DailyReadiness(date: Date(timeInterval: Double($0) * 86400, since: Date(timeIntervalSince1970: 0)),
                                     sleepHours: 8, hrRest: 48, hrvMs: 80) }
    }

    func testGoodDay() {
        let today = DailyReadiness(date: Date(), sleepHours: 8, hrRest: 47, hrvMs: 82,
                                   subjective: SubjectiveCheckin(form: 5, sleepQuality: 5, soreness: 5, motivation: 5))
        XCTAssertEqual(eval.assess(today: today, history: baseHistory()).level, .good)
    }

    func testLowDay() {
        let today = DailyReadiness(date: Date(), sleepHours: 5, hrRest: 58, hrvMs: 45,
                                   subjective: SubjectiveCheckin(form: 2, sleepQuality: 2, soreness: 1, motivation: 2))
        let a = eval.assess(today: today, history: baseHistory())
        XCTAssertEqual(a.level, .low)
        XCTAssertFalse(a.reasons.isEmpty)
    }
}

final class EquipmentSubstitutionTests: XCTestCase {
    let sub = EquipmentSubstitution()
    let today = Date()

    func bikeSession() -> PlannedSession {
        PlannedSession(date: today, sport: .bike, intent: .threshold, title: "Vélo seuil", estimatedLoad: 80, estimatedDuration: 3600)
    }

    func testBikeWithoutBikeBecomesRun() {
        let eq = Equipment(hasBike: false, runOutdoor: true)
        let r = sub.substitute(bikeSession(), equipment: eq)
        XCTAssertTrue(r.changed)
        XCTAssertEqual(r.session.sport, .run)
    }

    func testSwimWithoutWaterBecomesStrength() {
        let s = PlannedSession(date: today, sport: .swim, intent: .endurance, title: "Nat", estimatedLoad: 50, estimatedDuration: 2400)
        let eq = Equipment(poolAccess: false, openWaterAccess: false, hasDrylandCords: true)
        let r = sub.substitute(s, equipment: eq)
        XCTAssertTrue(r.changed)
        XCTAssertEqual(r.session.sport, .strength)
    }

    func testPractticableSportUnchanged() {
        let eq = Equipment(hasBike: true, bikeType: .road)
        let r = sub.substitute(bikeSession(), equipment: eq)
        XCTAssertFalse(r.changed)
    }
}

final class AdapterTests: XCTestCase {
    let today = Date(timeIntervalSince1970: 1_700_000_000)
    let cal = Calendar(identifier: .gregorian)

    func runSession(daysFromToday d: Int, load: Double = 80, intent: SessionIntent = .threshold) -> PlannedSession {
        PlannedSession(date: cal.date(byAdding: .day, value: d, to: today)!, sport: .run, intent: intent,
                       title: "Course", estimatedLoad: load, estimatedDuration: 3600, phase: .build)
    }

    func testInjuryReplacesRunWithSwim() {
        let ctx = AdaptationContext(
            today: today,
            upcoming: [runSession(daysFromToday: 1)],
            injuries: [InjuryRecord(zone: .knee, intensity: 4, since: today, affectedSports: [.run])],
            equipment: fullEquipment(), profile: testProfile(), zones: testZones()
        )
        let r = Adapter().adapt(ctx)
        XCTAssertEqual(r.plan.first?.sport, .swim)
        XCTAssertTrue(r.events.contains { $0.kind == .injuryAdjusted })
        XCTAssertTrue(r.events.first { $0.kind == .injuryAdjusted }!.message.contains("avis médical"))
    }

    func testLowReadinessEasesHardestToday() {
        let ctx = AdaptationContext(
            today: today,
            upcoming: [runSession(daysFromToday: 0, load: 90, intent: .vo2)],
            readinessToday: DailyReadiness(date: today, sleepHours: 5, hrRest: 60, hrvMs: 40,
                                           subjective: SubjectiveCheckin(form: 1, sleepQuality: 1, soreness: 1, motivation: 2)),
            readinessHistory: (0..<7).map { DailyReadiness(date: Date(timeInterval: Double($0) * 86400, since: Date(timeIntervalSince1970: 0)), sleepHours: 8, hrRest: 48, hrvMs: 80) },
            equipment: fullEquipment(), profile: testProfile(), zones: testZones()
        )
        let r = Adapter().adapt(ctx)
        XCTAssertEqual(r.plan.first?.intent, .recovery)
        XCTAssertTrue(r.events.contains { $0.kind == .eased })
    }

    func testHighACWRTriggersDeload() {
        let lp = LoadPoint(date: today, dailyLoad: 100, ctl: 60, atl: 90, tsb: -30, acwr: 1.7)
        let session = runSession(daysFromToday: 1, load: 100)
        let ctx = AdaptationContext(today: today, upcoming: [session], recentLoad: [lp],
                                    equipment: fullEquipment(), profile: testProfile(), zones: testZones())
        let r = Adapter().adapt(ctx)
        XCTAssertTrue(r.events.contains { $0.kind == .deload })
        XCTAssertLessThan(r.plan.first!.estimatedLoad, session.estimatedLoad)
    }

    func testMissedRescheduledWhenFresh() {
        let missed = runSession(daysFromToday: -1, load: 70)
        let ctx = AdaptationContext(today: today, upcoming: [], missed: [missed],
                                    recentLoad: [LoadPoint(date: today, dailyLoad: 40, ctl: 50, atl: 45, tsb: 5, acwr: 1.0)],
                                    equipment: fullEquipment(), profile: testProfile(), zones: testZones())
        let r = Adapter().adapt(ctx)
        XCTAssertTrue(r.events.contains { $0.kind == .rescheduled })
        XCTAssertEqual(r.plan.count, 1)
    }

    func testMissedNotRescheduledWhenOverloaded() {
        let missed = runSession(daysFromToday: -1)
        let ctx = AdaptationContext(today: today, upcoming: [], missed: [missed],
                                    recentLoad: [LoadPoint(date: today, dailyLoad: 120, ctl: 60, atl: 100, tsb: -20, acwr: 1.4)],
                                    equipment: fullEquipment(), profile: testProfile(), zones: testZones())
        let r = Adapter().adapt(ctx)
        XCTAssertTrue(r.events.contains { $0.kind == .alert })
        XCTAssertTrue(r.plan.isEmpty)
    }

    func testDetectMissed() {
        let planned = [runSession(daysFromToday: -2), runSession(daysFromToday: -1)]
        let done = [CompletedActivity(sport: .run, start: cal.date(byAdding: .day, value: -1, to: today)!, duration: 3600)]
        let missed = Adapter.detectMissed(pastPlanned: planned, completed: done)
        XCTAssertEqual(missed.count, 1)
    }
}
