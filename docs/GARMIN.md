# Connecter Garmin Connect (module optionnel)

Apple Santé reçoit les données Garmin mais de façon incomplète/imprécise. La
**connexion directe** via la *Garmin Health API* donne des données bien plus
riches (VFC quotidienne, Body Battery, puissance normalisée, sommeil détaillé).

Ce module (`App/Providers/GarminProvider.swift`) est **prêt et branché** derrière
l'abstraction `HealthDataProvider` (cumulable avec Apple Santé). Il s'active avec
des identifiants du **Garmin Developer Program** — que seul le propriétaire du
compte peut obtenir (validation Garmin requise).

## 1. Accès développeur
1. Demander l'accès sur https://developer.garmin.com/ → *Health API* (ou *Activity API*).
   La validation par Garmin peut prendre quelques jours.
2. Créer une app → récupérer **Client ID** et **Client Secret**.
3. Déclarer l'URL de redirection OAuth :
   `com.evanblanchard.coachtriathlon:/garmin-oauth`

## 2. Configurer l'app
Dans `App/Providers/GarminProvider.swift` :
```swift
var clientID = "TON_CLIENT_ID"
var clientSecret = "TON_CLIENT_SECRET"
```
Ajouter le schéma d'URL dans `project.yml` (info) :
```yaml
CFBundleURLTypes:
  - CFBundleURLSchemes: [com.evanblanchard.coachtriathlon]
```

## 3. Reste à implémenter (TODO balisés dans le code)
- `authorize()` : `ASWebAuthenticationSession(url: authorizationURL(...))` (PKCE via
  l'enum `PKCE` déjà présente) → code → token sur `tokenEndpoint`. Stocker le
  refresh token dans le Keychain.
- `importActivities` : `GET wellness-api/rest/activities` → mapper vers `CompletedActivity`.
- `importReadiness` : `GET .../dailies` + `.../sleeps` + `.../hrv` → `DailyReadiness`
  (renseigner `hrvMs`, `bodyBattery`, `sleepHours`).
- (Phase 3) Push de workouts structurés vers la montre (Training API).

## En attendant
Réglages → **Source de données → Garmin** utilise `GarminMockProvider`, un jeu de
données **plus riche** (VFC, Body Battery, puissance normalisée sur 30 jours) pour
visualiser ce que la connexion réelle apportera. Le coordinateur
(`ProviderCoordinator`) **fusionne et déduplique** automatiquement Apple Santé +
Garmin, en gardant la source la plus complète par métrique.
