import Foundation
import TriathlonEngine

// Harnais de vérification léger, sans XCTest, pour valider le moteur
// immédiatement (`swift run EngineChecks`) avant l'installation d'Xcode.
// Les mêmes assertions existent en version XCTest dans Tests/ pour la CI.

var passed = 0
var failed = 0

@MainActor func check(_ name: String, _ condition: Bool) {
    if condition { passed += 1; print("  ✅ \(name)") }
    else { failed += 1; print("  ❌ \(name)") }
}

@MainActor func approx(_ name: String, _ value: Double, _ target: Double, _ tol: Double) {
    let ok = abs(value - target) <= tol
    if ok { passed += 1; print("  ✅ \(name)  (\(fmt(value)) ≈ \(fmt(target)))") }
    else { failed += 1; print("  ❌ \(name)  (\(fmt(value)) vs \(fmt(target)) ±\(tol))") }
}

func fmt(_ d: Double) -> String { String(format: "%.2f", d) }
func mmss(_ s: Double) -> String { String(format: "%d:%02d", Int(s) / 60, Int(s) % 60) }

print("\n🏊🚴🏃 Vérification du moteur TriathlonEngine\n")

// MARK: VDOT
print("VDOT (Daniels)")
approx("5 km 20:00 → VDOT ≈ 49.8", VDOT.vdot(distanceMeters: 5000, timeSeconds: 1200), 49.8, 0.7)
let vdotRT = VDOT.predictTimeSeconds(vdot: VDOT.vdot(distanceMeters: 5000, timeSeconds: 1200), distanceMeters: 5000)
approx("aller-retour temps↔VDOT", vdotRT, 1200, 3)
let paces = VDOT.trainingPaces(vdot: 50)
check("allures monotones (facile > seuil > intervalle)",
      paces.easySecPerKm > paces.thresholdSecPerKm && paces.thresholdSecPerKm > paces.intervalSecPerKm)

// MARK: Riegel
print("\nRiegel")
approx("5 km 20:00 → 10 km ≈ 41:42", Riegel.predictTimeSeconds(knownDistanceMeters: 5000, knownTimeSeconds: 1200, targetDistanceMeters: 10000), 2502, 5)

// MARK: CSS
print("\nCSS (natation)")
approx("400/6:00 & 200/2:50 → CSS ≈ 1:35/100m",
       CSS.pacePer100m(longDistanceM: 400, longTimeSec: 360, shortDistanceM: 200, shortTimeSec: 170), 95, 0.5)

// MARK: Puissance vélo
print("\nModèle puissance vélo")
let cpm = CyclingPowerModel(totalMassKg: 83, cda: 0.32)
let t40 = cpm.predictTimeSeconds(distanceM: 40000, sustainedPowerW: 250)
check("40 km @ 250 W plausible (58–75 min)  [\(mmss(t40))]", t40 > 58*60 && t40 < 75*60)
check("puissance ↑ ⇒ vitesse ↑", cpm.speed(forPower: 200) < cpm.speed(forPower: 300))
check("CdA CLM+aéro < route", CyclingPowerModel.typicalCdA(bikeType: .tt, aeroBars: true) < CyclingPowerModel.typicalCdA(bikeType: .road, aeroBars: false))

// MARK: Zones
print("\nZones")
let zc = ZoneCalculator()
let hr = zc.hrZones(hrMax: 190, hrRest: 50)
approx("Karvonen Z2 borne basse = 145.2", hr.first { $0.zone == 2 }!.lower, 145.2, 0.1)
let pw = zc.powerZones(ftp: 250)
approx("Coggan Z4 borne basse = 225 W", pw.first { $0.zone == 4 }!.lower, 225, 0.01)

// MARK: Charge
print("\nModèle de charge")
approx("1 h @ FTP → TSS = 100", LoadCalculator().cyclingTSS(durationSec: 3600, normalizedPowerW: 250, ftpW: 250), 100, 0.01)
let start = Date(timeIntervalSince1970: 0)
let days = (0..<200).map { (date: Date(timeInterval: Double($0) * 86400, since: start), load: 50.0) }
let series = LoadSeries().series(dailyLoads: days)
approx("charge constante 50 → CTL → 50", series.last!.ctl, 50, 1.0)
approx("… → ACWR → 1.0", series.last!.acwr, 1.0, 0.01)

// MARK: Prédiction de course assemblée
print("\nPrédiction triathlon")
let profile = AthleteProfile(
    birthDate: Date(timeIntervalSince1970: 631152000), sex: .male,
    heightCm: 180, weightKg: 72, hrMax: 190, hrRest: 48,
    ftpWatts: 260, cssSecPer100m: 95, vdot: 52
)
let eq = Equipment(hasBike: true, bikeType: .road, bikeWeightKg: 8, hasAeroBars: true)
let pred = RacePredictor().predict(format: .olympic, profile: profile, equipment: eq)
check("olympique plausible (2h–2h45)  [\(mmss(pred.totalSeconds))]", pred.totalSeconds > 2*3600 && pred.totalSeconds < 2.75*3600)
let sum = (pred.swimSeconds ?? 0) + (pred.t1Seconds ?? 0) + (pred.bikeSeconds ?? 0) + (pred.t2Seconds ?? 0) + pred.runSeconds
approx("somme des splits = total", sum, pred.totalSeconds, 0.5)
print("   → nat \(mmss(pred.swimSeconds ?? 0)) | T1 \(mmss(pred.t1Seconds ?? 0)) | vélo \(mmss(pred.bikeSeconds ?? 0)) | T2 \(mmss(pred.t2Seconds ?? 0)) | course \(mmss(pred.runSeconds)) — IC ±\(Int(pred.confidenceHalfWidth*100))%")

// MARK: Périodisation
print("\nPériodisation")
let race = Race(date: Date(timeInterval: 12*7*86400, since: start), format: .olympic, priority: .a, title: "A")
let weeks = Periodizer().plan(start: start, race: race)
func rank(_ p: TrainingPhase) -> Int { [.base,.build,.specific,.taper,.recovery].firstIndex(of: p)! }
check("phases non décroissantes", zip(weeks, weeks.dropFirst()).allSatisfy { rank($0.phase) <= rank($1.phase) })
check("contient une semaine de décharge", weeks.contains { $0.isDeload })
check("se termine par l'affûtage", weeks.last!.phase == .taper)

// MARK: Génération de séances
print("\nGénérateur de séances")
let zones = ZoneCalculator().zones(for: profile)
let equip = Equipment(hasBike: true, bikeType: .road, hasAeroBars: true, poolAccess: true, runOutdoor: true, strengthAccess: .homeWeights)
let gen = SessionGenerator()
let thr = gen.generate(sport: .run, intent: .threshold, phase: .build, date: start, zones: zones, profile: profile, equipment: equip)
check("course seuil : échauffement + bloc + retour au calme",
      thr.steps.first?.kind == .warmup && thr.steps.last?.kind == .cooldown && thr.steps.contains { $0.kind == .repeatBlock })
check("charge & durée estimées > 0", thr.estimatedLoad > 0 && thr.estimatedDuration > 0)
let baseR = gen.generate(sport: .run, intent: .endurance, phase: .base, date: start, zones: zones, profile: profile, equipment: equip)
let buildR = gen.generate(sport: .run, intent: .endurance, phase: .build, date: start, zones: zones, profile: profile, equipment: equip)
check("phase build > phase base (volume)", buildR.estimatedLoad > baseR.estimatedLoad)
let swimS = gen.generate(sport: .swim, intent: .technique, phase: .base, date: start, zones: zones, profile: profile, equipment: equip)
check("natation exprimée en longueurs", swimS.steps.contains { if case .lengths = $0.duration { return true }; return false })

// MARK: Récupération
print("\nÉvaluation de la récupération")
let hist = (0..<7).map { DailyReadiness(date: Date(timeInterval: Double($0)*86400, since: start), sleepHours: 8, hrRest: 48, hrvMs: 80) }
let goodDay = ReadinessEvaluator().assess(today: DailyReadiness(date: start, sleepHours: 8, hrRest: 47, hrvMs: 82, subjective: SubjectiveCheckin(form: 5, sleepQuality: 5, soreness: 5, motivation: 5)), history: hist)
let badDay = ReadinessEvaluator().assess(today: DailyReadiness(date: start, sleepHours: 5, hrRest: 58, hrvMs: 42, subjective: SubjectiveCheckin(form: 2, sleepQuality: 2, soreness: 1, motivation: 2)), history: hist)
check("jour frais → good", goodDay.level == .good)
check("jour fatigué → low", badDay.level == .low)

// MARK: Adaptation
print("\nMoteur d'adaptation")
func rSession(_ d: Int, load: Double = 90, intent: SessionIntent = .vo2) -> PlannedSession {
    PlannedSession(date: Date(timeInterval: Double(d)*86400, since: start), sport: .run, intent: intent, title: "Course", estimatedLoad: load, estimatedDuration: 3600, phase: .build)
}
// Blessure genou → natation + rappel médical
let injCtx = AdaptationContext(today: start, upcoming: [rSession(1)],
    injuries: [InjuryRecord(zone: .knee, intensity: 4, since: start, affectedSports: [.run])],
    equipment: equip, profile: profile, zones: zones)
let injRes = Adapter().adapt(injCtx)
check("blessure genou : course → natation", injRes.plan.first?.sport == .swim)
check("rappel médical présent", injRes.events.first { $0.kind == .injuryAdjusted }?.message.contains("avis médical") ?? false)
// Récupération basse → allègement
let easeCtx = AdaptationContext(today: start, upcoming: [rSession(0)],
    readinessToday: DailyReadiness(date: start, sleepHours: 5, hrRest: 60, hrvMs: 40, subjective: SubjectiveCheckin(form: 1, sleepQuality: 1, soreness: 1, motivation: 1)),
    readinessHistory: hist, equipment: equip, profile: profile, zones: zones)
check("récup basse → séance allégée en récupération", Adapter().adapt(easeCtx).plan.first?.intent == .recovery)
// ACWR élevé → décharge
let acwrCtx = AdaptationContext(today: start, upcoming: [rSession(1, load: 100)],
    recentLoad: [LoadPoint(date: start, dailyLoad: 100, ctl: 60, atl: 95, tsb: -35, acwr: 1.7)],
    equipment: equip, profile: profile, zones: zones)
let acwrRes = Adapter().adapt(acwrCtx)
check("ACWR 1.7 → décharge appliquée", acwrRes.events.contains { $0.kind == .deload } && acwrRes.plan.first!.estimatedLoad < 100)
// Rattrapage intelligent
let missedFresh = AdaptationContext(today: start, upcoming: [], missed: [rSession(-1, load: 70)],
    recentLoad: [LoadPoint(date: start, dailyLoad: 40, ctl: 50, atl: 45, tsb: 5, acwr: 1.0)],
    equipment: equip, profile: profile, zones: zones)
check("séance manquée (frais) → replanifiée", Adapter().adapt(missedFresh).events.contains { $0.kind == .rescheduled })

// MARK: Assemblage complet du plan
print("\nPlanBuilder (assemblage bout-en-bout)")
let planProfile = AthleteProfile(
    birthDate: Date(timeIntervalSince1970: 631152000), sex: .male, heightCm: 180, weightKg: 72,
    hrMax: 190, hrRest: 48, ftpWatts: 250, cssSecPer100m: 95, vdot: 50,
    levels: [.swim: .novice, .bike: .advanced, .run: .intermediate]
)
let raceA = Race(date: Date(timeInterval: 12*7*86400, since: start), format: .olympic, priority: .a, title: "Triathlon M")
let plan = PlanBuilder().build(profile: planProfile, equipment: equip, race: raceA, start: start,
                               availability: WeeklyAvailability(maxSessionsPerWeek: 6))
check("plan non vide (\(plan.sessions.count) séances sur \(plan.weeks.count) sem.)", !plan.sessions.isEmpty)
check("chaque semaine a des séances", plan.weeks.allSatisfy { w in
    let end = Date(timeInterval: 7*86400, since: w.startDate)
    return plan.sessions.contains { $0.date >= w.startDate && $0.date < end }
})
let buildWk = plan.weeks.first { $0.phase == .build }!
let endB = Date(timeInterval: 7*86400, since: buildWk.startDate)
let buildSports = Set(plan.sessions.filter { $0.date >= buildWk.startDate && $0.date < endB }.map(\.sport))
check("semaine build couvre nat+vélo+course", buildSports.isSuperset(of: [.swim, .bike, .run]))
// Polarisation par le VOLUME : seules les séances vraiment intenses (seuil/VO2/sprint)
// comptent comme « dur » ; endurance/tempo/brick/renfo = aérobie dominant.
let hardIntents: Set<SessionIntent> = [.threshold, .vo2, .sprint]
let hardVol = plan.sessions.filter { hardIntents.contains($0.intent) }.reduce(0.0) { $0 + $1.estimatedDuration }
let totalVol = plan.sessions.reduce(0.0) { $0 + $1.estimatedDuration }
let easyPct = 1 - hardVol / totalVol
check("polarisation ~80/20 en volume (facile \(Int(easyPct*100))%)", easyPct >= 0.72)
// Intensité vélo : la semaine build doit contenir des intervalles vélo (seuil/VO2).
let buildBike = plan.sessions.filter { $0.date >= buildWk.startDate && $0.date < endB && $0.sport == .bike }
check("intervalles vélo présents en build", buildBike.contains { [.threshold, .vo2].contains($0.intent) })
approx("charge S build ≈ cible", plan.load(forWeekIndex: buildWk.index), buildWk.targetLoad, buildWk.targetLoad * 0.3)
let peakLoad = plan.weeks.filter { $0.phase != .taper }.map { plan.load(forWeekIndex: $0.index) }.max()!
check("affûtage plus léger que le pic", plan.weeks.filter { $0.phase == .taper }.allSatisfy { plan.load(forWeekIndex: $0.index) < peakLoad })
// Démarrage sans vélo ni piscine → substitution automatique
let noGear = Equipment(hasBike: false, poolAccess: false, openWaterAccess: false, hasDrylandCords: true, runOutdoor: true, strengthAccess: .bodyweightOnly)
let planNoGear = PlanBuilder().build(profile: planProfile, equipment: noGear, race: Race(date: Date(timeInterval: 8*7*86400, since: start), format: .olympic, priority: .a, title: "M"), start: start, availability: WeeklyAvailability(maxSessionsPerWeek: 6))
check("démarrage sans vélo/piscine : plan quand même, sans vélo ni bassin",
      !planNoGear.sessions.isEmpty && !planNoGear.sessions.contains { $0.sport == .bike || $0.sport == .swim })
// Aperçu semaine 1
let w1End = Date(timeInterval: 7*86400, since: plan.weeks[0].startDate)
let w1 = plan.sessions.filter { $0.date >= plan.weeks[0].startDate && $0.date < w1End }
print("   Semaine 1 (\(plan.weeks[0].phase.rawValue), cible \(Int(plan.weeks[0].targetLoad))) :")
for s in w1 { print("     • \(s.title) — charge \(Int(s.estimatedLoad)), \(Int(s.estimatedDuration/60)) min") }

// Progression : Performance monte plus fort que Prudent.
let planPrudent = PlanBuilder().build(profile: planProfile, equipment: equip, race: raceA, start: start,
    availability: WeeklyAvailability(maxSessionsPerWeek: 6), config: .init(progression: .prudent))
let planPerf = PlanBuilder().build(profile: planProfile, equipment: equip, race: raceA, start: start,
    availability: WeeklyAvailability(maxSessionsPerWeek: 6), config: .init(progression: .performance))
let peakPrudent = (0..<planPrudent.weeks.count).map { planPrudent.load(forWeekIndex: $0) }.max() ?? 0
let peakPerf = (0..<planPerf.weeks.count).map { planPerf.load(forWeekIndex: $0) }.max() ?? 0
check("progression Performance > Prudent (pic de charge)", peakPerf > peakPrudent)

// Disponibilités par lieu : piscine seulement le lundi → toutes les nat le lundi.
let poolMonday = WeeklyAvailability(maxSessionsPerWeek: 6, sportDays: [.swim: [2]])
let planPool = PlanBuilder().build(profile: planProfile, equipment: equip, race: raceA, start: start, availability: poolMonday)
let cal2 = Calendar(identifier: .gregorian)
let swimDays = Set(planPool.sessions.filter { $0.sport == .swim }.map { cal2.component(.weekday, from: $0.date) })
check("natation uniquement le lundi (jours piscine respectés)", swimDays.isSubset(of: [2]) && !swimDays.isEmpty)

// Courses multiples : mini-affûtage → pas d'entraînement le jour de la course B.
let raceB = Race(date: Date(timeInterval: 6*7*86400, since: start), format: .sprint, priority: .b, title: "Sprint local")
let planMulti = PlanBuilder().build(profile: planProfile, equipment: equip, races: [raceB, raceA], start: start,
    availability: WeeklyAvailability(maxSessionsPerWeek: 6))
check("aucune séance le jour de la course B", !planMulti.sessions.contains { cal2.isDate($0.date, inSameDayAs: raceB.date) })

// MARK: Analyse post-séance & records
print("\nAnalyse post-séance & records")
let doneRun = CompletedActivity(sport: .run, start: start, duration: 3000, distanceM: 9000, avgHr: 150, avgPaceSecPerKm: 320, hrDriftPct: 3.5)
let histRun = [
    CompletedActivity(sport: .run, start: Date(timeInterval: -86400, since: start), duration: 2700, distanceM: 7000, avgPaceSecPerKm: 350),
    CompletedActivity(sport: .run, start: Date(timeInterval: -172800, since: start), duration: 2700, distanceM: 6000, avgPaceSecPerKm: 345)
]
let analysis = PostSessionAnalyzer().analyze(activity: doneRun, profile: profile, history: histRun)
check("analyse : titre non vide", !analysis.headline.isEmpty)
check("analyse : dérive cardiaque faible détectée", analysis.insights.contains { $0.contains("Dérive") })
check("analyse : progression d'allure détectée", analysis.insights.contains { $0.contains("progresse") })
let records = PersonalRecords().compute(from: [doneRun] + histRun)
check("records : plus longue distance course", records.contains { $0.sportKey == "run" && $0.label.contains("distance") })
check("records : meilleure allure course", records.contains { $0.label.contains("allure") })

// MARK: Stratégie de course (nutrition + pacing)
print("\nStratégie de course")
let nutriShort = RaceNutrition.plan(durationSec: 3600, weightKg: 72, format: .sprint)
let nutriLong = RaceNutrition.plan(durationSec: 11 * 3600, weightKg: 72, format: .full)
check("nutrition : glucides/h croît avec la durée", nutriLong.carbsPerHour > nutriShort.carbsPerHour)
check("nutrition : total cohérent (long > court)", nutriLong.totalCarbs > nutriShort.totalCarbs)
let pacing = RacePacing.targets(format: .olympic, profile: profile)
check("pacing : 3 cibles (nat/vélo/course) pour un triathlon", pacing.count == 3)
check("pacing : cible vélo en % FTP", pacing.contains { $0.sportKey == "bike" && $0.value.contains("FTP") })

// MARK: Bilan
print("\n" + String(repeating: "─", count: 40))
print("Résultat : \(passed) réussis, \(failed) échoués")
if failed > 0 { exit(1) } else { print("✅ Moteur validé.\n") }
