import XCTest
@testable import TriathlonEngine

final class PeriodizerTests: XCTestCase {

    var calendar: Calendar { Calendar(identifier: .gregorian) }

    func makeRace(weeksFromStart: Int, format: RaceFormat, start: Date) -> Race {
        let date = calendar.date(byAdding: .day, value: weeksFromStart * 7, to: start)!
        return Race(date: date, format: format, priority: .a, title: "Course A")
    }

    func phaseRank(_ p: TrainingPhase) -> Int {
        switch p {
        case .base: return 0
        case .build: return 1
        case .specific: return 2
        case .taper: return 3
        case .recovery: return 4
        }
    }

    func testPhasesAreOrdered() {
        let start = Date(timeIntervalSince1970: 0)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 12, format: .olympic, start: start))
        for i in 1..<weeks.count {
            XCTAssertGreaterThanOrEqual(phaseRank(weeks[i].phase), phaseRank(weeks[i - 1].phase),
                                        "Les phases doivent être non décroissantes")
        }
    }

    func testHasDeloadWeek() {
        let start = Date(timeIntervalSince1970: 0)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 12, format: .olympic, start: start))
        XCTAssertTrue(weeks.contains { $0.isDeload })
    }

    func testEndsWithTaper() {
        let start = Date(timeIntervalSince1970: 0)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 12, format: .half, start: start))
        XCTAssertEqual(weeks.last!.phase, .taper)
    }

    func testTaperLoadLowerThanPeak() {
        let start = Date(timeIntervalSince1970: 0)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 16, format: .full, start: start))
        let peak = weeks.filter { $0.phase != .taper }.map(\.targetLoad).max()!
        let taperLoads = weeks.filter { $0.phase == .taper }.map(\.targetLoad)
        for l in taperLoads { XCTAssertLessThan(l, peak) }
    }

    func testRampIsBounded() {
        let start = Date(timeIntervalSince1970: 0)
        let cfg = Periodizer.Config(startingWeeklyLoad: 300, weeklyRampRate: 0.08)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 12, format: .olympic, start: start), config: cfg)
        // Entre deux semaines pleines consécutives (hors décharge/affûtage), la hausse ≤ ~9 %.
        let full = weeks.filter { !$0.isDeload && $0.phase != .taper }
        for i in 1..<full.count {
            if full[i].targetLoad > full[i - 1].targetLoad {
                let ratio = full[i].targetLoad / full[i - 1].targetLoad
                XCTAssertLessThanOrEqual(ratio, 1.09)
            }
        }
    }

    func testDeloadReducesLoad() {
        let start = Date(timeIntervalSince1970: 0)
        let weeks = Periodizer().plan(start: start, race: makeRace(weeksFromStart: 12, format: .olympic, start: start))
        // Une semaine de décharge doit être plus légère que la semaine pleine précédente.
        for i in 1..<weeks.count where weeks[i].isDeload {
            XCTAssertLessThan(weeks[i].targetLoad, weeks[i - 1].targetLoad)
        }
    }
}
