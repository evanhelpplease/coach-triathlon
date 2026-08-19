import Foundation
import TriathlonEngine

// Conversions Domain (moteur, pur) ⇄ Modèles SwiftData (persistance).

extension ProfileModel {
    var domain: AthleteProfile {
        AthleteProfile(
            birthDate: birthDate,
            sex: BiologicalSex(rawValue: sexRaw) ?? .other,
            heightCm: heightCm, weightKg: weightKg,
            hrMax: hrMax, hrRest: hrRest, ftpWatts: ftpWatts,
            cssSecPer100m: cssSecPer100m, vdot: vdot,
            levels: [
                .swim: SkillLevel(rawValue: swimLevel) ?? .beginner,
                .bike: SkillLevel(rawValue: bikeLevel) ?? .beginner,
                .run:  SkillLevel(rawValue: runLevel) ?? .beginner
            ]
        )
    }

    func apply(_ p: AthleteProfile) {
        birthDate = p.birthDate
        sexRaw = p.sex.rawValue
        heightCm = p.heightCm
        weightKg = p.weightKg
        hrMax = p.hrMax; hrRest = p.hrRest; ftpWatts = p.ftpWatts
        cssSecPer100m = p.cssSecPer100m; vdot = p.vdot
        swimLevel = (p.levels[.swim] ?? .beginner).rawValue
        bikeLevel = (p.levels[.bike] ?? .beginner).rawValue
        runLevel = (p.levels[.run] ?? .beginner).rawValue
    }

    var progression: ProgressionLevel { ProgressionLevel(rawValue: progressionRaw) ?? .balanced }

    private static func decodeDays(_ mask: Int) -> Set<Int> {
        var s = Set<Int>()
        for wd in 1...7 where (mask & (1 << (wd - 1))) != 0 { s.insert(wd) }
        return s
    }

    /// Disponibilités hebdomadaires + restrictions par lieu (piscine, piste…).
    var availability: WeeklyAvailability {
        let days = Self.decodeDays(availableWeekdaysMask)
        var sportDays: [Sport: Set<Int>] = [:]
        if swimDaysMask != 0 { sportDays[.swim] = Self.decodeDays(swimDaysMask) }
        if bikeDaysMask != 0 { sportDays[.bike] = Self.decodeDays(bikeDaysMask) }
        if runDaysMask != 0 { sportDays[.run] = Self.decodeDays(runDaysMask) }
        if strengthDaysMask != 0 { sportDays[.strength] = Self.decodeDays(strengthDaysMask) }
        return WeeklyAvailability(
            availableWeekdays: days.isEmpty ? [2, 3, 4, 5, 6, 7, 1] : days,
            maxSessionsPerWeek: max(1, maxSessionsPerWeek),
            sportDays: sportDays
        )
    }

    /// Disciplines sans référentiel mesuré (→ test de terrain à planifier).
    var missingReferentials: Set<Sport> {
        var m = Set<Sport>()
        if vdot == nil { m.insert(.run) }
        if ftpWatts == nil { m.insert(.bike) }
        if cssSecPer100m == nil { m.insert(.swim) }
        return m
    }
}

extension EquipmentModel {
    var domain: Equipment {
        Equipment(
            hasBike: hasBike,
            bikeType: bikeTypeRaw.flatMap(BikeType.init(rawValue:)),
            bikeWeightKg: bikeWeightKg,
            hasAeroBars: hasAeroBars, hasPowerMeter: hasPowerMeter, hasSmartTrainer: hasSmartTrainer,
            poolAccess: poolAccess, openWaterAccess: openWaterAccess,
            hasWetsuit: hasWetsuit, hasDrylandCords: hasDrylandCords,
            runOutdoor: runOutdoor, hasTreadmill: hasTreadmill, hasTrack: hasTrack,
            strengthAccess: Equipment.StrengthAccess(rawValue: strengthAccessRaw) ?? .bodyweightOnly
        )
    }

    func apply(_ e: Equipment) {
        hasBike = e.hasBike
        bikeTypeRaw = e.bikeType?.rawValue
        bikeWeightKg = e.bikeWeightKg
        hasAeroBars = e.hasAeroBars; hasPowerMeter = e.hasPowerMeter; hasSmartTrainer = e.hasSmartTrainer
        poolAccess = e.poolAccess; openWaterAccess = e.openWaterAccess
        hasWetsuit = e.hasWetsuit; hasDrylandCords = e.hasDrylandCords
        runOutdoor = e.runOutdoor; hasTreadmill = e.hasTreadmill; hasTrack = e.hasTrack
        strengthAccessRaw = e.strengthAccess.rawValue
        updatedAt = .now
    }
}

extension RaceModel {
    var domain: Race {
        Race(id: id, date: date,
             format: RaceFormat(rawValue: formatRaw) ?? .olympic,
             priority: RacePriority(rawValue: priorityRaw) ?? .a,
             title: title)
    }
    func apply(_ r: Race) {
        id = r.id; date = r.date; formatRaw = r.format.rawValue
        priorityRaw = r.priority.rawValue; title = r.title
    }
}

extension PlannedSessionModel {
    var domain: PlannedSession {
        let steps: [WorkoutStep] = stepsData.flatMap { try? JSONDecoder().decode([WorkoutStep].self, from: $0) } ?? []
        return PlannedSession(
            id: id, date: date,
            sport: Sport(rawValue: sportRaw) ?? .run,
            intent: SessionIntent(rawValue: intentRaw) ?? .endurance,
            title: title, steps: steps,
            estimatedLoad: estimatedLoad, estimatedDuration: estimatedDuration,
            notes: notes,
            phase: phaseRaw.flatMap(TrainingPhase.init(rawValue:))
        )
    }
    func apply(_ s: PlannedSession) {
        id = s.id; date = s.date; sportRaw = s.sport.rawValue; intentRaw = s.intent.rawValue
        title = s.title; estimatedLoad = s.estimatedLoad; estimatedDuration = s.estimatedDuration
        notes = s.notes; phaseRaw = s.phase?.rawValue
        stepsData = try? JSONEncoder().encode(s.steps)
    }

    convenience init(_ s: PlannedSession) {
        self.init()
        apply(s)
    }
}

extension InjuryModel {
    var zone: InjuryRecord.BodyZone { InjuryRecord.BodyZone(rawValue: zoneRaw) ?? .other }

    /// Sports impactés (dérivés de la zone), pour affichage.
    static func affectedSports(_ zone: InjuryRecord.BodyZone) -> Set<Sport> {
        switch zone {
        case .knee, .ankle, .foot, .calf, .hamstring, .hip: return [.run, .brick]
        case .shoulder: return [.swim]
        case .lowerBack: return [.brick]
        case .other: return []
        }
    }

    var domain: InjuryRecord {
        InjuryRecord(zone: zone, intensity: intensity, since: since,
                     affectedSports: Self.affectedSports(zone))
    }
}

extension UnavailabilityModel {
    var sport: Sport { Sport(rawValue: sportRaw) ?? .swim }

    var domain: Unavailability {
        Unavailability(id: id, sport: sport, start: startDate, end: endDate, note: note)
    }
}

extension DailyCheckinModel {
    var domain: DailyReadiness {
        let subjective: SubjectiveCheckin?
        if let f = form, let sl = sleepQuality, let so = soreness, let mo = motivation {
            subjective = SubjectiveCheckin(form: f, sleepQuality: sl, soreness: so, motivation: mo)
        } else { subjective = nil }
        return DailyReadiness(date: date, sleepHours: sleepHours, hrRest: hrRest, hrvMs: hrvMs,
                              bodyBattery: nil, subjective: subjective)
    }
}
