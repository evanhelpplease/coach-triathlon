import XCTest
@testable import TriathlonEngine

final class PlanBuilderTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)
    let start = Date(timeIntervalSince1970: 1_700_000_000)

    func profile() -> AthleteProfile {
        AthleteProfile(birthDate: Date(timeIntervalSince1970: 631152000), sex: .male,
                       heightCm: 180, weightKg: 72, hrMax: 190, hrRest: 48,
                       ftpWatts: 250, cssSecPer100m: 95, vdot: 50,
                       levels: [.swim: .novice, .bike: .advanced, .run: .intermediate])
    }
    func fullEquip() -> Equipment {
        Equipment(hasBike: true, bikeType: .road, hasAeroBars: true, poolAccess: true,
                  runOutdoor: true, strengthAccess: .homeWeights)
    }
    func race(weeks: Int, format: RaceFormat = .olympic) -> Race {
        Race(date: cal.date(byAdding: .day, value: weeks * 7, to: start)!, format: format, priority: .a, title: "Course A")
    }
    func availability(days: Set<Int> = [2,3,4,5,6,7,1], max: Int = 6) -> WeeklyAvailability {
        WeeklyAvailability(availableWeekdays: days, maxSessionsPerWeek: max)
    }

    func sessions(inWeek week: PlannedWeek, of plan: TrainingPlan) -> [PlannedSession] {
        let end = cal.date(byAdding: .day, value: 7, to: week.startDate)!
        return plan.sessions.filter { $0.date >= week.startDate && $0.date < end }
    }

    func testBuildsNonEmptyPlan() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 12),
                                       start: start, availability: availability())
        XCTAssertFalse(plan.sessions.isEmpty)
        XCTAssertFalse(plan.zones.hr.isEmpty)
        for w in plan.weeks {
            XCTAssertFalse(sessions(inWeek: w, of: plan).isEmpty, "chaque semaine doit avoir des séances")
        }
    }

    func testRespectsMaxSessionsPerWeek() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 8),
                                       start: start, availability: availability(max: 4))
        for w in plan.weeks {
            XCTAssertLessThanOrEqual(sessions(inWeek: w, of: plan).count, 4)
        }
    }

    func testBuildWeekCoversThreeDisciplines() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 12),
                                       start: start, availability: availability())
        let buildWeek = plan.weeks.first { $0.phase == .build }!
        let sports = Set(sessions(inWeek: buildWeek, of: plan).map(\.sport))
        XCTAssertTrue(sports.isSuperset(of: [.swim, .bike, .run]))
    }

    func testWeeklyLoadApproximatesTarget() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 12),
                                       start: start, availability: availability())
        let buildWeek = plan.weeks.first { $0.phase == .build && !$0.isDeload }!
        let load = plan.load(forWeekIndex: buildWeek.index)
        // La mise à l'échelle doit rapprocher la charge de la cible (±30 %).
        XCTAssertEqual(load, buildWeek.targetLoad, accuracy: buildWeek.targetLoad * 0.3)
    }

    func testTaperLighterThanPeak() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 16, format: .half),
                                       start: start, availability: availability())
        let peak = plan.weeks.filter { $0.phase != .taper }.map { plan.load(forWeekIndex: $0.index) }.max()!
        for w in plan.weeks where w.phase == .taper {
            XCTAssertLessThan(plan.load(forWeekIndex: w.index), peak)
        }
    }

    func testPolarization80_20() {
        // Mesuré par le VOLUME : seul l'entraînement vraiment intense compte comme « dur ».
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 12),
                                       start: start, availability: availability())
        let hard: Set<SessionIntent> = [.threshold, .vo2, .sprint]
        let hardVol = plan.sessions.filter { hard.contains($0.intent) }.reduce(0.0) { $0 + $1.estimatedDuration }
        let totalVol = plan.sessions.reduce(0.0) { $0 + $1.estimatedDuration }
        XCTAssertGreaterThanOrEqual(1 - hardVol / totalVol, 0.72)
    }

    func testBuildWeekHasBikeIntervals() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 12),
                                       start: start, availability: availability())
        let buildWeek = plan.weeks.first { $0.phase == .build }!
        let bike = sessions(inWeek: buildWeek, of: plan).filter { $0.sport == .bike }
        XCTAssertTrue(bike.contains { [.threshold, .vo2].contains($0.intent) })
    }

    func testFacilityDaysRespected() {
        let avail = WeeklyAvailability(maxSessionsPerWeek: 6, sportDays: [.swim: [2, 4]]) // lun/mer
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 8),
                                       start: start, availability: avail)
        let swimWeekdays = Set(plan.sessions.filter { $0.sport == .swim }.map { cal.component(.weekday, from: $0.date) })
        XCTAssertTrue(swimWeekdays.isSubset(of: [2, 4]))
    }

    func testMultiRaceRemovesTrainingOnRaceDays() {
        let raceB = Race(date: cal.date(byAdding: .day, value: 5 * 7, to: start)!, format: .sprint, priority: .b, title: "Sprint")
        let raceA = race(weeks: 12)
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), races: [raceB, raceA],
                                       start: start, availability: availability())
        XCTAssertFalse(plan.sessions.contains { cal.isDate($0.date, inSameDayAs: raceB.date) })
    }

    func testStartsWithoutBikeThenSubstituted() {
        // "Je démarre demain mais je n'ai ni vélo ni piscine."
        let noGear = Equipment(hasBike: false, poolAccess: false, openWaterAccess: false,
                               hasDrylandCords: true, runOutdoor: true, strengthAccess: .bodyweightOnly)
        let plan = PlanBuilder().build(profile: profile(), equipment: noGear, race: race(weeks: 8),
                                       start: start, availability: availability())
        XCTAssertFalse(plan.sessions.contains { $0.sport == .bike }, "aucune séance vélo sans vélo")
        XCTAssertFalse(plan.sessions.contains { $0.sport == .swim }, "aucune séance en bassin sans eau")
        XCTAssertFalse(plan.sessions.isEmpty, "le plan démarre quand même")
    }

    func testMonoSportPlanFocusesOnRun() {
        let plan = PlanBuilder().build(profile: profile(), equipment: fullEquip(), race: race(weeks: 10, format: .marathon),
                                       start: start, availability: availability())
        let runShare = Double(plan.sessions.filter { $0.sport == .run }.count) / Double(plan.sessions.count)
        XCTAssertGreaterThan(runShare, 0.5)
    }
}
