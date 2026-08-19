// Portage de App/Features/Health/InjuryCatalog.swift.
// Contenu pédagogique — ne remplace pas un avis médical.
import type { BodyZone } from '@engine/index';

export interface SpecificInjury {
  id: string;
  name: string;
  sensation: string;
}

export type RehabKind = 'stretch' | 'strength' | 'mobility' | 'care';
export const REHAB_LABEL: Record<RehabKind, string> = {
  stretch: 'Étirement', strength: 'Renforcement', mobility: 'Mobilité', care: 'Soin',
};

export interface RehabExercise {
  id: string;
  kind: RehabKind;
  name: string;
  howTo: string;
}

export const BODY_ZONES: { zone: BodyZone; label: string }[] = [
  { zone: 'shoulder', label: 'Épaule' },
  { zone: 'lowerBack', label: 'Bas du dos' },
  { zone: 'hip', label: 'Hanche' },
  { zone: 'hamstring', label: 'Ischios' },
  { zone: 'knee', label: 'Genou' },
  { zone: 'calf', label: 'Mollet' },
  { zone: 'ankle', label: 'Cheville' },
  { zone: 'foot', label: 'Pied' },
  { zone: 'other', label: 'Autre' },
];

export function specifics(zone: BodyZone): SpecificInjury[] {
  switch (zone) {
    case 'knee': return [
      { id: 'runners_knee', name: 'Syndrome rotulien (runner\'s knee)', sensation: 'Douleur sourde autour ou sous la rotule, aggravée en descente, en escaliers et en position assise prolongée.' },
      { id: 'jumpers_knee', name: 'Tendinite rotulienne (jumper\'s knee)', sensation: 'Douleur juste sous la rotule, à l\'impact, aux sauts et au démarrage de la course.' },
      { id: 'it_band', name: 'Syndrome de l\'essuie-glace (bandelette IT)', sensation: 'Douleur sur le côté externe du genou après quelques minutes de course, disparaît au repos.' },
      { id: 'meniscus', name: 'Gêne ménisque / ligament', sensation: 'Douleur profonde, parfois blocage ou instabilité — prudence, avis médical conseillé.' },
      { id: 'fatigue', name: 'Simple fatigue / tension', sensation: 'Gêne légère et diffuse, sans blocage, qui passe avec le repos.' },
    ];
    case 'ankle': return [
      { id: 'achilles', name: 'Tendinite d\'Achille', sensation: 'Douleur/raideur à l\'arrière du talon, raide au réveil, s\'échauffe puis revient après l\'effort.' },
      { id: 'sprain', name: 'Entorse (ligaments)', sensation: 'Douleur vive sur le côté suite à une torsion, souvent avec gonflement — repos.' },
      { id: 'malleolus', name: 'Douleur malléole', sensation: 'Point douloureux sur l\'os saillant de la cheville, sensible à la pression.' },
      { id: 'stress_fracture', name: 'Suspicion de fracture de fatigue', sensation: 'Douleur osseuse très localisée qui s\'aggrave à chaque appui — arrêt et avis médical.' },
      { id: 'fatigue', name: 'Simple fatigue', sensation: 'Gêne diffuse sans point précis, disparaît au repos.' },
    ];
    case 'foot': return [
      { id: 'plantar', name: 'Fasciite plantaire (aponévrosite)', sensation: 'Douleur sous le talon ou la voûte, très raide aux premiers pas du matin.' },
      { id: 'metatarsalgia', name: 'Métatarsalgie', sensation: 'Douleur à l\'avant-pied, à l\'appui, comme un caillou sous les orteils.' },
      { id: 'stress_fracture', name: 'Suspicion de fracture de fatigue', sensation: 'Douleur localisée sur le dessus du pied, croissante à l\'impact — avis médical.' },
      { id: 'fatigue', name: 'Simple fatigue', sensation: 'Lourdeur/gêne diffuse après une grosse charge.' },
    ];
    case 'calf': return [
      { id: 'strain', name: 'Élongation / déchirure du mollet', sensation: 'Douleur brutale à l\'arrière de la jambe, comme un coup de fouet, pendant un effort intense.' },
      { id: 'contracture', name: 'Contracture / crampe', sensation: 'Muscle dur et tendu, souvent en fin d\'effort, gêne à l\'étirement.' },
      { id: 'achilles_high', name: 'Tendinite (jonction Achille)', sensation: 'Douleur en bas du mollet vers le tendon, à l\'impulsion.' },
      { id: 'fatigue', name: 'Simple fatigue', sensation: 'Lourdeur diffuse qui passe au repos.' },
    ];
    case 'hamstring': return [
      { id: 'strain', name: 'Élongation / déchirure', sensation: 'Douleur brutale à l\'arrière de la cuisse pendant un sprint ou une accélération.' },
      { id: 'high_tendinopathy', name: 'Tendinopathie haute (insertion)', sensation: 'Douleur profonde en haut de la cuisse, gênante en position assise et à l\'accélération.' },
      { id: 'contracture', name: 'Contracture', sensation: 'Muscle dur, tension permanente, gêne à l\'étirement.' },
      { id: 'fatigue', name: 'Simple fatigue', sensation: 'Tension diffuse sans douleur vive.' },
    ];
    case 'hip': return [
      { id: 'glute_med', name: 'Tendinite moyen fessier', sensation: 'Douleur sur le côté de la hanche, sensible en position couchée sur le côté.' },
      { id: 'psoas', name: 'Fléchisseur / psoas', sensation: 'Douleur à l\'avant de la hanche/aine en levant la cuisse.' },
      { id: 'snapping', name: 'Ressaut de hanche', sensation: 'Claquement ou accrochage à certains mouvements, souvent indolore.' },
      { id: 'fatigue', name: 'Simple fatigue', sensation: 'Raideur diffuse après les longues sorties.' },
    ];
    case 'lowerBack': return [
      { id: 'mechanical', name: 'Lombalgie mécanique', sensation: 'Douleur basse et raideur, aggravée en position vélo prolongée ou en flexion.' },
      { id: 'sciatica', name: 'Douleur type sciatique', sensation: 'Douleur qui irradie dans la fesse et la jambe — avis médical conseillé.' },
      { id: 'contracture', name: 'Contracture / faux mouvement', sensation: 'Muscle bloqué d\'un côté, suite à un mouvement brusque.' },
      { id: 'fatigue', name: 'Fatigue posturale', sensation: 'Gêne après les longues sorties, passe au repos.' },
    ];
    case 'shoulder': return [
      { id: 'cuff', name: 'Tendinite de la coiffe des rotateurs', sensation: 'Douleur en levant le bras, gênante en natation (phase de traction).' },
      { id: 'impingement', name: 'Conflit sous-acromial', sensation: 'Pincement douloureux à l\'avant de l\'épaule en élévation.' },
      { id: 'instability', name: 'Instabilité', sensation: 'Sensation que l\'épaule « sort » ou se dérobe.' },
      { id: 'fatigue', name: 'Fatigue musculaire', sensation: 'Tension diffuse après une grosse charge de natation.' },
    ];
    default: return [
      { id: 'muscular', name: 'Douleur musculaire', sensation: 'Tension ou courbature localisée dans un muscle.' },
      { id: 'articular', name: 'Douleur articulaire', sensation: 'Gêne au niveau d\'une articulation, à certains mouvements.' },
      { id: 'other', name: 'Autre', sensation: 'Décris au mieux ta gêne ; en cas de doute, consulte.' },
    ];
  }
}

export function rehab(zone: BodyZone): RehabExercise[] {
  switch (zone) {
    case 'knee': return [
      { id: 'wallsit', kind: 'strength', name: 'Chaise contre le mur', howTo: 'Dos au mur, cuisses à ~90°. Tenir 30–45 s × 3. Renforce le quadriceps sans impact.' },
      { id: 'clamshell', kind: 'strength', name: 'Clam shell (moyen fessier)', howTo: 'Allongé sur le côté, genoux fléchis, ouvrir/fermer le genou du haut. 15 × 3 par côté.' },
      { id: 'it_stretch', kind: 'stretch', name: 'Étirement chaîne latérale / TFL', howTo: 'Debout, croiser la jambe douloureuse derrière, pencher le buste du côté opposé. 30 s × 3.' },
      { id: 'ankle_mob', kind: 'mobility', name: 'Mobilité cheville', howTo: 'Genou vers le mur, talon au sol, avancer progressivement. 10 × 2 par côté.' },
    ];
    case 'ankle':
    case 'calf': return [
      { id: 'eccentric_calf', kind: 'strength', name: 'Excentrique mollet (Alfredson)', howTo: 'Sur une marche, monter sur 2 pieds, redescendre lentement sur 1 pied. 15 × 3, matin et soir.' },
      { id: 'calf_stretch', kind: 'stretch', name: 'Étirement mollet', howTo: 'Face au mur, jambe arrière tendue, talon au sol. 30 s × 3.' },
      { id: 'ankle_mob', kind: 'mobility', name: 'Mobilité cheville', howTo: 'Genou vers le mur talon au sol, gagner en amplitude. 10 × 2.' },
      { id: 'foot_strength', kind: 'strength', name: 'Renforcement pied', howTo: 'Ramasser une serviette avec les orteils / marche sur pointes. 1–2 min.' },
    ];
    case 'foot': return [
      { id: 'plantar_roll', kind: 'care', name: 'Auto-massage voûte', howTo: 'Rouler une balle/bouteille froide sous le pied. 2–3 min, plusieurs fois par jour.' },
      { id: 'calf_stretch', kind: 'stretch', name: 'Étirement mollet + voûte', howTo: 'Étirement mollet mur, puis orteils relevés contre le mur. 30 s × 3.' },
      { id: 'foot_strength', kind: 'strength', name: 'Renforcement intrinsèques', howTo: '« Short foot » : creuser la voûte sans plier les orteils. 10 × 3.' },
      { id: 'eccentric_calf', kind: 'strength', name: 'Excentrique mollet', howTo: 'Descente lente sur la marche. 15 × 3.' },
    ];
    case 'hamstring': return [
      { id: 'nordic_light', kind: 'strength', name: 'Nordic curl (léger) / pont', howTo: 'Pont fessier une jambe, ou descente lente à genoux si indolore. 8–10 × 3.' },
      { id: 'ham_stretch', kind: 'stretch', name: 'Étirement ischios doux', howTo: 'Talon posé, dos droit, pencher depuis les hanches (sans douleur). 30 s × 3.' },
      { id: 'glute_bridge', kind: 'strength', name: 'Pont fessier', howTo: 'Sur le dos, monter le bassin. 15 × 3.' },
    ];
    case 'hip': return [
      { id: 'clamshell', kind: 'strength', name: 'Clam shell + abduction', howTo: 'Ouverture de hanche sur le côté, 15 × 3. Renforce le moyen fessier.' },
      { id: 'psoas_stretch', kind: 'stretch', name: 'Étirement psoas', howTo: 'Fente genou au sol, bascule du bassin vers l\'avant. 30 s × 3 par côté.' },
      { id: 'glute_bridge', kind: 'strength', name: 'Pont fessier', howTo: '15 × 3, en serrant les fessiers en haut.' },
    ];
    case 'lowerBack': return [
      { id: 'plank', kind: 'strength', name: 'Gainage (planche)', howTo: 'Planche ventrale et latérale, dos neutre. 20–40 s × 3.' },
      { id: 'cat_cow', kind: 'mobility', name: 'Chat-vache', howTo: 'À quatre pattes, arrondir puis creuser le dos en douceur. 10 × 2.' },
      { id: 'psoas_stretch', kind: 'stretch', name: 'Étirement psoas / fessiers', howTo: 'Fente + rotation du bassin. 30 s × 3.' },
      { id: 'bird_dog', kind: 'strength', name: 'Bird-dog', howTo: 'À quatre pattes, tendre bras + jambe opposés. 10 × 3, dos stable.' },
    ];
    case 'shoulder': return [
      { id: 'external_rot', kind: 'strength', name: 'Rotation externe (élastique)', howTo: 'Coude au corps, tirer l\'élastique vers l\'extérieur. 15 × 3. Renforce la coiffe.' },
      { id: 'scap_retraction', kind: 'strength', name: 'Rétraction scapulaire', howTo: 'Serrer les omoplates (rowing élastique léger). 15 × 3.' },
      { id: 'sleeper_stretch', kind: 'stretch', name: 'Étirement postérieur d\'épaule', howTo: 'Sur le côté, pousser doucement l\'avant-bras vers le sol. 30 s × 3.' },
      { id: 'cuff_care', kind: 'care', name: 'Réduire le volume nat.', howTo: 'Éviter les paddles, travailler les éducatifs et le gainage en attendant.' },
    ];
    default: return [
      { id: 'mobility', kind: 'mobility', name: 'Mobilité douce', howTo: 'Mobilise la zone en amplitude sans douleur, 5–10 min.' },
      { id: 'ice', kind: 'care', name: 'Glace si inflammation', howTo: '10–15 min sur la zone après l\'effort si chaud/gonflé.' },
    ];
  }
}
