# Phase 1 — Mise en route de l'app

## Prérequis

- **Xcode 26+** installé (fait ✅).
- **Runtime iOS Simulator** — à installer une fois (le SDK est là, mais l'image
  du simulateur, plusieurs Go, ne l'est pas encore). Deux options :
  - Xcode → Settings → Components → iOS 26.x → *Get*
  - ou en ligne de commande :
    ```bash
    xcodebuild -downloadPlatform iOS
    ```
- **XcodeGen** (déjà installé via Homebrew) pour (re)générer le projet.

## Générer le projet & lancer

```bash
cd "MyCoach App"
xcodegen generate          # crée CoachTriathlon.xcodeproj depuis project.yml
open CoachTriathlon.xcodeproj
```

Dans Xcode : choisir un simulateur iPhone, puis **⌘R**.

- Au premier lancement, l'app affiche l'**onboarding**. Le bouton
  « Charger un athlète démo » remplit un profil complet et génère un plan
  immédiatement — pratique pour tout voir sans rien saisir.
- Le **mode démo** (Réglages) fournit des activités/récupération simulées : aucune
  permission requise. Désactive-le pour brancher **Apple Santé** (le simulateur a
  peu de données santé ; teste HealthKit sur un iPhone réel).

## Vérifier sans lancer (utile en CI ou sans runtime)

Le moteur pur, testable sans Xcode :
```bash
cd Packages/TriathlonEngine && swift run EngineChecks
```

Typecheck de l'app contre le SDK simulateur (sans runtime installé) :
```bash
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
T=arm64-apple-ios17.0-simulator ; B=/tmp/coachbuild ; mkdir -p $B
swiftc -emit-module -module-name TriathlonEngine -sdk "$SDK" -target $T \
  -emit-module-path $B/TriathlonEngine.swiftmodule \
  $(find Packages/TriathlonEngine/Sources/TriathlonEngine -name '*.swift')
swiftc -emit-module -module-name DesignSystem -sdk "$SDK" -target $T \
  -emit-module-path $B/DesignSystem.swiftmodule \
  $(find Packages/DesignSystem/Sources -name '*.swift')
swiftc -typecheck -sdk "$SDK" -target $T -I $B $(find App -name '*.swift')
```

## Signature (device réel / TestFlight)

- Renseigner `DEVELOPMENT_TEAM` dans `project.yml` (ou régler *Signing* dans Xcode).
- HealthKit sur device réel nécessite l'**Apple Developer Program** (99 $/an).

## iCloud (sync SwiftData) — activation

Actuellement en **stockage local** pour un premier lancement sans friction. Pour activer la sync iCloud :
1. Activer la capability **iCloud → CloudKit** dans Xcode et créer le conteneur.
2. Décommenter le bloc iCloud dans `App/CoachTriathlon.entitlements`.
3. Passer `ModelConfiguration` en CloudKit dans `App/CoachTriathlonApp.swift`.

## État Phase 1 (tranche verticale livrée)

| Livré | À venir (suite Phase 1 / Phase 2) |
|---|---|
| Onboarding + profil/matériel/course | Édition profil détaillée, écrans matériel/blessure |
| Cockpit (forme TSB, séance du jour, compte à rebours, stats) | Graphiques Swift Charts, analyse post-séance |
| Plan (séances datées, détail structuré) | Édition/drag de séances, check-in quotidien |
| Persistance SwiftData + mappers | Sync iCloud activée, BackgroundTasks |
| DataProvider (Apple Health réel + mock cumulables) | Export .ZWO/.FIT, Google Calendar, notifications |
| Design system (tokens, composants, dark mode) | Widgets, Live Activity |
