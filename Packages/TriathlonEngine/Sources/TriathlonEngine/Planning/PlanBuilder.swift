import Foundation

/// Disponibilités d'entraînement de l'athlète.
public struct WeeklyAvailability: Sendable, Equatable {
    /// Jours disponibles (composante `weekday` grégorienne : 1 = dimanche … 7 = samedi).
    public var availableWeekdays: Set<Int>
    public var maxSessionsPerWeek: Int
    /// Restriction par sport (ex. natation seulement lun/mer/ven). Vide = aucune restriction.
    public var sportDays: [Sport: Set<Int>]

    public init(availableWeekdays: Set<Int> = [2, 3, 4, 5, 6, 7, 1], maxSessionsPerWeek: Int = 6,
                sportDays: [Sport: Set<Int>] = [:]) {
        self.availableWeekdays = availableWeekdays
        self.maxSessionsPerWeek = maxSessionsPerWeek
        self.sportDays = sportDays
    }

    static let weekendDays: Set<Int> = [7, 1] // samedi, dimanche

    /// Jours autorisés pour un sport (restriction ∩ jours dispo, sinon tous les jours dispo).
    func allowedWeekdays(for sport: Sport) -> Set<Int> {
        guard let restricted = sportDays[sport], !restricted.isEmpty else { return availableWeekdays }
        return restricted.intersection(availableWeekdays)
    }
}

/// Plan d'entraînement concret : zones, découpage hebdomadaire et séances datées.
public struct TrainingPlan: Sendable {
    public var zones: TrainingZones
    public var weeks: [PlannedWeek]
    public var sessions: [PlannedSession]
    public var rationale: [String]

    /// Charge totale planifiée pour une semaine donnée (par index de semaine).
    public func load(forWeekIndex index: Int, calendar: Calendar = .init(identifier: .gregorian)) -> Double {
        guard index < weeks.count else { return 0 }
        let start = weeks[index].startDate
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return sessions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.estimatedLoad }
    }
}

/// Orchestrateur : assemble un plan complet à partir des entrées de l'athlète.
public struct PlanBuilder: Sendable {
    private let zoneCalc = ZoneCalculator()
    private let periodizer = Periodizer()
    private let generator: SessionGenerator
    private let substitution = EquipmentSubstitution()

    public struct Config: Sendable {
        public var progression: ProgressionLevel
        public var poolMeters: Double
        public var startingWeeklyLoad: Double
        public init(progression: ProgressionLevel = .balanced, poolMeters: Double = 25, startingWeeklyLoad: Double = 300) {
            self.progression = progression
            self.poolMeters = poolMeters
            self.startingWeeklyLoad = startingWeeklyLoad
        }
    }

    public init() { self.generator = SessionGenerator() }

    /// Compatibilité : une seule course cible.
    public func build(profile: AthleteProfile, equipment: Equipment, race: Race, start: Date,
                      availability: WeeklyAvailability, config: Config = Config(),
                      calendar: Calendar = .init(identifier: .gregorian)) -> TrainingPlan {
        build(profile: profile, equipment: equipment, races: [race], start: start,
              availability: availability, config: config, calendar: calendar)
    }

    /// Plan périodisé vers la dernière course, avec mini-affûtage avant chaque course
    /// intermédiaire pour arriver frais sur chacune.
    public func build(profile: AthleteProfile, equipment: Equipment, races: [Race], start: Date,
                      availability: WeeklyAvailability, config: Config = Config(),
                      calendar: Calendar = .init(identifier: .gregorian)) -> TrainingPlan {
        let zones = zoneCalc.zones(for: profile, on: start)
        let sorted = races.sorted { $0.date < $1.date }
        guard let target = sorted.last else {
            return TrainingPlan(zones: zones, weeks: [], sessions: [], rationale: ["Aucune course."])
        }
        let gen = SessionGenerator(poolMeters: config.poolMeters)
        let perio = Periodizer.Config.forProgression(config.progression, startingWeeklyLoad: config.startingWeeklyLoad)
        let weeks = periodizer.plan(start: start, race: target, config: perio, calendar: calendar)

        var allSessions: [PlannedSession] = []
        for week in weeks {
            allSessions.append(contentsOf: buildWeek(
                week: week, target: target, profile: profile, equipment: equipment, zones: zones,
                availability: availability, progression: config.progression, generator: gen, calendar: calendar
            ))
        }
        applyRaceTapers(&allSessions, races: sorted, calendar: calendar)

        var rationale = ["Plan périodisé vers « \(target.title) » : \(weeks.count) semaines, pic de forme le jour J."]
        if sorted.count > 1 { rationale.append("\(sorted.count) courses programmées : mini-affûtage avant chaque course.") }
        rationale.append(contentsOf: weeks.prefix(3).map { "S\($0.index + 1) (\($0.phase.rawValue)) : \($0.rationale)" })
        return TrainingPlan(zones: zones, weeks: weeks, sessions: allSessions.sorted { $0.date < $1.date }, rationale: rationale)
    }

    /// Mini-affûtage : allège J-1 et J-2 avant chaque course et retire l'entraînement le jour J.
    private func applyRaceTapers(_ sessions: inout [PlannedSession], races: [Race], calendar cal: Calendar) {
        for race in races {
            let raceDay = cal.startOfDay(for: race.date)
            sessions.removeAll { cal.isDate($0.date, inSameDayAs: raceDay) }
            for i in sessions.indices {
                let d = cal.dateComponents([.day], from: cal.startOfDay(for: sessions[i].date), to: raceDay).day ?? 99
                if d == 1 || d == 2 {
                    sessions[i].estimatedLoad = (sessions[i].estimatedLoad * 0.5).rounded()
                    sessions[i].estimatedDuration *= 0.6
                    if sessions[i].intent != .recovery { sessions[i].intent = .endurance }
                }
            }
        }
    }

    // MARK: - Construction d'une semaine

    private func buildWeek(
        week: PlannedWeek, target: Race, profile: AthleteProfile, equipment: Equipment,
        zones: TrainingZones, availability: WeeklyAvailability, progression: ProgressionLevel,
        generator gen: SessionGenerator, calendar cal: Calendar
    ) -> [PlannedSession] {
        // 1) Jours dispo dans la fenêtre de 7 jours.
        let candidateDates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: week.startDate) }
            .filter { availability.availableWeekdays.contains(cal.component(.weekday, from: $0)) }
        guard !candidateDates.isEmpty else { return [] }

        // 2) Gabarit selon phase + progression (répartit l'intensité sur les 3 sports).
        let slots = weeklySlots(phase: week.phase, format: target.format, profile: profile, progression: progression)
        let n = min(availability.maxSessionsPerWeek, candidateDates.count)
        guard n > 0 else { return [] }

        // 3) Placement respectant les jours par lieu (piscine, piste…), longues le week-end.
        let dated = assignDates(slots: slots, dates: candidateDates, availability: availability, maxCount: n, calendar: cal)

        // 4) Matérialisation + substitution matériel.
        var sessions = dated.map { item in
            materialize(sport: item.slot.sport, intent: item.slot.intent, phase: week.phase,
                        date: item.date, zones: zones, profile: profile, equipment: equipment, generator: gen)
        }

        // 5) Mise à l'échelle sur la charge hebdo cible.
        scaleToTarget(&sessions, target: week.targetLoad)
        return sessions
    }

    // MARK: - Gabarit hebdomadaire

    private struct Slot { var sport: Sport; var intent: SessionIntent; var isLong: Bool }

    /// Nombre de séances qualité (intensité) par semaine, selon la phase et la
    /// volonté de progression. Le socle reste aérobie (polarisation par le VOLUME).
    private func qualityCount(_ phase: TrainingPhase, _ prog: ProgressionLevel) -> Int {
        switch phase {
        case .base:     return prog == .performance ? 2 : 1
        case .build:    return prog == .performance ? 3 : 2
        case .specific: return prog == .prudent ? 2 : 3
        case .taper:    return 1
        case .recovery: return 0
        }
    }

    /// Intention d'une séance qualité selon phase, sport et progression.
    private func qualityIntent(_ phase: TrainingPhase, _ sport: Sport, _ prog: ProgressionLevel) -> SessionIntent {
        switch phase {
        case .base: return .tempo
        case .build:
            switch sport {
            case .run:  return .vo2
            case .bike: return prog == .performance ? .vo2 : .threshold   // ← intervalles vélo
            case .swim: return .threshold
            default:    return .threshold
            }
        case .specific: return .threshold      // allure/puissance spécifique course
        case .taper:    return .threshold
        case .recovery: return .endurance
        }
    }

    private func weeklySlots(phase: TrainingPhase, format: RaceFormat, profile: AthleteProfile,
                             progression prog: ProgressionLevel) -> [Slot] {
        let tri = format.isTriathlon
        var slots: [Slot] = []

        // Socle aérobie (domine le volume → polarisation ~80/20 préservée).
        slots.append(Slot(sport: .run, intent: .endurance, isLong: true))
        slots.append(Slot(sport: .bike, intent: .endurance, isLong: tri))
        if tri { slots.append(Slot(sport: .swim, intent: .endurance, isLong: false)) }

        // Séances qualité RÉPARTIES sur les disciplines (le vélo en a une dès 2 qualité).
        let qSports: [Sport] = tri ? [.run, .bike, .swim] : [.run]
        let qc = tri ? qualityCount(phase, prog) : min(qualityCount(phase, prog), 2)
        for i in 0..<qc {
            let s = qSports[i % qSports.count]
            slots.append(Slot(sport: s, intent: qualityIntent(phase, s, prog), isLong: false))
        }

        // Brick spécifique triathlon en build/spécifique.
        if tri && (phase == .build || phase == .specific) {
            slots.append(Slot(sport: .brick, intent: .brick, isLong: true))
        }
        // Renforcement (hors affûtage).
        if phase != .taper { slots.append(Slot(sport: .strength, intent: .strength, isLong: false)) }

        // Fillers d'endurance.
        slots += tri
            ? [Slot(sport: .bike, intent: .endurance, isLong: false),
               Slot(sport: .run, intent: .endurance, isLong: false),
               Slot(sport: .swim, intent: .endurance, isLong: false)]
            : [Slot(sport: .run, intent: .endurance, isLong: false),
               Slot(sport: .bike, intent: .endurance, isLong: false)]

        // Priorise le point faible.
        if let weakest = weakestDiscipline(profile),
           let idx = slots.firstIndex(where: { $0.sport.rawValue == weakest.rawValue && $0.intent == .endurance }) {
            let s = slots.remove(at: idx); slots.insert(s, at: 0)
        }
        // Récupération : tout devient récup.
        if phase == .recovery { slots = slots.map { Slot(sport: $0.sport, intent: .recovery, isLong: false) } }
        return slots
    }

    private func weakestDiscipline(_ profile: AthleteProfile) -> Discipline? {
        profile.levels.min { $0.value < $1.value }?.key
    }

    // MARK: - Placement des dates

    private struct DatedSlot { var slot: Slot; var date: Date }

    /// Place les créneaux en respectant les jours autorisés PAR SPORT (piscine, piste…),
    /// les plus contraints d'abord, longues sur le week-end, dans la limite de `maxCount`.
    private func assignDates(slots: [Slot], dates: [Date], availability: WeeklyAvailability,
                             maxCount: Int, calendar cal: Calendar) -> [DatedSlot] {
        func allowed(_ slot: Slot) -> [Date] {
            let days = availability.allowedWeekdays(for: slot.sport)
            return dates.filter { days.contains(cal.component(.weekday, from: $0)) }
        }
        // Ordre : sport le plus contraint d'abord (sinon la piscine « perd » ses jours),
        // en conservant la priorité du gabarit à contrainte égale.
        let ordered = slots.enumerated().sorted { a, b in
            let ca = allowed(a.element).count, cb = allowed(b.element).count
            return ca != cb ? ca < cb : a.offset < b.offset
        }.map { $0.element }

        var used: Set<Date> = []
        var result: [DatedSlot] = []
        for slot in ordered {
            guard result.count < maxCount else { break }
            let options = allowed(slot).filter { !used.contains($0) }
            guard !options.isEmpty else { continue }   // sport indisponible cette semaine → séance sautée
            let weekend = options.filter { WeeklyAvailability.weekendDays.contains(cal.component(.weekday, from: $0)) }
            let date = (slot.isLong ? weekend.first : nil) ?? options.first!
            used.insert(date)
            result.append(DatedSlot(slot: slot, date: date))
        }
        return result.sorted { $0.date < $1.date }
    }

    // MARK: - Matérialisation & substitution

    private func materialize(sport: Sport, intent: SessionIntent, phase: TrainingPhase, date: Date,
                             zones: TrainingZones, profile: AthleteProfile, equipment: Equipment,
                             generator gen: SessionGenerator) -> PlannedSession {
        let base = gen.generate(sport: sport, intent: intent, phase: phase, date: date,
                                zones: zones, profile: profile, equipment: equipment)
        let sub = substitution.substitute(base, equipment: equipment)
        guard sub.changed else { return base }
        // Le sport a changé : on régénère un contenu cohérent pour le nouveau sport.
        var repl = gen.generate(sport: sub.session.sport, intent: intent, phase: phase, date: date,
                                zones: zones, profile: profile, equipment: equipment)
        repl.title = sub.session.title
        repl.notes = sub.explanation
        return repl
    }

    // MARK: - Mise à l'échelle sur la charge cible

    private func scaleToTarget(_ sessions: inout [PlannedSession], target: Double) {
        let sum = sessions.reduce(0) { $0 + $1.estimatedLoad }
        guard sum > 0, target > 0 else { return }
        // Facteur borné pour ne pas dénaturer les séances.
        let factor = min(2.5, max(0.4, target / sum))
        for i in sessions.indices {
            sessions[i].estimatedLoad = (sessions[i].estimatedLoad * factor).rounded()
            sessions[i].estimatedDuration *= factor
        }
    }
}
