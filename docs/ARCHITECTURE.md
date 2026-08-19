# Coach Triathlon IA — Architecture & Plan de développement

> Document de référence. Version 1.0 — 2026-08-04
> Cible : iOS 17+, Swift 6, SwiftUI. Langue de l'app : français. Unités : métriques.

## Sommaire

1. [Principes directeurs](#1-principes-directeurs)
2. [Vue modules & workspace](#2-vue-modules--workspace)
3. [Modèle de données](#3-modèle-de-données)
4. [Le moteur d'entraînement (cœur)](#4-le-moteur-dentraînement-cœur)
5. [Couche DataProvider & synchronisations](#5-couche-dataprovider--synchronisations)
6. [Intégrations externes](#6-intégrations-externes)
7. [Couche IA (Claude, optionnelle)](#7-couche-ia-claude-optionnelle)
8. [Design system](#8-design-system)
9. [Plan de développement par phases](#9-plan-de-développement-par-phases)
10. [Prérequis externes & entitlements](#10-prérequis-externes--entitlements)
11. [Stratégie de tests](#11-stratégie-de-tests)
12. [Guide de mise en route](#12-guide-de-mise-en-route)
13. [Évolutions futures](#13-évolutions-futures)

---

## 1. Principes directeurs

1. **Le moteur est un package pur, sans UI ni I/O.** `TriathlonEngine` ne dépend ni de SwiftUI, ni de HealthKit, ni du réseau. Il prend des entrées (profil, historique, données de récup, matériel dispo) et produit des sorties (plan, séances, zones, prédictions). Conséquence : il est **testable via `swift test` sans Xcode**, déterministe, et réutilisable (widget, extension, serveur).
2. **Hors-ligne par défaut.** Toute la logique d'entraînement tourne en local par règles. Le réseau (Claude, Google Calendar) est un *enrichissement*, jamais un prérequis.
3. **Sources de données interchangeables et cumulables.** Un protocole `HealthDataProvider` abstrait Apple Health / Garmin / saisie manuelle. En Phase 1, Garmin arrive *gratuitement* via Apple Health (l'app Garmin Connect y écrit déjà).
4. **Adaptation, pas prescription figée.** Le plan est un objet vivant recalculé à chaque événement (séance réalisée, check-in, blessure, indispo matériel).
5. **Bienveillance et transparence.** Ton de coach expert non culpabilisant. Chaque ajustement automatique est expliqué. Rappel médical systématique. RGPD : données santé traitées localement au maximum.

---

## 2. Vue modules & workspace

```
CoachTriathlon.xcworkspace
├── Packages/
│   ├── TriathlonEngine/                 # Swift pur — 0 dépendance UI/IO — testable sans Xcode
│   │   ├── Sources/TriathlonEngine/
│   │   │   ├── Domain/                   # value types immuables
│   │   │   ├── Zones/                    # calcul & recalibrage des zones
│   │   │   ├── Periodization/            # macro/méso/micro-cycles
│   │   │   ├── SessionGeneration/        # séances structurées par sport
│   │   │   ├── Load/                     # CTL/ATL/TSB, ACWR, TSS-like
│   │   │   ├── Adaptation/               # règles d'ajustement quotidien
│   │   │   ├── Equipment/                # substitution matériel
│   │   │   ├── Predictions/              # Riegel, VDOT, CSS, puissance
│   │   │   └── Injury/                   # règles d'adaptation blessure
│   │   └── Tests/TriathlonEngineTests/
│   └── DesignSystem/                     # SwiftUI — couleurs, type, composants, haptics
│
└── App/  (CoachTriathlon — cible iOS)
    ├── Features/                         # MVVM par écran
    │   ├── Onboarding/
    │   ├── Cockpit/                      # écran d'accueil "cockpit du jour"
    │   ├── PlanCalendar/
    │   ├── SessionDetail/
    │   ├── Analysis/
    │   ├── Injury/
    │   ├── Chat/                         # assistant Claude
    │   └── Profile/
    ├── Persistence/                      # SwiftData @Model + mappers ⇄ Domain
    ├── Providers/                        # HealthDataProvider & impls
    ├── Integrations/                     # HealthKit, WorkoutKit, GoogleCalendar, FIT/ZWO
    ├── AI/                               # AnthropicClient + PromptBuilder + fallback
    ├── Notifications/                    # local + (push plus tard)
    ├── Background/                       # BGTaskScheduler
    └── App.swift
```

**Pourquoi MVVM et pas TCA** : l'énoncé demande de justifier. Le moteur étant déjà un package pur et déterministe (là où TCA apporte le plus), la valeur ajoutée de TCA côté UI ne justifie pas son boilerplate et sa courbe pour un projet mené en solo. MVVM + `@Observable` (Observation framework iOS 17) + SwiftData couvre le besoin avec zéro dépendance externe et une meilleure vélocité. On garde la testabilité là où elle compte : dans le moteur.

---

## 3. Modèle de données

Deux couches distinctes, reliées par des *mappers* :

- **Domain (dans le package)** : `struct` immuables, `Codable`, `Sendable`. Aucune notion de persistance. C'est le vocabulaire du moteur.
- **Persistance (dans l'app)** : classes `@Model` SwiftData, avec `CloudKit` pour la sync iCloud.

### 3.1 Types Domain (extraits)

```swift
enum Sport: String, Codable, Sendable { case swim, bike, run, strength, brick }

enum Discipline: Sendable {            // granularité fine pour zones/prédictions
    case swim, bike, run
}

struct AthleteProfile: Codable, Sendable {
    var birthDate: Date
    var sex: BiologicalSex
    var heightCm: Double
    var weightKg: Double
    var hrMax: Int?                     // mesurée ou estimée (voir Zones)
    var hrRest: Int?
    var ftpWatts: Int?                  // vélo
    var cssPer100m: TimeInterval?       // Critical Swim Speed (natation)
    var vdot: Double?                   // Daniels (course)
    var levels: [Discipline: SkillLevel]
    var injuryHistory: [InjuryRecord]
}

struct Equipment: Codable, Sendable {  // état à un instant T
    var hasBike: Bool
    var bikeType: BikeType?            // road, tt, gravel, mtb, trainer
    var bikeWeightKg: Double?
    var hasAeroBars: Bool
    var hasPowerMeter: Bool
    var hasSmartTrainer: Bool
    var poolAccess: PoolAccess?       // jours/créneaux
    var openWaterAccess: Bool
    var hasWetsuit: Bool
    var hasDrylandCords: Bool
    var runOutdoor: Bool
    var hasTreadmill: Bool
    var hasTrack: Bool
    var strengthAccess: StrengthAccess // gym, homeWeights, bodyweightOnly, none
}

struct Race: Codable, Sendable {
    var id: UUID
    var date: Date
    var format: RaceFormat            // xs, sprint, olympic, half, full, run10k, halfM, marathon, ...
    var priority: RacePriority        // A, B, C
    var title: String
}

struct TrainingZones: Codable, Sendable {
    var hr: [ZoneBoundary]            // 5 zones FC
    var runPace: [ZoneBoundary]       // s/km
    var swimPace: [ZoneBoundary]      // s/100m
    var power: [ZoneBoundary]         // W (Coggan 7 zones)
    var updatedAt: Date
    var source: ZoneSource            // test, estimated, autoRecalibrated
}

struct PlannedSession: Codable, Sendable {
    var id: UUID
    var date: Date
    var sport: Sport
    var intent: SessionIntent         // recovery, endurance, tempo, threshold, vo2, sprint, technique, brick, strength
    var steps: [WorkoutStep]          // WU / intervalles / CD, avec cibles
    var estimatedLoad: Double         // charge (TSS-like)
    var estimatedDuration: TimeInterval
    var notes: String                 // consignes techniques / éducatifs
    var equipmentRequired: Set<EquipmentNeed>
}

struct WorkoutStep: Codable, Sendable {
    var kind: StepKind                // warmup, work, recovery, rest, cooldown, repeatBlock
    var duration: StepDuration        // time | distance | lengths(pool)
    var target: StepTarget            // hrZone | paceRange | powerRange | rpe | free
    var cue: String?                  // "cadence 90+", "position aéro", "éducatif rattrapé"
    var repeats: Int?                 // pour repeatBlock
    var children: [WorkoutStep]?
}

struct CompletedActivity: Codable, Sendable {  // importée depuis HealthKit/Garmin/manuel
    var id: UUID
    var sport: Sport
    var start: Date
    var duration: TimeInterval
    var distanceM: Double?
    var avgHr: Int?; var maxHr: Int?
    var avgPowerW: Int?; var normalizedPowerW: Int?
    var avgPaceSecPerKm: Double?
    var hrDriftPct: Double?           // dérive cardiaque calculée
    var poolLengths: Int?
    var rpe: Int?                     // saisi post-séance
    var source: DataSource
}

struct DailyReadiness: Codable, Sendable {
    var date: Date
    var sleepHours: Double?
    var hrRest: Int?
    var hrvMs: Double?                // rMSSD / SDNN
    var bodyBattery: Int?            // si Garmin via Health
    var subjective: SubjectiveCheckin? // forme, sommeil ressenti, courbatures, motivation (1–5)
}
```

### 3.2 SwiftData (@Model) + sync iCloud

Chaque type persistant a un `@Model` miroir + un mapper `toDomain()/init(from:)`. On persiste : `ProfileModel`, `EquipmentSnapshotModel` (historisé — le matériel change dans le temps), `RaceModel`, `PlanModel`→`PlannedSessionModel`, `CompletedActivityModel`, `DailyReadinessModel`, `InjuryRecordModel`, `ZonesSnapshotModel`, `ChatMessageModel`.

- Container : `ModelConfiguration(cloudKitDatabase: .private)` → sync iCloud transparente.
- Les données santé brutes ne sont **pas** dupliquées dans iCloud au-delà du nécessaire ; on stocke les activités agrégées, pas les séries GPS complètes (RGPD + poids).
- Historisation du matériel et des zones → indispensable pour ré-analyser le passé avec les bons référentiels.

---

## 4. Le moteur d'entraînement (cœur)

Pipeline principal, tout en fonctions pures :

```
PlanRequest { profile, equipment, races[], availability, history[], readiness[], constraints[] }
      │
      ▼
[1] ZoneCalculator      → TrainingZones
[2] Periodizer          → [Mesocycle] → [Microcycle] (semaines)
[3] SessionGenerator    → [PlannedSession] pour chaque microcycle
[4] LoadModel           → CTL/ATL/TSB, ACWR, charge prévue vs cible
[5] Adapter             → applique les règles (récup, manqué, matériel, blessure)
      │
      ▼
TrainingPlan { sessions[], rationale[], warnings[] }
```

### 4.1 Calcul des zones (`ZoneCalculator`)

**FC** — si `hrMax` et `hrRest` connues → **Karvonen** (réserve de FC) :
`FC_cible = hrRest + %×(hrMax − hrRest)`. Zones : Z1 <68%, Z2 68–83%, Z3 83–90%, Z4 90–98%, Z5 >98% de la réserve (paramétrable). Si `hrMax` inconnue → estimation `211 − 0.64×âge` (Nes), signalée comme `estimated` et invitation à faire un test.

**Course (allures)** — via **VDOT (Daniels)**. À partir d'une perf récente (ex. 5 km en 22:00), on calcule VDOT puis les allures E/M/T/I/R. Formules Daniels :
- VO2 d'une course : `VO2 = -4.60 + 0.182258·v + 0.000104·v²` (v en m/min)
- % VO2max soutenu selon durée t (min) : `%max = 0.8 + 0.1894393·e^(-0.012778·t) + 0.2989558·e^(-0.1932605·t)`
- On résout pour trouver le VDOT, puis on redescend pour les allures cibles de chaque zone.

**Natation** — **CSS** (Critical Swim Speed) à partir de deux tests (400 m et 200 m) :
`CSS (s/m) = (D400 − D200) / (T400 − T200)`. Allures d'entraînement dérivées en % de CSS (EN, seuil, VO2). Défaut si un seul test connu : estimation + flag.

**Puissance vélo** — 7 zones **Coggan** en % de FTP : Z1 <55, Z2 55–75, Z3 76–90, Z4 91–105, Z5 106–120, Z6 121–150, Z7 >150 %.

**Recalibrage auto** : après chaque séance clé ou test, si la performance réalisée implique un meilleur référentiel (nouvelle meilleure allure au seuil tenue X min, nouvelle puissance record 20 min → FTP = 95 % × P20…), on met à jour les zones et on journalise un `ZonesSnapshot` daté avec la raison.

### 4.2 Périodisation (`Periodizer`)

Entrée : dates des courses A/B/C + volume/dispos. Sortie : macrocycle → mésocycles → microcycles.

- **Rétro-planification** depuis chaque course A : `Affûtage (1–3 sem) ← Spécifique ← Build ← Base`, avec **semaine de décharge** toutes les 3–4 semaines (charge −40 %).
- **Modèle de charge polarisé 80/20** : ~80 % du volume en Z1–Z2, ~20 % en Z3–Z5, réparti par sport selon niveau et limitant (discipline faible priorisée en base).
- **Progression de charge bornée par l'ACWR** : la charge hebdo cible respecte un ratio aigu/chronique dans la fenêtre 0.8–1.3 (sweet spot ~1.0–1.1). Jamais de saut >~10 %/sem hors reprise.
- **Multi-courses** : les courses B/C deviennent des séances "test/prépa" intégrées sans casser la préparation de la course A ; conflit de pics géré par priorité.
- **Sans objectif** : cycles de progression continue base→build→décharge en boucle, focalisés sur le point faible.

Sortie annotée : chaque semaine porte sa `phase`, sa `chargeCible`, et un `rationale` court affichable.

### 4.3 Génération de séances (`SessionGenerator`)

Pour chaque créneau du microcycle, on choisit une `SessionIntent` selon la phase et la répartition polarisée, puis on **matérialise des `WorkoutStep`** avec cibles issues des zones :

- Échauffement progressif + éducatifs (natation : rattrapé, poings fermés, jambes ; course : gammes ; vélo : montées de cadence).
- Corps de séance : intervalles précis (ex. `8×400 m @ allure I, récup 200 m`, `4×8 min @ Z4 puissance, récup 4 min Z1`).
- Retour au calme + consignes techniques (cadence cible, position aéro si prolongateurs, technique de virage natation).
- **Séances brick** (enchaînement vélo→course) placées en build/spécifique, avec cible de "negative split" course.
- Chaque séance porte `equipmentRequired` → base de la substitution matériel.

### 4.4 Modèle de charge (`LoadModel`)

- **Charge par séance** (TSS-like) : vélo via puissance (`TSS = (s·NP·IF)/(FTP·36)`), course via allure/GAP + FC (rTSS/hrTSS), natation via CSS (sTSS). Fallback FC (TRIMP de Banister) si pas de puissance/allure fiable.
- **CTL** (fitness) = moyenne exponentielle 42 j ; **ATL** (fatigue) = 7 j ; **TSB** (forme) = CTL − ATL.
- **ACWR** = charge aiguë 7 j / charge chronique 28 j → garde-fou anti-blessure.
- Ces indicateurs alimentent l'affûtage (viser TSB > +5 à J-course) et les alertes.

### 4.5 Adaptation quotidienne (`Adapter`) — moteur de règles

Règles ordonnées, chacune : `condition → transformation + rationale`. Exemples (extrait) :

| Déclencheur | Action | Explication utilisateur |
|---|---|---|
| HRV ↓ >1 écart-type + sommeil <6 h + courbatures élevées | Séance du jour → récup active ou repos | "Ta récupération est basse, on allège aujourd'hui pour progresser demain." |
| Séance clé manquée | Re-planif sur créneau libre proche, sans dépasser ACWR 1.3 | "Séance décalée à jeudi, sans surcharger ta semaine." |
| ACWR > 1.5 sur 7 j | Décharge anticipée −30 % | Alerte surcharge + pédagogie |
| TSB < −25 persistant | Micro-décharge + priorité sommeil | Détection sous-récupération |
| Réalisé > prévu (dérive cardiaque ↓, allure seuil ↑) | Recalibrage zones + note positive | Analyse post-séance |
| Météo défavorable extérieur | Propose home trainer / tapis équivalent | Adaptation contextuelle |

Le résultat est toujours un **nouveau plan** + une liste d'`AdaptationEvent` traçables (affichés et annulables).

### 4.6 Substitution matériel (`EquipmentSubstitution`)

Fonction pure `substitute(session, available: Equipment) -> PlannedSession`. Table d'équivalences de charge :

- Pas de vélo → séance de charge équivalente en course (facteur de conversion charge) + PPG spécifique vélo (gainage, chaîne postérieure) + travail de cadence à sec si home trainer absent.
- Pas de piscine → traction élastique à sec + technique + mobilité épaules ; report du volume aquatique sur les sports dispo (bornage ACWR).
- Déplacement "juste des baskets" → conversion des séances week-end en équivalent course/PPG sans casser la logique hebdo.
- Prolongateurs/capteur de puissance présents → séances puissance structurées + travail position aéro ; sinon pilotage à la FC/RPE.
- **Indisponibilité temporaire par sport** (dates) déclarable depuis le calendrier → le moteur re-répartit et rebascule automatiquement au retour du matériel.

### 4.7 Prédictions (`Predictions`)

- **Course** : **Riegel** `T2 = T1·(D2/D1)^1.06` pour extrapoler entre distances, croisé avec **VDOT** pour cohérence physiologique. Sorties : 5 k, 10 k, semi, marathon.
- **Natation** : **CSS** → temps 400 m / 1500 m (+ correction eau libre/combinaison).
- **Vélo** : modèle puissance/vitesse (FTP + CdA estimé selon position route vs CLM+prolongateurs + poids système) → 20 / 40 / 90 km.
- **Triathlon assemblé** : somme des disciplines aux allures cibles *durables* pour le format (pas au max mono-sport) + **T1/T2** estimées, décote de la course selon la fatigue vélo. Sortie décomposée par discipline + transitions, avec **intervalle de confiance** (fonction de la quantité/qualité de données) et **courbe d'évolution** dans le temps.

Toutes ces fonctions sont **prioritaires en tests unitaires** (valeurs de référence connues de la littérature).

---

## 5. Couche DataProvider & synchronisations

```swift
protocol HealthDataProvider: Sendable {
    var id: ProviderID { get }
    func authorize() async throws
    func importActivities(since: Date) async throws -> [CompletedActivity]
    func importReadiness(since: Date) async throws -> [DailyReadiness]
    func writeWorkout(_ planned: PlannedSession) async throws   // écriture Health
    var capabilities: ProviderCapabilities { get }
}
```

- Implémentations : `AppleHealthProvider` (Phase 1), `ManualProvider` (Phase 1), `GarminConnectProvider` (Phase 3, mock d'abord).
- **Agrégation cumulative** : un `ProviderCoordinator` fusionne les sources, déduplique (fenêtre temporelle + source d'origine) et priorise la source la plus riche par métrique (ex. puissance Garmin > estimation Apple).
- **Sync en arrière-plan** : `BGAppRefreshTask` + `BGProcessingTask` déclenchent l'import + le re-calcul du plan + la mise à jour des workouts/agenda/notifs.

Flux de sync :

1. **Vers la montre** — Phase 1 : export `.FIT`/`.ZWO` de la séance (import manuel dans Garmin/Zwift). Phase 3 : push direct via Garmin Workouts API ou `WorkoutKit` (Apple Watch). Toute modif du plan régénère le workout.
2. **Vers Google Agenda** — chaque séance = événement (titre, durée, description détaillée). Modif/annulation/re-planif → update de l'event (idempotent via `extendedProperties` portant l'`id` de séance). Gestion fuseaux horaires (IANA) et conflits.
3. **Depuis la montre/Health** — import auto activités + sommeil + FC repos + HRV + poids, en arrière-plan.

---

## 6. Intégrations externes

- **HealthKit** : lecture (workouts, `heartRate`, `hrv SDNN`, `restingHR`, `sleepAnalysis`, `bodyMass`, distances, puissance cycliste/course, longueurs piscine) + écriture (`HKWorkout`). Entitlement HealthKit requis.
- **WorkoutKit** (Phase 3) : `WorkoutPlan` structuré poussé vers Apple Watch.
- **Google Calendar** : OAuth 2.0 (projet Google Cloud gratuit), scope `calendar.events`. Mode **mock** fourni pour tester sans compte.
- **Export FIT/ZWO** : générateurs de fichiers pour import manuel (Phase 1) — `.ZWO` (Zwift, XML lisible) prioritaire car trivial ; `.FIT` via encodeur binaire.
- **Météo** : API gratuite (ex. Open-Meteo, sans clé) pour la suggestion extérieur↔indoor.

Chaque client externe : **protocole + implémentation réelle + implémentation mock/démo**, injectés par un conteneur de dépendances simple.

---

## 7. Couche IA (Claude, optionnelle)

- `AnthropicClient` derrière un protocole `AICoach`. Par défaut : `RuleBasedCoach` (local, hors-ligne) qui répond aux intentions courantes ("décale ma séance de jeudi", résumés post-séance) via le moteur.
- Quand une clé API est configurée : `ClaudeCoach` enrichit — génération/adaptation de plans en langage naturel, analyses rédigées, conseils nutrition/récup — avec **fallback automatique** vers `RuleBasedCoach` si hors-ligne ou erreur.
- `PromptBuilder` sérialise l'état (profil, zones, charge, plan, dernières séances) en contexte compact. Aucune donnée santé n'est envoyée sans consentement explicite ; opt-in clair, désactivable.
- Modèle par défaut recommandé : dernier Claude disponible (config `claude-*`), paramétrable.

---

## 8. Design system

Package `DesignSystem` : tokens (couleurs, typo, espacements, rayons), composants (`StatTile`, `SessionCard`, `ZoneBar`, `RingGauge`, `Countdown`), haptics, motion.

- **Identité** : palette inspirée triathlon — eau (bleu profond), route (graphite/asphalte), effort (accent néon premium type lime/corail), + neutres chauds. Dark mode natif *premium* (pas juste inversé).
- **Cockpit du jour** : séance du jour en héro, anneau d'état de forme (TSB), météo, prochaine course + compte à rebours.
- **Swift Charts** pour tous les graphes (charge, progression, prédictions).
- Micro-copies FR, ton coach bienveillant. Accessibilité : Dynamic Type, VoiceOver, contrastes AA.
- Animations signifiantes (transitions d'état de forme, complétion de séance) + haptics subtils.

---

## 9. Plan de développement par phases

### Phase 0 — Fondations vérifiables (sans Xcode)
`TriathlonEngine` : Domain + ZoneCalculator + Predictions + LoadModel + Periodizer minimal, **avec tests unitaires** (valeurs de référence VDOT/Riegel/CSS/Coggan). Buildable via `swift test`. ⇒ *On valide la science avant l'UI.*

### Phase 1 — App gratuite, testable immédiatement (Xcode requis)
Onboarding complet → profil/matériel/objectifs/dispos ; Cockpit ; génération de plan périodisé ; SwiftData + iCloud ; HealthKit (import réalisé + écriture workouts) ; check-in quotidien ; adaptation matériel + indispo ponctuelle ; export `.ZWO`/`.FIT` ; Google Calendar (compte gratuit + mock) ; notifications locales ; **Garmin via Apple Health**.

### Phase 2 — Analyse & intelligence
Dashboards Swift Charts (CTL/ATL/TSB, progression, records) ; adaptation quotidienne complète (ACWR/HRV/RPE) ; analyse post-séance en langage naturel ; blessures (schéma corporel interactif + adaptation + biblio) ; assistant Claude (opt-in) ; prédictions de course affinées + intervalles de confiance.

### Phase 3 — Intégrations directes & finitions
Garmin Connect API (push workouts, OAuth, review) ; WorkoutKit Apple Watch ; Live Activity + widgets ; nutrition de course ; préparation de course (checklist, pacing, briefings J-7/J-1) ; brick/transitions avancés ; export FIT/TCX/CSV complet.

---

## 10. Prérequis externes & entitlements

| Élément | Nécessaire pour | Coût | Quand |
|---|---|---|---|
| **Xcode** (App Store) | build/run de l'app | gratuit | avant Phase 1 |
| **Apple Developer Program** | HealthKit sur device réel, TestFlight | 99 $/an | avant test device / TestFlight |
| Entitlement **HealthKit** + clés Info.plist (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) | HealthKit | — | Phase 1 |
| Entitlement **iCloud/CloudKit** | sync SwiftData | inclus | Phase 1 |
| **Background Modes** (fetch/processing) | sync arrière-plan | — | Phase 1 |
| **Projet Google Cloud** + OAuth client iOS, scope Calendar | Google Agenda réel | gratuit | Phase 1 (mock d'abord) |
| **Clé API Anthropic** | assistant Claude enrichi | payant à l'usage | Phase 2, optionnel |
| **Garmin Developer / Health API** (review) | push direct workouts Garmin | review requise | Phase 3, optionnel |

Le simulateur iOS suffit pour l'UI ; **HealthKit ne fonctionne pleinement que sur device réel** (donnera des données simulées limitées en simulateur).

---

## 11. Stratégie de tests

- **Priorité absolue** : moteur & prédictions. Tests unitaires avec valeurs de référence de la littérature (tables VDOT Daniels, exemples Riegel, CSS, zones Coggan), tests de propriété (monotonies : plus de charge ⇒ ATL ↑ ; meilleure perf ⇒ VDOT ↑), tests de non-régression sur la périodisation (invariants : décharge présente, ACWR borné, phases ordonnées).
- **Snapshot** des séances générées (structure stable).
- **Mocks** pour tous les I/O (providers, calendar, IA) → tests de la couche app sans comptes.
- CI locale : `swift test` sur le package (rapide, sans Xcode).

---

## 12. Guide de mise en route

1. Installer **Xcode** (App Store), lancer une fois pour installer les composants + un simulateur iOS 17+.
2. Ouvrir `CoachTriathlon.xcworkspace`.
3. `swift test` dans `Packages/TriathlonEngine` pour valider le moteur.
4. Cible App → régler *Signing* (compte Apple perso gratuit pour simulateur ; Developer Program pour device/TestFlight), activer entitlements HealthKit + iCloud + Background Modes.
5. (Optionnel) Google : créer projet Google Cloud, OAuth client iOS, coller l'ID → sinon rester en mode mock.
6. (Optionnel Phase 2) Anthropic : renseigner la clé API dans les réglages → sinon coach par règles.
7. Build & Run (simulateur pour l'UI, device réel pour HealthKit).
8. TestFlight : archive → App Store Connect → testeurs internes.

## 13. Évolutions futures

Eau libre GPS avancée ; segments/KOM ; comparaison sociale sobre ; plans de force périodisés détaillés ; intégration capteurs additionnels (Stryd, Core temp) ; export vers TrainingPeaks ; watchOS app native ; modèle de fatigue par discipline ; coach vocal.

---
*Fin du document d'architecture v1.0.*
