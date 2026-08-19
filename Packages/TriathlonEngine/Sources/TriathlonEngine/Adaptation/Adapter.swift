import Foundation

/// Événement d'adaptation : chaque ajustement automatique est tracé et expliqué
/// (affichable et, côté app, annulable).
public struct AdaptationEvent: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable, Codable {
        case eased, rescheduled, deload, substituted, injuryAdjusted, alert, recalibrated
    }
    public var id: UUID
    public var kind: Kind
    public var date: Date
    public var sessionID: UUID?
    public var message: String

    public init(id: UUID = UUID(), kind: Kind, date: Date, sessionID: UUID? = nil, message: String) {
        self.id = id; self.kind = kind; self.date = date; self.sessionID = sessionID; self.message = message
    }
}

/// Contexte d'entrée du moteur d'adaptation.
public struct AdaptationContext: Sendable {
    public var today: Date
    public var upcoming: [PlannedSession]        // séances >= aujourd'hui, triées par date
    public var missed: [PlannedSession]          // séances passées non réalisées
    public var recentLoad: [LoadPoint]           // pour ACWR / TSB (le dernier = le plus récent)
    public var readinessToday: DailyReadiness?
    public var readinessHistory: [DailyReadiness]
    public var injuries: [InjuryRecord]
    public var equipment: Equipment
    public var profile: AthleteProfile
    public var zones: TrainingZones

    public init(
        today: Date,
        upcoming: [PlannedSession],
        missed: [PlannedSession] = [],
        recentLoad: [LoadPoint] = [],
        readinessToday: DailyReadiness? = nil,
        readinessHistory: [DailyReadiness] = [],
        injuries: [InjuryRecord] = [],
        equipment: Equipment,
        profile: AthleteProfile,
        zones: TrainingZones
    ) {
        self.today = today
        self.upcoming = upcoming
        self.missed = missed
        self.recentLoad = recentLoad
        self.readinessToday = readinessToday
        self.readinessHistory = readinessHistory
        self.injuries = injuries
        self.equipment = equipment
        self.profile = profile
        self.zones = zones
    }
}

public struct AdaptationResult: Sendable {
    public var plan: [PlannedSession]
    public var events: [AdaptationEvent]
}

/// Rappel médical systématique, jamais absent des ajustements liés à la douleur.
public let medicalDisclaimer = "Ceci ne remplace pas un avis médical : si la douleur persiste, consulte un professionnel."

/// Moteur de règles d'adaptation. Applique, dans l'ordre : sécurité (blessures),
/// disponibilité matériel, récupération du jour, garde-fous de charge, rattrapage.
public struct Adapter: Sendable {
    private let generator: SessionGenerator
    private let substitution = EquipmentSubstitution()
    private let readiness = ReadinessEvaluator()

    public init(generator: SessionGenerator = SessionGenerator()) {
        self.generator = generator
    }

    public func adapt(_ ctx: AdaptationContext) -> AdaptationResult {
        var plan = ctx.upcoming.sorted { $0.date < $1.date }
        var events: [AdaptationEvent] = []

        // 1) Blessures — priorité sécurité.
        (plan, events) = applyInjuries(plan, events: events, ctx: ctx)

        // 2) Disponibilité matériel.
        (plan, events) = applyEquipment(plan, events: events, ctx: ctx)

        // 3) Récupération du jour → allègement de la séance du jour si nécessaire.
        (plan, events) = applyReadiness(plan, events: events, ctx: ctx)

        // 4) Garde-fous de charge (ACWR / TSB).
        (plan, events) = applyLoadGuards(plan, events: events, ctx: ctx)

        // 5) Rattrapage intelligent des séances manquées.
        (plan, events) = applyReschedule(plan, events: events, ctx: ctx)

        return AdaptationResult(plan: plan.sorted { $0.date < $1.date }, events: events)
    }

    // MARK: - 1. Blessures

    /// Sports interdits et alternative sûre selon la zone blessée.
    private func injuryPolicy(_ zone: InjuryRecord.BodyZone) -> (forbidden: Set<Sport>, safe: Sport, hint: String) {
        switch zone {
        case .knee: return ([.run, .brick], .swim, "Genou : natation avec pull buoy conservée, vélo allégé, course suspendue.")
        case .ankle, .foot, .calf: return ([.run, .brick], .swim, "Cheville/pied : impact évité, natation et vélo maintenus.")
        case .hamstring: return ([.run, .brick], .bike, "Ischios : pas de vitesse à pied, vélo souple et natation ok.")
        case .hip: return ([.run, .brick], .swim, "Hanche : on privilégie natation et vélo doux.")
        case .shoulder: return ([.swim], .bike, "Épaule : natation suspendue, vélo et course maintenus.")
        case .lowerBack: return ([.brick], .bike, "Bas du dos : intensité réduite, position vélo surveillée.")
        case .other: return ([], .swim, "Zone sensible : prudence sur les séances intenses.")
        }
    }

    private func applyInjuries(_ plan: [PlannedSession], events: [AdaptationEvent], ctx: AdaptationContext) -> ([PlannedSession], [AdaptationEvent]) {
        var out = plan, ev = events
        let active = ctx.injuries.filter { $0.intensity >= 3 }
        guard !active.isEmpty else { return (out, ev) }

        for injury in active {
            let policy = injuryPolicy(injury.zone)
            for i in out.indices where policy.forbidden.contains(out[i].sport) {
                let safe = ctx.equipment.canPractice(policy.safe) ? policy.safe : .strength
                var repl = rematerialize(out[i], sport: safe, intent: .recovery, ctx: ctx)
                repl.notes = "\(policy.hint) \(medicalDisclaimer)"
                ev.append(AdaptationEvent(kind: .injuryAdjusted, date: out[i].date, sessionID: out[i].id,
                                          message: policy.hint + " " + medicalDisclaimer))
                out[i] = repl
            }
        }
        return (out, ev)
    }

    // MARK: - 2. Matériel

    private func applyEquipment(_ plan: [PlannedSession], events: [AdaptationEvent], ctx: AdaptationContext) -> ([PlannedSession], [AdaptationEvent]) {
        var out = plan, ev = events
        for i in out.indices {
            let r = substitution.substitute(out[i], equipment: ctx.equipment)
            guard r.changed else { continue }
            // Re-matérialise avec le générateur pour un contenu cohérent du nouveau sport.
            var repl = rematerialize(out[i], sport: r.session.sport, intent: out[i].intent, ctx: ctx)
            repl.title = r.session.title
            repl.notes = r.explanation
            repl.estimatedLoad = r.session.estimatedLoad
            out[i] = repl
            ev.append(AdaptationEvent(kind: .substituted, date: out[i].date, sessionID: out[i].id, message: r.explanation))
        }
        return (out, ev)
    }

    // MARK: - 3. Récupération du jour

    private func applyReadiness(_ plan: [PlannedSession], events: [AdaptationEvent], ctx: AdaptationContext) -> ([PlannedSession], [AdaptationEvent]) {
        guard let today = ctx.readinessToday else { return (plan, events) }
        let a = readiness.assess(today: today, history: ctx.readinessHistory)
        guard a.level != .good else { return (plan, events) }

        var out = plan, ev = events
        let cal = Calendar(identifier: .gregorian)
        // Séance la plus dure du jour.
        let todays = out.indices.filter { cal.isDate(out[$0].date, inSameDayAs: ctx.today) }
        guard let hardest = todays.max(by: { out[$0].estimatedLoad < out[$1].estimatedLoad }) else { return (out, ev) }

        if a.level == .low {
            let repl = rematerialize(out[hardest], sport: out[hardest].sport, intent: .recovery, ctx: ctx)
            out[hardest] = repl
            ev.append(AdaptationEvent(kind: .eased, date: out[hardest].date, sessionID: out[hardest].id,
                                      message: "Récupération basse — on allège aujourd'hui pour mieux progresser demain. (\(a.reasons.first ?? ""))"))
        } else {
            // Modérée : on baisse l'intensité d'un cran sans changer le sport.
            let softer = downshift(out[hardest].intent)
            if softer != out[hardest].intent {
                let repl = rematerialize(out[hardest], sport: out[hardest].sport, intent: softer, ctx: ctx)
                out[hardest] = repl
                ev.append(AdaptationEvent(kind: .eased, date: out[hardest].date, sessionID: out[hardest].id,
                                          message: "Forme moyenne : intensité réduite d'un cran aujourd'hui."))
            }
        }
        return (out, ev)
    }

    private func downshift(_ intent: SessionIntent) -> SessionIntent {
        switch intent {
        case .vo2, .sprint: return .threshold
        case .threshold: return .tempo
        case .tempo: return .endurance
        default: return intent
        }
    }

    // MARK: - 4. Garde-fous de charge

    private func applyLoadGuards(_ plan: [PlannedSession], events: [AdaptationEvent], ctx: AdaptationContext) -> ([PlannedSession], [AdaptationEvent]) {
        guard let last = ctx.recentLoad.last else { return (plan, events) }
        var out = plan, ev = events
        let cal = Calendar(identifier: .gregorian)

        // ACWR trop haut → décharge anticipée des 7 prochains jours (−30 %).
        if last.acwr > 1.5 {
            let horizon = cal.date(byAdding: .day, value: 7, to: ctx.today)!
            for i in out.indices where out[i].date <= horizon {
                out[i].estimatedLoad = (out[i].estimatedLoad * 0.7).rounded()
                out[i].estimatedDuration *= 0.8
            }
            ev.append(AdaptationEvent(kind: .deload, date: ctx.today,
                                      message: "Charge aiguë élevée (ACWR \(String(format: "%.2f", last.acwr))) : semaine allégée de 30 % pour prévenir la blessure."))
        }

        // TSB très négatif → micro-décharge + priorité sommeil.
        if last.tsb < -25 {
            ev.append(AdaptationEvent(kind: .alert, date: ctx.today,
                                      message: "Fraîcheur très basse (TSB \(Int(last.tsb))) : priorité au sommeil, on lève le pied 48 h."))
        }
        return (out, ev)
    }

    // MARK: - 5. Rattrapage des séances manquées

    private func applyReschedule(_ plan: [PlannedSession], events: [AdaptationEvent], ctx: AdaptationContext) -> ([PlannedSession], [AdaptationEvent]) {
        guard !ctx.missed.isEmpty else { return (plan, events) }
        var out = plan, ev = events
        let cal = Calendar(identifier: .gregorian)
        let acwr = ctx.recentLoad.last?.acwr ?? 0

        for missed in ctx.missed {
            // On ne rattrape pas si la charge est déjà trop haute.
            if acwr > 1.2 {
                ev.append(AdaptationEvent(kind: .alert, date: ctx.today, sessionID: missed.id,
                                          message: "Séance « \(missed.title) » non rattrapée volontairement : on ne surcharge pas une semaine déjà lourde."))
                continue
            }
            // Cherche un créneau libre dans les 7 jours.
            var placed = false
            for offset in 1...7 {
                let day = cal.date(byAdding: .day, value: offset, to: ctx.today)!
                let occupied = out.contains { cal.isDate($0.date, inSameDayAs: day) }
                if !occupied {
                    var moved = missed
                    moved.date = day
                    moved.estimatedLoad = (missed.estimatedLoad * 0.9).rounded()
                    out.append(moved)
                    ev.append(AdaptationEvent(kind: .rescheduled, date: day, sessionID: missed.id,
                                              message: "Séance « \(missed.title) » replacée sans surcharger la semaine."))
                    placed = true
                    break
                }
            }
            if !placed {
                ev.append(AdaptationEvent(kind: .alert, date: ctx.today, sessionID: missed.id,
                                          message: "Pas de créneau libre pour « \(missed.title) » : on la laisse filer plutôt que d'entasser."))
            }
        }
        return (out, ev)
    }

    // MARK: - Utilitaires

    /// Reconstruit une séance (id & date conservés) avec un nouveau sport/intention.
    private func rematerialize(_ s: PlannedSession, sport: Sport, intent: SessionIntent, ctx: AdaptationContext) -> PlannedSession {
        var new = generator.generate(sport: sport, intent: intent, phase: s.phase ?? .base,
                                     date: s.date, zones: ctx.zones, profile: ctx.profile, equipment: ctx.equipment)
        new.id = s.id
        return new
    }

    // MARK: - Détection des séances manquées (utilitaire pur)

    /// Compare les séances passées planifiées aux activités réalisées (même jour + même sport).
    public static func detectMissed(pastPlanned: [PlannedSession], completed: [CompletedActivity],
                                    calendar: Calendar = .init(identifier: .gregorian)) -> [PlannedSession] {
        pastPlanned.filter { planned in
            !completed.contains { act in
                act.sport == planned.sport && calendar.isDate(act.start, inSameDayAs: planned.date)
            }
        }
    }
}
