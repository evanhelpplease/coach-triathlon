import Foundation

/// Une blessure/douleur précise, avec la description du ressenti.
struct SpecificInjury: Identifiable, Hashable {
    let id: String
    let name: String
    let sensation: String
}

/// Un exercice de rééducation / prévention.
struct RehabExercise: Identifiable, Hashable {
    enum Kind: String { case stretch = "Étirement", strength = "Renforcement", mobility = "Mobilité", care = "Soin" }
    let id: String
    let kind: Kind
    let name: String
    let howTo: String
}

/// Catalogue des douleurs précises et des protocoles de rééducation par zone.
/// Contenu pédagogique — ne remplace pas un avis médical.
enum InjuryCatalog {

    // MARK: Blessures précises par zone

    static func specifics(forZone raw: String) -> [SpecificInjury] {
        switch raw {
        case "knee": return [
            .init(id: "runners_knee", name: "Syndrome rotulien (runner's knee)",
                  sensation: "Douleur sourde autour ou sous la rotule, aggravée en descente, en escaliers et en position assise prolongée."),
            .init(id: "jumpers_knee", name: "Tendinite rotulienne (jumper's knee)",
                  sensation: "Douleur juste sous la rotule, à l'impact, aux sauts et au démarrage de la course."),
            .init(id: "it_band", name: "Syndrome de l'essuie-glace (bandelette IT)",
                  sensation: "Douleur sur le côté externe du genou qui apparaît après quelques minutes de course, disparaît au repos."),
            .init(id: "meniscus", name: "Gêne ménisque / ligament",
                  sensation: "Douleur profonde, parfois blocage ou sensation d'instabilité — prudence, avis médical conseillé."),
            .init(id: "fatigue", name: "Simple fatigue / tension",
                  sensation: "Gêne légère et diffuse, sans blocage, qui passe avec le repos.")
        ]
        case "ankle": return [
            .init(id: "achilles", name: "Tendinite d'Achille",
                  sensation: "Douleur/raideur à l'arrière du talon, raide au réveil, s'échauffe puis revient après l'effort."),
            .init(id: "sprain", name: "Entorse (ligaments)",
                  sensation: "Douleur vive sur le côté suite à une torsion, souvent avec gonflement — mise au repos."),
            .init(id: "malleolus", name: "Douleur malléole",
                  sensation: "Point douloureux sur l'os saillant de la cheville, sensible à la pression."),
            .init(id: "stress_fracture", name: "Suspicion de fracture de fatigue",
                  sensation: "Douleur osseuse très localisée qui s'aggrave à chaque appui/impact — arrêt et avis médical."),
            .init(id: "fatigue", name: "Simple fatigue",
                  sensation: "Gêne diffuse sans point précis, disparaît au repos.")
        ]
        case "foot": return [
            .init(id: "plantar", name: "Fasciite plantaire (aponévrosite)",
                  sensation: "Douleur sous le talon ou la voûte, très raide aux premiers pas du matin."),
            .init(id: "metatarsalgia", name: "Métatarsalgie",
                  sensation: "Douleur à l'avant-pied, à l'appui, comme un caillou sous les orteils."),
            .init(id: "stress_fracture", name: "Suspicion de fracture de fatigue",
                  sensation: "Douleur localisée sur le dessus du pied, croissante à l'impact — avis médical."),
            .init(id: "fatigue", name: "Simple fatigue",
                  sensation: "Lourdeur/gêne diffuse après une grosse charge.")
        ]
        case "calf": return [
            .init(id: "strain", name: "Élongation / déchirure du mollet",
                  sensation: "Douleur brutale à l'arrière de la jambe, comme un coup de fouet, pendant un effort intense."),
            .init(id: "contracture", name: "Contracture / crampe",
                  sensation: "Muscle dur et tendu, souvent en fin d'effort, gêne à l'étirement."),
            .init(id: "achilles_high", name: "Tendinite (jonction Achille)",
                  sensation: "Douleur en bas du mollet vers le tendon, à l'impulsion."),
            .init(id: "fatigue", name: "Simple fatigue",
                  sensation: "Lourdeur diffuse qui passe au repos.")
        ]
        case "hamstring": return [
            .init(id: "strain", name: "Élongation / déchirure",
                  sensation: "Douleur brutale à l'arrière de la cuisse pendant un sprint ou une accélération."),
            .init(id: "high_tendinopathy", name: "Tendinopathie haute (insertion)",
                  sensation: "Douleur profonde en haut de la cuisse, gênante en position assise et à l'accélération."),
            .init(id: "contracture", name: "Contracture",
                  sensation: "Muscle dur, tension permanente, gêne à l'étirement."),
            .init(id: "fatigue", name: "Simple fatigue",
                  sensation: "Tension diffuse sans douleur vive.")
        ]
        case "hip": return [
            .init(id: "glute_med", name: "Tendinite moyen fessier",
                  sensation: "Douleur sur le côté de la hanche, sensible en position couchée sur le côté."),
            .init(id: "psoas", name: "Fléchisseur / psoas",
                  sensation: "Douleur à l'avant de la hanche/aine en levant la cuisse."),
            .init(id: "snapping", name: "Ressaut de hanche",
                  sensation: "Claquement ou accrochage à certains mouvements, souvent indolore."),
            .init(id: "fatigue", name: "Simple fatigue",
                  sensation: "Raideur diffuse après les longues sorties.")
        ]
        case "lowerBack": return [
            .init(id: "mechanical", name: "Lombalgie mécanique",
                  sensation: "Douleur basse et raideur, aggravée en position vélo prolongée ou en flexion."),
            .init(id: "sciatica", name: "Douleur type sciatique",
                  sensation: "Douleur qui irradie dans la fesse et la jambe — avis médical conseillé."),
            .init(id: "contracture", name: "Contracture / faux mouvement",
                  sensation: "Muscle bloqué d'un côté, suite à un mouvement brusque."),
            .init(id: "fatigue", name: "Fatigue posturale",
                  sensation: "Gêne après les longues sorties, passe au repos.")
        ]
        case "shoulder": return [
            .init(id: "cuff", name: "Tendinite de la coiffe des rotateurs",
                  sensation: "Douleur en levant le bras, gênante en natation (phase de traction)."),
            .init(id: "impingement", name: "Conflit sous-acromial",
                  sensation: "Pincement douloureux à l'avant de l'épaule en élévation."),
            .init(id: "instability", name: "Instabilité",
                  sensation: "Sensation que l'épaule 'sort' ou se dérobe."),
            .init(id: "fatigue", name: "Fatigue musculaire",
                  sensation: "Tension diffuse après une grosse charge de natation.")
        ]
        default: return [
            .init(id: "muscular", name: "Douleur musculaire",
                  sensation: "Tension ou courbature localisée dans un muscle."),
            .init(id: "articular", name: "Douleur articulaire",
                  sensation: "Gêne au niveau d'une articulation, à certains mouvements."),
            .init(id: "other", name: "Autre",
                  sensation: "Décris au mieux ta gêne ; en cas de doute, consulte.")
        ]
        }
    }

    // MARK: Rééducation / prévention par zone

    static func rehab(forZone raw: String) -> [RehabExercise] {
        switch raw {
        case "knee": return [
            .init(id: "wallsit", kind: .strength, name: "Chaise contre le mur",
                  howTo: "Dos au mur, cuisses à ~90°. Tenir 30–45 s × 3. Renforce le quadriceps sans impact."),
            .init(id: "clamshell", kind: .strength, name: "Clam shell (moyen fessier)",
                  howTo: "Allongé sur le côté, genoux fléchis, ouvrir/fermer le genou du haut. 15 × 3 par côté."),
            .init(id: "it_stretch", kind: .stretch, name: "Étirement chaîne latérale / TFL",
                  howTo: "Debout, croiser la jambe douloureuse derrière, pencher le buste du côté opposé. 30 s × 3."),
            .init(id: "ankle_mob", kind: .mobility, name: "Mobilité cheville",
                  howTo: "Genou vers le mur, talon au sol, avancer progressivement. 10 × 2 par côté.")
        ]
        case "ankle", "calf": return [
            .init(id: "eccentric_calf", kind: .strength, name: "Excentrique mollet (Alfredson)",
                  howTo: "Sur une marche, monter sur 2 pieds, redescendre lentement sur 1 pied. 15 × 3, matin et soir."),
            .init(id: "calf_stretch", kind: .stretch, name: "Étirement mollet",
                  howTo: "Face au mur, jambe arrière tendue, talon au sol. 30 s × 3 (gastrocnémien et soléaire)."),
            .init(id: "ankle_mob", kind: .mobility, name: "Mobilité cheville",
                  howTo: "Genou vers le mur talon au sol, gagner en amplitude. 10 × 2."),
            .init(id: "foot_strength", kind: .strength, name: "Renforcement pied",
                  howTo: "Ramasser une serviette avec les orteils / marche sur pointes. 1–2 min.")
        ]
        case "foot": return [
            .init(id: "plantar_roll", kind: .care, name: "Auto-massage voûte",
                  howTo: "Rouler une balle/bouteille froide sous le pied. 2–3 min, plusieurs fois par jour."),
            .init(id: "calf_stretch", kind: .stretch, name: "Étirement mollet + voûte",
                  howTo: "Étirement mollet mur, puis orteils relevés contre le mur. 30 s × 3."),
            .init(id: "foot_strength", kind: .strength, name: "Renforcement intrinsèques",
                  howTo: "« Short foot » : creuser la voûte sans plier les orteils. 10 × 3."),
            .init(id: "eccentric_calf", kind: .strength, name: "Excentrique mollet",
                  howTo: "Descente lente sur la marche. 15 × 3.")
        ]
        case "hamstring": return [
            .init(id: "nordic_light", kind: .strength, name: "Nordic curl (léger) / pont",
                  howTo: "Pont fessier une jambe, ou descente lente à genoux si indolore. 8–10 × 3."),
            .init(id: "ham_stretch", kind: .stretch, name: "Étirement ischios doux",
                  howTo: "Talon posé, dos droit, pencher depuis les hanches (sans douleur). 30 s × 3."),
            .init(id: "glute_bridge", kind: .strength, name: "Pont fessier",
                  howTo: "Sur le dos, monter le bassin. 15 × 3.")
        ]
        case "hip": return [
            .init(id: "clamshell", kind: .strength, name: "Clam shell + abduction",
                  howTo: "Ouverture de hanche sur le côté, 15 × 3. Renforce le moyen fessier."),
            .init(id: "psoas_stretch", kind: .stretch, name: "Étirement psoas",
                  howTo: "Fente genou au sol, bascule du bassin vers l'avant. 30 s × 3 par côté."),
            .init(id: "glute_bridge", kind: .strength, name: "Pont fessier",
                  howTo: "15 × 3, en serrant les fessiers en haut.")
        ]
        case "lowerBack": return [
            .init(id: "plank", kind: .strength, name: "Gainage (planche)",
                  howTo: "Planche ventrale et latérale, dos neutre. 20–40 s × 3."),
            .init(id: "cat_cow", kind: .mobility, name: "Chat-vache",
                  howTo: "À quatre pattes, arrondir puis creuser le dos en douceur. 10 × 2."),
            .init(id: "psoas_stretch", kind: .stretch, name: "Étirement psoas / fessiers",
                  howTo: "Fente + rotation du bassin. 30 s × 3."),
            .init(id: "bird_dog", kind: .strength, name: "Bird-dog",
                  howTo: "À quatre pattes, tendre bras + jambe opposés. 10 × 3, dos stable.")
        ]
        case "shoulder": return [
            .init(id: "external_rot", kind: .strength, name: "Rotation externe (élastique)",
                  howTo: "Coude au corps, tirer l'élastique vers l'extérieur. 15 × 3. Renforce la coiffe."),
            .init(id: "scap_retraction", kind: .strength, name: "Rétraction scapulaire",
                  howTo: "Serrer les omoplates (rowing élastique léger). 15 × 3."),
            .init(id: "sleeper_stretch", kind: .stretch, name: "Étirement postérieur d'épaule",
                  howTo: "Sur le côté, pousser doucement l'avant-bras vers le sol. 30 s × 3."),
            .init(id: "cuff_care", kind: .care, name: "Réduire le volume nat.",
                  howTo: "Éviter les paddles, travailler les éducatifs et le gainage en attendant.")
        ]
        default: return [
            .init(id: "mobility", kind: .mobility, name: "Mobilité douce",
                  howTo: "Mobilise la zone en amplitude sans douleur, 5–10 min."),
            .init(id: "ice", kind: .care, name: "Glace si inflammation",
                  howTo: "10–15 min sur la zone après l'effort si chaud/gonflé.")
        ]
        }
    }
}
