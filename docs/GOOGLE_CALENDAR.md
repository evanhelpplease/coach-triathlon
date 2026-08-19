# Activer la synchro Google Agenda (module optionnel)

L'agenda **Apple (EventKit)** fonctionne déjà sans configuration (Réglages →
« Ajouter au calendrier Apple »). Google Agenda est un **module optionnel** dont
la partie cryptographique (PKCE) est déjà implémentée ; il reste à fournir des
identifiants et à brancher le flux navigateur.

## 1. Projet Google Cloud (gratuit)
1. https://console.cloud.google.com → nouveau projet.
2. **APIs & Services → Enable APIs** → activer *Google Calendar API*.
3. **OAuth consent screen** : type *External*, ajoute ton email en testeur.
4. **Credentials → Create OAuth client ID → iOS**.
   - Bundle ID : `com.evanblanchard.coachtriathlon`
   - Récupère le *Client ID*.

## 2. Configurer l'app
Dans `App/Calendar/GoogleCalendarService.swift`, renseigne :
```swift
var clientID = "TON_CLIENT_ID.apps.googleusercontent.com"
```
Ajoute le schéma d'URL de redirection dans `project.yml` (info) :
```yaml
CFBundleURLTypes:
  - CFBundleURLSchemes: [com.googleusercontent.apps.TON_CLIENT_ID]
```

## 3. Reste à implémenter (TODO balisés dans le code)
- `connect()` : `ASWebAuthenticationSession(url: authorizationURL(...))` →
  récupérer le `code` → échanger sur `tokenEndpoint` (avec le `code_verifier`).
- Stockage sécurisé du refresh token (Keychain).
- `push(sessions:)` : `POST /calendar/v3/calendars/primary/events` par séance
  (idempotence via `extendedProperties.private.coachtriId = session.id`).

`GoogleCalendarClient` est déjà branchable derrière le protocole `RemoteCalendar`
(mock possible pour les tests). `isConfigured` reste `false` tant que `clientID`
est vide → l'app affiche « bientôt (OAuth) ».
