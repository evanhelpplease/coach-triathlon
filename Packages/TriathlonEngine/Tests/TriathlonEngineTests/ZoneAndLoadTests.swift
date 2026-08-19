import XCTest
@testable import TriathlonEngine

final class ZoneCalculatorTests: XCTestCase {

    func testKarvonenHRZones() {
        let calc = ZoneCalculator()
        let zones = calc.hrZones(hrMax: 190, hrRest: 50) // réserve = 140
        // Z2 : 68 %..83 % de la réserve → 50 + 0.68·140 = 145.2
        let z2 = zones.first { $0.zone == 2 }!
        XCTAssertEqual(z2.lower, 145.2, accuracy: 0.1)
        XCTAssertEqual(z2.upper, 50 + 0.83 * 140, accuracy: 0.1)
        // La dernière zone est ouverte.
        XCTAssertEqual(zones.last!.upper, .infinity)
    }

    func testCogganPowerZones() {
        let z = ZoneCalculator().powerZones(ftp: 250)
        let z4 = z.first { $0.zone == 4 }!
        XCTAssertEqual(z4.lower, 225, accuracy: 0.01)   // 90 % FTP
        XCTAssertEqual(z4.upper, 262.5, accuracy: 0.01) // 105 % FTP
        XCTAssertEqual(z.count, 7)
    }

    func testEstimatedSourceWhenHRUnknown() {
        let p = AthleteProfile(
            birthDate: Date(timeIntervalSince1970: 631152000),
            sex: .male, heightCm: 180, weightKg: 72,
            ftpWatts: 250, vdot: 50
        )
        let z = ZoneCalculator().zones(for: p)
        XCTAssertEqual(z.source, .estimated)
        XCTAssertFalse(z.hr.isEmpty)      // estimée quand même
        XCTAssertFalse(z.power.isEmpty)
        XCTAssertFalse(z.runPace.isEmpty)
    }

    func testRunPaceZonesOrdering() {
        let z = ZoneCalculator().runPaceZones(vdot: 50)
        // Zone 5 (répétition) plus rapide (valeur plus basse) que zone 1 (facile).
        let z1 = z.first { $0.zone == 1 }!.lower
        let z5 = z.first { $0.zone == 5 }!.lower
        XCTAssertLessThan(z5, z1)
    }
}

final class LoadModelTests: XCTestCase {

    func testCyclingTSSOneHourAtFTPIs100() {
        let tss = LoadCalculator().cyclingTSS(durationSec: 3600, normalizedPowerW: 250, ftpW: 250)
        XCTAssertEqual(tss, 100, accuracy: 0.01)
    }

    func testPaceTSSOneHourAtThresholdIs100() {
        let tss = LoadCalculator().paceTSS(durationSec: 3600, avgSpeed: 4.0, thresholdSpeed: 4.0)
        XCTAssertEqual(tss, 100, accuracy: 0.01)
    }

    func testHalfIntensityGivesLowerTSS() {
        let hard = LoadCalculator().paceTSS(durationSec: 3600, avgSpeed: 4.0, thresholdSpeed: 4.0)
        let easy = LoadCalculator().paceTSS(durationSec: 3600, avgSpeed: 3.0, thresholdSpeed: 4.0)
        XCTAssertLessThan(easy, hard)
    }

    func testConstantLoadConvergesCTLtoLoad() {
        // 200 jours à charge constante 50 → CTL et ATL convergent vers 50, TSB → 0, ACWR → 1.
        let start = Date(timeIntervalSince1970: 0)
        let days: [(date: Date, load: Double)] = (0..<200).map {
            (Date(timeInterval: Double($0) * 86400, since: start), 50.0)
        }
        let series = LoadSeries().series(dailyLoads: days)
        let last = series.last!
        XCTAssertEqual(last.ctl, 50, accuracy: 1.0)
        XCTAssertEqual(last.atl, 50, accuracy: 0.5)
        XCTAssertEqual(last.tsb, 0, accuracy: 1.0)
        XCTAssertEqual(last.acwr, 1.0, accuracy: 0.01)
    }

    func testLoadDispatchUsesPowerForBike() {
        let profile = AthleteProfile(
            birthDate: Date(timeIntervalSince1970: 631152000),
            sex: .male, heightCm: 180, weightKg: 72, ftpWatts: 250
        )
        let a = CompletedActivity(sport: .bike, start: Date(), duration: 3600, normalizedPowerW: 250)
        let load = LoadCalculator().load(for: a, profile: profile)
        XCTAssertEqual(load, 100, accuracy: 0.5)
    }
}
