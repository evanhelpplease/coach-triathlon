import XCTest
@testable import TriathlonEngine

final class VDOTTests: XCTestCase {

    func testVDOTFrom5kReferenceValue() {
        // 5 km en 20:00 → VDOT ≈ 49.8 (table de Daniels : VDOT 50 ≈ 19:57).
        let v = VDOT.vdot(distanceMeters: 5000, timeSeconds: 20 * 60)
        XCTAssertEqual(v, 49.8, accuracy: 0.7)
    }

    func testPredictTimeRoundTrip() {
        let v = VDOT.vdot(distanceMeters: 5000, timeSeconds: 1200)
        let t = VDOT.predictTimeSeconds(vdot: v, distanceMeters: 5000)
        XCTAssertEqual(t, 1200, accuracy: 3)
    }

    func testLongerDistanceIsSlower() {
        let v = 50.0
        let t5 = VDOT.predictTimeSeconds(vdot: v, distanceMeters: 5000)
        let t10 = VDOT.predictTimeSeconds(vdot: v, distanceMeters: 10000)
        XCTAssertGreaterThan(t10, 2 * t5) // >2× car l'allure baisse avec la distance
    }

    func testTrainingPacesAreMonotonic() {
        let p = VDOT.trainingPaces(vdot: 50)
        // Allures en s/km : plus la zone est dure, plus la valeur est petite (plus rapide).
        XCTAssertGreaterThan(p.easySecPerKm, p.marathonSecPerKm)
        XCTAssertGreaterThan(p.marathonSecPerKm, p.thresholdSecPerKm)
        XCTAssertGreaterThan(p.thresholdSecPerKm, p.intervalSecPerKm)
        XCTAssertGreaterThan(p.intervalSecPerKm, p.repetitionSecPerKm)
    }

    func testHigherVDOTIsFaster() {
        let slow = VDOT.predictTimeSeconds(vdot: 40, distanceMeters: 10000)
        let fast = VDOT.predictTimeSeconds(vdot: 60, distanceMeters: 10000)
        XCTAssertLessThan(fast, slow)
    }
}

final class RiegelTests: XCTestCase {

    func testPredict10kFrom5k() {
        // 5 km en 20:00 → 10 km ≈ 20:00 · 2^1.06 ≈ 41:42.
        let t = Riegel.predictTimeSeconds(
            knownDistanceMeters: 5000, knownTimeSeconds: 1200,
            targetDistanceMeters: 10000
        )
        XCTAssertEqual(t, 2502, accuracy: 5)
    }

    func testFittedExponentRecoversInput() {
        let t2 = 1200 * pow(2.0, 1.06)
        let b = Riegel.fittedExponent(d1: 5000, t1: 1200, d2: 10000, t2: t2)
        XCTAssertEqual(b, 1.06, accuracy: 1e-6)
    }
}

final class CSSTests: XCTestCase {

    func testCSSPaceReference() {
        // 400 m en 6:00, 200 m en 2:50 → CSS ≈ 1:35/100 m (95 s).
        let pace = CSS.pacePer100m(
            longDistanceM: 400, longTimeSec: 360,
            shortDistanceM: 200, shortTimeSec: 170
        )
        XCTAssertEqual(pace, 95, accuracy: 0.5)
    }

    func testPredictAtReferenceDistance() {
        let t = CSS.predictTimeSeconds(cssPacePer100m: 95, distanceM: 400)
        XCTAssertEqual(t, 380, accuracy: 1)
    }
}

final class CyclingPowerTests: XCTestCase {

    func makeModel(cda: Double = 0.32, mass: Double = 83) -> CyclingPowerModel {
        CyclingPowerModel(totalMassKg: mass, cda: cda)
    }

    func testHigherPowerIsFaster() {
        let m = makeModel()
        XCTAssertLessThan(m.speed(forPower: 200), m.speed(forPower: 300))
    }

    func testLowerCdAIsFaster() {
        let road = makeModel(cda: 0.32)
        let tt = makeModel(cda: 0.24)
        XCTAssertLessThan(road.speed(forPower: 250), tt.speed(forPower: 250))
    }

    func test40kTimeIsPlausible() {
        // 250 W FTP, vélo route → 40 km entre 58 et 75 min.
        let m = makeModel()
        let t = m.predictTimeSeconds(distanceM: 40000, sustainedPowerW: 250)
        XCTAssertGreaterThan(t, 58 * 60)
        XCTAssertLessThan(t, 75 * 60)
    }

    func testPowerSpeedRoundTrip() {
        let m = makeModel()
        let v = m.speed(forPower: 250)
        XCTAssertEqual(m.power(forSpeed: v), 250, accuracy: 0.5)
    }

    func testTypicalCdAOrdering() {
        let tt = CyclingPowerModel.typicalCdA(bikeType: .tt, aeroBars: true)
        let road = CyclingPowerModel.typicalCdA(bikeType: .road, aeroBars: false)
        let mtb = CyclingPowerModel.typicalCdA(bikeType: .mtb, aeroBars: false)
        XCTAssertLessThan(tt, road)
        XCTAssertLessThan(road, mtb)
    }
}

final class RacePredictorTests: XCTestCase {

    func fullProfile() -> AthleteProfile {
        AthleteProfile(
            birthDate: Date(timeIntervalSince1970: 631152000), // 1990
            sex: .male, heightCm: 180, weightKg: 72,
            hrMax: 190, hrRest: 48, ftpWatts: 260,
            cssSecPer100m: 95, vdot: 52
        )
    }

    func testOlympicPredictionIsPlausible() {
        let eq = Equipment(hasBike: true, bikeType: .road, bikeWeightKg: 8, hasAeroBars: true)
        let p = RacePredictor().predict(format: .olympic, profile: fullProfile(), equipment: eq)
        // Un olympique bien préparé : ~2h à 2h45.
        XCTAssertNotNil(p.swimSeconds)
        XCTAssertNotNil(p.bikeSeconds)
        XCTAssertGreaterThan(p.totalSeconds, 2 * 3600)
        XCTAssertLessThan(p.totalSeconds, 2.75 * 3600)
        // Somme cohérente.
        let sum = (p.swimSeconds ?? 0) + (p.t1Seconds ?? 0) + (p.bikeSeconds ?? 0) + (p.t2Seconds ?? 0) + p.runSeconds
        XCTAssertEqual(sum, p.totalSeconds, accuracy: 0.5)
    }

    func testConfidenceWidensWithMissingData() {
        let eq = Equipment(hasBike: true, bikeType: .road)
        let full = RacePredictor().predict(format: .olympic, profile: fullProfile(), equipment: eq)
        let sparse = AthleteProfile(
            birthDate: Date(timeIntervalSince1970: 631152000),
            sex: .male, heightCm: 180, weightKg: 72
        )
        let poor = RacePredictor().predict(format: .olympic, profile: sparse, equipment: eq)
        XCTAssertGreaterThan(poor.confidenceHalfWidth, full.confidenceHalfWidth)
    }

    func testRunOnlyFormatHasNoSwimBike() {
        let eq = Equipment()
        let p = RacePredictor().predict(format: .marathon, profile: fullProfile(), equipment: eq)
        XCTAssertNil(p.swimSeconds)
        XCTAssertNil(p.bikeSeconds)
        XCTAssertEqual(p.runSeconds, p.totalSeconds, accuracy: 0.5)
    }

    func testWetsuitSpeedsUpSwim() {
        let noSuit = Equipment(hasBike: true, bikeType: .road, hasWetsuit: false)
        let suit = Equipment(hasBike: true, bikeType: .road, hasWetsuit: true)
        let a = RacePredictor().predict(format: .olympic, profile: fullProfile(), equipment: noSuit)
        let b = RacePredictor().predict(format: .olympic, profile: fullProfile(), equipment: suit)
        XCTAssertLessThan(b.swimSeconds ?? 0, a.swimSeconds ?? 0)
    }
}
