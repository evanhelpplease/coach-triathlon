# TriathlonEngine

Le **cœur scientifique** de Coach Triathlon IA : un package Swift **pur** (aucune
dépendance à SwiftUI, HealthKit ou au réseau), donc déterministe, testable en
isolation et réutilisable (app, widget, extension).

## Contenu (Phase 0)

| Module | Rôle |
|---|---|
| `Domain/` | Types valeur immuables (`AthleteProfile`, `Equipment`, `Race`, `PlannedSession`, `CompletedActivity`, `TrainingZones`, `DailyReadiness`…) |
| `Zones/` | `ZoneCalculator` — FC (Karvonen), puissance (Coggan 7 zones), allures course (VDOT), natation (CSS) |
| `Predictions/` | `VDOT` (Daniels), `Riegel`, `CSS`, `CyclingPowerModel`, `RacePredictor` (triathlon assemblé + transitions + IC) |
| `Load/` | `LoadCalculator` (TSS-like puissance/allure/TRIMP) + `LoadSeries` (CTL/ATL/TSB, ACWR) |
| `Periodization/` | `Periodizer` — rétro-planification base→build→spécifique→affûtage, décharges, rampe bornée |
| `SessionGeneration/` | `SessionGenerator` — séances structurées (WU/corps/CD) par sport & intention, cibles issues des zones, charge estimée |
| `Adaptation/` | `ReadinessEvaluator` (VFC/sommeil/ressenti), `EquipmentSubstitution` (équivalence de charge), `Adapter` (moteur de règles : blessures, matériel, récup, ACWR/TSB, rattrapage) |
| `Planning/` | `PlanBuilder` — orchestrateur bout-en-bout : profil + course + dispos → zones → périodisation → microcycles remplis (80/20, point faible priorisé, longues le week-end) → mise à l'échelle sur la charge cible → substitution matériel |

## Vérifier le moteur **sans Xcode**

Le Command Line Tools d'Apple ne fournit **pas** XCTest. Un harnais dédié permet
de valider les modèles immédiatement :

```bash
cd Packages/TriathlonEngine
swift run EngineChecks
```

→ vérifie les valeurs de référence de la littérature (VDOT 5 km, Riegel 10 km,
CSS, puissance 40 km, zones Karvonen/Coggan, TSS, ACWR, prédiction olympique,
invariants de périodisation). Sortie code ≠ 0 si un test échoue.

## Suite XCTest complète (après installation d'Xcode)

```bash
swift test          # nécessite Xcode (XCTest)
```

Les tests couvrent en priorité le moteur et les prédictions : valeurs de
référence + tests de propriété (monotonies) + invariants de périodisation.

## Principes

- Fonctions **pures**, entrées/sorties `Codable` & `Sendable`.
- Strict concurrency Swift 6 activé.
- Aucune I/O ici : la persistance et les intégrations vivent dans la cible App.
