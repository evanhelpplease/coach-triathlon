# Analyse d'écart — app vs cahier des charges initial

> État au 2026-08-05. Légende : ✅ fait · 🟡 partiel · ❌ à faire · ⏭️ phase ultérieure assumée

## Stack technique

| Exigence | État | Note |
|---|---|---|
| Swift/SwiftUI iOS 17+ | ✅ | |
| MVVM (justifié) | ✅ | + moteur pur `TriathlonEngine` |
| SwiftData | ✅ | |
| Sync iCloud | 🟡 | code prêt (`.automatic` + repli local) ; activation = capability iCloud + conteneur |
| HealthKit lecture **et** écriture | ✅ | `AppleHealthProvider` |
| Garmin via couche `DataProvider` | 🟡 | Phase 1 = via Apple Health ✅ ; API directe ⏭️ Phase 3 |
| Google Calendar (OAuth projet gratuit) | ❌ | **à faire Phase 1** |
| EventKit (Apple Calendar) | ❌ | optionnel |
| Moteur règles + adaptatif embarqué | ✅ | |
| Couche Claude + fallback local | 🟡 | fallback local ✅ ; `AnthropicClient` ❌ |
| Notifications locales + push | ❌ | **locales à faire Phase 1** ; push ⏭️ |
| Design system, dark mode, animations | ✅ | |

## Onboarding & profil

| Exigence | État | Note |
|---|---|---|
| Données physiques (taille/poids/âge/sexe/FCmax/FCrepos) | 🟡 | onboarding minimal ; **Étape 3 en cours** |
| FTP / allures réf / VMA / CSS | 🟡 | FTP + 5 km actuellement ; **Étape 3 : tout + tests** |
| Historique sportif (niveau, volume, expérience) | 🟡 | niveaux ✅ ; volume/expérience ❌ |
| Matériel détaillé | ✅ | éditable (`EquipmentEditView`) |
| Montre connectée (modèle) | ❌ | |
| Objectifs (courses A/B/C, multi, sans objectif) | 🟡 | 1 course + priorité ✅ ; multi-courses ❌ ; « sans objectif » ❌ |
| Ajout/suppr/modif course → re-périodisation | 🟡 | régénération manuelle ✅ ; multi ❌ |
| Disponibilités (jours/créneaux, nb max, durée sem vs WE) | 🟡 | `WeeklyAvailability` par défaut ; **pas saisi en onboarding** |
| Contraintes santé / blessures | ✅ | `InjuryView` (déclaration + adaptation) |

## Moteur d'entraînement

| Exigence | État |
|---|---|
| Périodisation auto (base/build/spé/affûtage/décharge) | ✅ |
| Zones individualisées (FC/allure/puissance) recalibrées | 🟡 calcul ✅ ; recalibrage auto après séance ❌ |
| Séances structurées détaillées + consignes | ✅ |
| Adaptativité quotidienne (réalisé, récup, fatigue, manquées) | ✅ |
| Détection surentraînement + allègement pédagogique | ✅ (ACWR/TSB) |
| Adaptation matériel (indispo ponctuelle/durable) | ✅ |

## Synchronisations

| Exigence | État |
|---|---|
| Push workout vers montre (WorkoutKit/Garmin) | ⏭️ Phase 3 |
| Export .FIT / .ZWO (import manuel) | ✅ `WorkoutExport` (bouton partager sur le détail de séance) |
| Vers l'agenda | 🟡 Apple/EventKit ✅ ; Google OAuth ⏭️ |
| Import activités/sommeil/FC/VFC/poids | ✅ (Health) |
| Notifications locales (rappels de séance) | ✅ `NotificationService` |
| Sync arrière-plan (BackgroundTasks) | ✅ `BGAppRefreshTask` enregistré (reprogramme rappels) |

## Analyse & prédictions

| Exigence | État |
|---|---|
| Analyse post-séance en langage naturel | ✅ `PostSessionAnalyzer` + `ActivitiesView` |
| Tableaux de bord (CTL/ATL/TSB, volumes, records) | ✅ CTL/ATL/TSB + volumes + `RecordsView` |
| Prédictions de course (Riegel/VDOT/CSS/puissance) | ✅ `PredictionsView` (course cible décomposée + tous formats) |
| Temps de référence prédits par distance | ✅ nat 400/1500, vélo 20/40/90, course 5/10/semi/marathon |
| Intervalle de confiance | ✅ ± % + fourchette ; évolution dans le temps ❌ (pas d'historique persisté) |

## Blessures

| Exigence | État |
|---|---|
| Déclaration (zone, intensité, depuis) | ✅ (liste ; schéma corporel interactif ❌) |
| Adaptation immédiate | ✅ |
| Bibliothèque conseils/réathlétisation | ❌ |
| Rappel médical | ✅ |
| Prévention proactive (renfo/mobilité, alertes volume) | ✅ |

## Fonctionnalités additionnelles

| Exigence | État |
|---|---|
| Assistant conversationnel (Claude) | ❌ |
| Plan nutrition de course | ❌ |
| Préparation course (checklist, pacing, briefings) | ❌ |
| Séances brick + éducatifs T1/T2 | 🟡 brick ✅ ; éducatifs transition ❌ |
| Météo (adaptation extérieur↔indoor) | ❌ (règle moteur prête) |
| Journal RPE / notes / sensations | 🟡 RPE modèle ✅ ; écran journal ❌ |
| Badges / streaks | ❌ |
| Mode hors-ligne | ✅ (local) |
| Widgets + Live Activity | ❌ |
| Export FIT/TCX/CSV + RGPD | ❌ |
| Accessibilité (Dynamic Type, VoiceOver, contrastes) | 🟡 Dynamic Type/contrastes OK ; audit VoiceOver ❌ |

## Manques les plus visibles à prioriser

1. **Écran de prédictions de course** — le moteur calcule déjà tout (chrono par discipline + transitions + IC), il n'est juste pas affiché. Fort ROI.
2. **Onboarding riche + tests de terrain** — Étape 3 (en cours).
3. **Export .ZWO/.FIT**, **Google Calendar**, **notifications locales** — trio Phase 1 restant.
4. **Analyse post-séance en langage naturel** + **records personnels**.
5. **Disponibilités saisies** (jours/créneaux) au lieu du défaut.
