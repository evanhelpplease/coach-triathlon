import Foundation

/// Convertit une séance quand le matériel requis n'est pas disponible, en
/// préservant la logique de charge de la semaine (équivalence, pas suppression).
public struct EquipmentSubstitution: Sendable {
    public init() {}

    public struct Result: Sendable, Equatable {
        public var session: PlannedSession
        public var changed: Bool
        public var explanation: String
    }

    /// Facteur de conversion de charge d'un sport source vers un sport cible.
    /// (À charge égale, on ajuste la durée : la course "coûte" plus au kg.)
    static func loadKept(from: Sport, to: Sport) -> Double {
        switch (from, to) {
        case (.bike, .run): return 0.85      // on convertit à ~85 % de la charge vélo
        case (.swim, .strength): return 0.6  // travail à sec : charge moindre
        case (.run, .bike): return 1.0
        default: return 0.8
        }
    }

    public func substitute(_ session: PlannedSession, equipment: Equipment) -> Result {
        // Le sport est praticable → aucune substitution.
        if equipment.canPractice(session.sport) {
            return Result(session: session, changed: false, explanation: "")
        }

        switch session.sport {
        case .bike:
            if equipment.canPractice(.run) {
                return convert(session, to: .run,
                               explanation: "Pas de vélo : converti en course d'intensité équivalente. On rebascule dès que le vélo revient.")
            }
            return convert(session, to: .strength,
                           explanation: "Pas de vélo ni de course : maintien via PPG spécifique vélo (gainage, chaîne postérieure).")

        case .swim:
            let via: Sport = equipment.hasDrylandCords ? .strength : .strength
            let why = equipment.hasDrylandCords
                ? "Pas d'accès à l'eau : traction élastique à sec + mobilité épaules, technique conservée."
                : "Pas d'accès à l'eau : renforcement spécifique nage + mobilité épaules à la place."
            return convert(session, to: via, explanation: why)

        case .run:
            if equipment.hasTreadmill {
                var s = session
                s.notes = "Sur tapis : \(s.notes)"
                return Result(session: s, changed: true, explanation: "Course déplacée sur tapis.")
            }
            if equipment.canPractice(.bike) {
                return convert(session, to: .bike,
                               explanation: "Course indisponible : converti en vélo d'intensité équivalente (préserve les articulations).")
            }
            return convert(session, to: .strength, explanation: "Ni course ni vélo : renforcement + mobilité.")

        case .brick:
            if equipment.canPractice(.run) {
                return convert(session, to: .run, explanation: "Brick impossible sans vélo : séance course seule d'intensité proche.")
            }
            return convert(session, to: .strength, explanation: "Brick impossible : renforcement de substitution.")

        case .strength:
            return Result(session: session, changed: false, explanation: "")
        }
    }

    private func convert(_ session: PlannedSession, to target: Sport, explanation: String) -> Result {
        let kept = Self.loadKept(from: session.sport, to: target)
        var s = session
        s.sport = target
        s.estimatedLoad = (session.estimatedLoad * kept).rounded()
        s.estimatedDuration = session.estimatedDuration * kept
        s.title = "\(sportLabel(target)) · remplace \(sportLabel(session.sport).lowercased())"
        s.notes = explanation
        // Les pas d'origine ne sont plus valides pour le nouveau sport : on marque
        // la séance comme "à matérialiser" par le générateur au moment de l'exécution.
        s.steps = []
        return Result(session: s, changed: true, explanation: explanation)
    }

    private func sportLabel(_ s: Sport) -> String {
        switch s {
        case .swim: return "Natation"; case .bike: return "Vélo"; case .run: return "Course"
        case .strength: return "Renforcement"; case .brick: return "Brick"
        }
    }
}
