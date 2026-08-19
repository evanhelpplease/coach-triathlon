# Coach Triathlon IA — version web (PWA)

Portage web de l'app iOS (voir `../RECAP-ET-PORTAGE-WEB.md`). Vite + React + TypeScript, PWA installable, moteur d'entraînement porté 1:1 depuis Swift et testé (Vitest).

## Démarrer

```bash
cd web
npm install
npm run dev        # http://localhost:5173
```

Autres scripts :

```bash
npm run test       # tests du moteur (valeurs de référence Daniels/Coggan/Banister…)
npm run build      # build de production (typecheck + Vite + PWA)
npm run typecheck
```

## Architecture

- `src/engine/` — **moteur pur** (aucune dépendance UI), portage de `Packages/TriathlonEngine`.
  Zones, VDOT/Riegel/CSS/puissance vélo, charge (CTL/ATL/TSB/ACWR), périodisation,
  génération de séances, adaptation, PlanBuilder, prédictions, analyse, records, stratégie.
  Dates gérées en **UTC** pour parité déterministe avec `Calendar(.gregorian)`.
  Tests : `src/engine/__tests__/*.test.ts` (55 assertions calées sur `EngineChecks`).
- `src/app/` — modèle de données persisté (`model.ts`), sérialisation Date/Set,
  dérivations analytiques (`derive.ts`), store Zustand (`store.ts`).
- `src/providers/` — contrat `HealthDataProvider` + `ManualProvider` (le **Journal** alimente le moteur).
- `src/persistence/` — abstraction `SyncProvider` : `LocalProvider` (localStorage) + export/import JSON.
- `src/services/` — météo (Open-Meteo), synchro Google Agenda (GIS + Calendar API).
- `src/screens/` — Cockpit, Plan, détail séance, Journal, Analyse, Prédictions, Courses, Blessures, Réglages, Onboarding.

## Fonctionnalités

Onboarding · Cockpit adaptatif (forme TSB, check-in, météo, bannières, séance du jour) ·
Plan périodisé + détail structuré · slider de progression · adaptation quotidienne ·
Analyse (dashboards + analyse post-séance + records) · Prédictions de course (splits + IC,
pacing, nutrition) · Blessures (zones + catalogue + rééducation) · **Journal de saisie manuelle**
(sommeil + entraînements → `ManualProvider`) · **Synchro Google Agenda** (idempotente) ·
export/import JSON · mode démo.

## Persistance multi-appareils

Par défaut : **localStorage** (cet appareil) + export/import JSON. Pour le 24/7 PC + téléphone,
le **`FirebaseProvider`** (Auth Google + Firestore, synchro **temps réel**) est branché
([firebaseProvider.ts](src/persistence/firebaseProvider.ts)) et chargé dynamiquement (code-split).
Alternative prévue : Google Drive `appDataFolder` (réutilise l'OAuth de l'agenda).

### Activer Firebase

1. Console Firebase → nouveau projet → activer **Authentication** (fournisseur Google) et **Firestore**.
2. Réglages du projet → app Web → récupérer la config (apiKey, projectId, appId…).
3. Créer `web/.env.local` (config web publique, sans danger côté client) :

   ```
   VITE_FIREBASE_API_KEY=...
   VITE_FIREBASE_PROJECT_ID=...
   VITE_FIREBASE_APP_ID=...
   VITE_FIREBASE_AUTH_DOMAIN=...        # optionnel (défaut <projectId>.firebaseapp.com)
   VITE_FIREBASE_STORAGE_BUCKET=...      # optionnel
   VITE_FIREBASE_MESSAGING_SENDER_ID=... # optionnel
   ```

   En CI (GitHub Pages), passer ces variables au step `npm run build` (secrets du repo).
4. Firestore → règles : chaque utilisateur n'accède qu'à son document `users/{uid}` :

   ```
   match /users/{uid} { allow read, write: if request.auth != null && request.auth.uid == uid; }
   ```
5. Dans l'app : **Réglages → Synchro cloud → Se connecter avec Google**. Les données
   (un seul document JSON par utilisateur) se synchronisent en temps réel entre appareils.

## Import de fichiers (Journal)

**Journal → Importer un fichier** accepte `.fit` (binaire, résumé de session), `.tcx`, `.gpx`
et `.csv` (export Garmin Connect / Strava), sans dépendance externe
([importFiles.ts](src/services/importFiles.ts)). Évite de tout ressaisir.

## Synchro Google Agenda

1. Projet Google Cloud gratuit → activer *Google Calendar API*.
2. Créer un *OAuth client ID (Web)*, déclarer l'origine `https://<user>.github.io`.
3. Renseigner le Client ID dans **Réglages → Synchro Google Agenda**.
4. Lancer depuis l'onglet **Plan → Synchro agenda**. Idempotent via
   `extendedProperties.private.coachtriId = session.id`.

## Déploiement GitHub Pages

`.github/workflows/deploy.yml` build et déploie à chaque push sur `main`
(`base` = `/<nom-du-repo>/`). Activer **Pages → Source : GitHub Actions** dans les réglages du repo.
