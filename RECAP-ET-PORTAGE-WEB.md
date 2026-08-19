# Coach Triathlon IA — Récapitulatif & Brief de portage en site web

> **But de ce document.** Il sert deux choses :
> 1. **Récapituler** tout ce que fait l'application iOS actuelle (fonctionnalités + moteur scientifique + architecture).
> 2. Servir de **brief de portage** pour reconstruire le tout en **site web** dans une **nouvelle conversation Claude Code**, sur une copie du dossier, déployable sur **GitHub** (accès PC + téléphone, 24/7).
>
> Deux ajouts demandés pour la version web :
> - **Saisie manuelle des données** (sommeil + entraînements réalisés), puisqu'on ne peut pas charger Garmin facilement.
> - **Synchronisation automatique vers Google Agenda**.

---

## 0. Contexte : pourquoi passer au web ?

Le format app iOS impose l'écosystème Apple : signer avec un compte Apple Developer (99 $/an) pour un usage durable, App Groups/HealthKit/Sign in with Apple payants, TestFlight… Trop lourd/coûteux pour un usage perso.

**Un site web** résout tout ça : hébergement **gratuit** sur GitHub Pages, accessible **partout** (PC + téléphone via le navigateur, installable en PWA sur l'écran d'accueil), mises à jour instantanées par simple `git push`.

### Sur Garmin (pour mémoire)
Relier directement Garmin nécessite de s'inscrire au **Garmin Developer Program** (`developer.garmin.com` → *Health API* ou *Activity API*), avec **validation manuelle par Garmin** (plusieurs jours), puis un flux **OAuth 2.0** avec `clientID`/`clientSecret`. C'est faisable mais lourd et non instantané. **Décision : on remplace par une saisie manuelle** (sommeil + entraînements) dans la version web. Le module Garmin reste documenté dans le code (`App/Providers/GarminProvider.swift`) si tu veux l'activer un jour.

---

## 1. Ce que fait l'application (récap complet)

Une app de **coach triathlon IA** : elle remplace un coach humain — génère un plan personnalisé et adaptatif, analyse les données, accompagne au quotidien. Français, unités métriques.

### 1.1 Onboarding (9 étapes)
Collecte un maximum d'infos pour bâtir un plan sur mesure :
- **Physique** : date de naissance, sexe, taille, poids, FC max / FC repos (optionnel).
- **Niveaux** par discipline (débutant → expert) + volume hebdo.
- **Référentiels par sport** (avec champs de saisie) : VMA **ou** chrono 5/10 km (course) → VDOT ; FTP (vélo) ; chronos 400 m + 200 m → CSS (natation). **Si une donnée manque → un test de terrain est planifié** en début de plan.
- **Matériel** complet (vélo + type + prolongateurs + capteur + home trainer ; piscine/eau libre/combinaison ; tapis/piste ; accès renfo).
- **Disponibilités** : jours dispo + nb max de séances/semaine, et **contraintes par lieu** (ex. piscine seulement lun/mer/ven).
- **Objectif** : plaisir / progresser sans course / **une ou plusieurs courses** (type, lieu, date, priorité A/B/C, **objectif de temps**).
- **Blessures** antérieures/actuelles avec **schéma corporel interactif** (voir 1.7) + « douleur encore présente ? ».
- **Connexions** : source de données (démo / Apple Santé / Garmin), agenda.
- Bouton **« Charger un athlète démo »** pour tout tester instantanément.

### 1.2 Cockpit du jour (écran d'accueil)
- **Anneau d'état de forme** (TSB) + « Fitness / Fatigue ».
- **Météo** locale (Open-Meteo) + suggestion **extérieur ↔ home trainer/tapis** selon les conditions.
- **Check-in du jour** (forme/sommeil/courbatures/motivation) → ajuste la séance en direct.
- **Bannières d'adaptation** expliquées et pédagogiques (allègement récup, décharge ACWR, substitution matériel, adaptation blessure, rattrapage…).
- **Séance du jour** adaptée (avec bouton « Voir la séance »).
- **Compte à rebours** vers la prochaine course + stats de la semaine.

### 1.3 Plan
Séances datées groupées par jour, ajustées aux indisponibilités (un sport indispo à une date → séance convertie). Chaque séance ouvre un **détail structuré** : échauffement / intervalles / retour au calme, avec **cibles** (allure/puissance/FC/RPE) et consignes techniques.

### 1.4 Génération & adaptation (le cœur, voir §2)
- **Périodisation** automatique vers la/les course(s) : base → build → spécifique → affûtage, décharges régulières, rampe de charge bornée.
- **Slider de progression** : **Prudent / Équilibré / Performance** (rampe + volume d'intensité + risque de blessure).
- **Polarisation 80/20** avec de vrais intervalles par discipline (VO2/seuil **y compris vélo**), bricks en build/spécifique.
- **Adaptativité quotidienne** : récup basse → allègement ; ACWR élevé → décharge ; TSB très bas → alerte ; séance manquée → replanifiée sans surcharge ; matériel/blessure → substitution.

### 1.5 Analyse
- **Dashboards** (graphiques) : Forme (TSB), Fitness & Fatigue (CTL/ATL), charge hebdo par sport.
- **Dernières séances** : chaque activité réalisée reçoit un **résumé en langage naturel** (intensité, dérive cardiaque, tendance d'allure/puissance, charge).
- **Records personnels** par discipline.

### 1.6 Prédictions de course
Pour la course cible : **chrono prédit décomposé** (natation / T1 / vélo / T2 / course) + **intervalle de confiance**. Plus : temps de référence par distance (nat 400/1500, vélo 20/40/90, course 5/10/semi/marathon) et projection sur **tous les formats** (Sprint/M/Half/Full). Fondé sur VDOT, CSS, modèle de puissance vélo, matériel.

### 1.7 Blessures (schéma + adaptation + rééducation)
- **Schéma corporel interactif** : silhouette avec points tappables (épaule, bas du dos, hanche, ischios, genou, mollet, cheville, pied) + « Autre ».
- **Liste déroulante de blessures précises** par zone avec **description du ressenti** (ex. cheville → tendinite d'Achille / entorse / malléole / fracture de fatigue / fatigue).
- **Adaptation immédiate** du plan (ex. pied → course/brick évités, natation/vélo maintenus ; épaule → natation suspendue).
- **Bibliothèque d'étirements/renforcements adaptés** par zone (badges Étirement / Renforcement / Mobilité / Soin) + rappel médical systématique.

### 1.8 Divers
- **Recalibrage automatique des zones** : après une séance de test, saisie du résultat (distance VMA / puissance FTP / temps CSS) → référentiel mis à jour → zones et plan régénérés → la séance de test disparaît.
- **Export .ZWO / .FIT** d'une séance (import manuel Zwift/Garmin).
- **Synchro agenda Apple** (EventKit) — à porter en **Google Agenda** côté web.
- **Notifications** locales (rappels de séance).
- **Widget** iOS + **Live Activity** (Dynamic Island) — à repenser en web (notifications PWA / pas d'équivalent direct).
- **Compte** : email + mot de passe (local), Sign in with Apple, Google (scaffold).
- **Mode démo** complet (données simulées) — utile comme état par défaut sur le web aussi.

---

## 2. Le moteur scientifique (à porter en TypeScript)

**Le cœur réutilisable.** Tout est du **calcul pur** (aucune dépendance UI/réseau), donc **facile à porter en TypeScript**. Fichiers de référence :
`Packages/TriathlonEngine/Sources/TriathlonEngine/`.

Le nouveau projet web aura accès à ces fichiers Swift (dossier copié) : **les lire et les transcrire en TS** (mêmes formules, mêmes structures). Résumé des pièces + formules clés ci-dessous.

### 2.1 Zones (`Zones/ZoneCalculator.swift`)
- **FC — Karvonen** (réserve de FC) : `FC_cible = repos + p·(max − repos)`. 5 zones (bornes en % de la réserve : Z1<0.68, Z2 0.68–0.83, Z3 0.83–0.90, Z4 0.90–0.98, Z5>0.98). FC max estimée si absente : `211 − 0.64·âge`.
- **Puissance — Coggan** : 7 zones en % FTP (Z1<55, Z2 55–75, Z3 76–90, Z4 91–105, Z5 106–120, Z6 121–150, Z7>150).
- **Allures course** : dérivées du VDOT (voir 2.2).
- **Allures natation** : dérivées de la CSS.

### 2.2 Prédictions (`Predictions/`)
- **VDOT / Daniels** (`VDOT.swift`) :
  - Coût O₂ : `vo2(v) = -4.60 + 0.182258·v + 0.000104·v²` (v en m/min).
  - Fraction de VO₂max soutenable : `%max(t) = 0.8 + 0.1894393·e^(-0.012778·t) + 0.2989558·e^(-0.1932605·t)` (t en min).
  - `VDOT = vo2(v) / %max(t)`. Prédiction d'un temps par **bissection** (fonction décroissante en t).
  - Allures d'entraînement = vitesses à un % de VO₂max donné (E 70 %, M 82 %, seuil 88 %, I 98 %, R 105 %).
- **Riegel** (`Riegel.swift`) : `T2 = T1·(D2/D1)^1.06`.
- **CSS** (`CSS.swift`) : `vitesse = (400−200)/(T400−T200)` m/s ; `allure/100 = 100/vitesse`.
- **Puissance vélo** (`CyclingPower.swift`) : `P = (m·g·Crr + m·g·pente)·v + ½·ρ·CdA·v²·v`, puis `/rendement` ; vitesse par inversion numérique. CdA typique par type de vélo + prolongateurs.
- **Prédiction de course assemblée** (`RacePredictor.swift`) : par format, intensité vélo = % FTP (sprint 0.95 … full 0.72), pénalité course post-vélo (×1.03 → ×1.13), transitions T1/T2 estimées, combinaison néoprène ≈ −4 % natation ; **intervalle de confiance** qui s'élargit quand des référentiels manquent.

### 2.3 Charge (`Load/LoadModel.swift`)
- **Charge par séance (TSS-like)** : vélo `= (durée_s·NP·IF)/(FTP·3600)·100` ; course/nat via allure vs seuil ; **TRIMP** (Banister) en repli FC ; sinon durée×RPE.
- **CTL** (fitness, τ=42 j), **ATL** (fatigue, τ=7 j), **TSB** = CTL − ATL, **ACWR** = charge aiguë 7 j / chronique 28 j. Moyennes exponentielles (`α = 1 − e^(-1/τ)`).

### 2.4 Périodisation (`Periodization/Periodizer.swift`)
Rétro-planification depuis la course : affûtage (1–3 sem selon format) ← spécifique ← build ← base. **Décharge** toutes les N semaines (charge réduite). **Rampe bornée** (+X %/sem). **Niveau de progression** (Prudent/Équilibré/Performance) → règle la rampe (0.05/0.08/0.11), la fréquence/ampleur de décharge, et le nombre de séances qualité.

### 2.5 Génération de séances (`SessionGeneration/`)
Séances structurées (WU / corps / CD) par sport × intention (endurance/tempo/seuil/VO2/sprint/technique/brick/force), cibles issues des zones, charge estimée (`Σ durée_h·IF²·100`). Éducatifs natation, position aéro vélo si prolongateurs, etc.

### 2.6 Adaptation (`Adaptation/`)
- `ReadinessEvaluator` : score 0–100 depuis VFC vs ligne de base (moyenne − écart-type), FC repos, sommeil, ressenti, Body Battery → good/moderate/low.
- `EquipmentSubstitution` : conversion à équivalence de charge (pas de vélo → course ; pas d'eau → travail à sec ; etc.).
- `Adapter` (moteur de règles ordonné) : **1** blessures (sécurité) → **2** matériel → **3** récup du jour → **4** garde-fous charge (ACWR>1.5 décharge, TSB<−25 alerte) → **5** rattrapage des séances manquées. Chaque ajustement produit un **événement tracé et expliqué**.

### 2.7 Assemblage (`Planning/PlanBuilder.swift`)
Orchestrateur bout-en-bout : profil + matériel + course(s) + dispos + progression → zones → périodisation → microcycles remplis (80/20, point faible priorisé, longues le week-end, **respect des jours par lieu**) → mise à l'échelle sur la charge cible → substitution matériel. Gère **plusieurs courses** (mini-affûtage avant les courses B/C).

### 2.8 Analyse (`Analysis/`)
- `PostSessionAnalyzer` : résumé en langage naturel d'une activité réalisée.
- `PersonalRecords` : records par discipline.

---

## 3. Modèle de données (à recréer en TS)

Types Domain (dans `TriathlonEngine/Sources/TriathlonEngine/Domain/`) :
`AthleteProfile`, `Equipment`, `Race`, `TrainingZones`, `PlannedSession` (+ `WorkoutStep`), `CompletedActivity`, `DailyReadiness` (+ `SubjectiveCheckin`), `InjuryRecord`, `ProgressionLevel`, `WeeklyAvailability` (jours + max séances + jours par sport).

Côté app (persistance) : profil, matériel, courses, séances planifiées, check-ins, blessures (+ blessure précise), indisponibilités. Catalogue blessures/rééducation : `App/Features/Health/InjuryCatalog.swift`.

---

## 4. Ce qu'il faut construire pour la version web

### 4.1 Stack recommandé (100 % gratuit, GitHub-hostable)
- **Frontend** : **Vite + React + TypeScript** (ou Svelte/SvelteKit). **PWA** (installable sur l'écran d'accueil du téléphone, offline).
- **Graphiques** : Recharts ou Chart.js.
- **Hébergement** : **GitHub Pages** (déploiement via GitHub Actions à chaque push) — ou Netlify/Vercel (free) si tu préfères.
- **Moteur** : **porter `TriathlonEngine` en TypeScript** (paquet `src/engine/`), 1:1 avec les fichiers Swift. Écrire des **tests** (Vitest) sur les valeurs de référence (VDOT 5 km, Riegel, CSS, Coggan, puissance 40 km…) — les mêmes que `EngineChecks` en Swift.
- **Design** : reprendre l'identité (eau/route/effort, dark mode) — voir `Packages/DesignSystem`.

### 4.2 Persistance cross-appareils (24/7, PC + téléphone)
Pour que les données soient les mêmes partout, deux options gratuites :
- **Firebase (recommandé)** : **Firebase Auth** (connexion Google) + **Firestore** (free tier) pour stocker profil/plan/journal. Synchro automatique multi-appareils, temps réel.
- **Alternative sans backend** : stockage dans **Google Drive `appDataFolder`** (via l'OAuth Google déjà utilisé pour l'agenda) — un seul fichier JSON, synchro par le compte Google.
- **Fallback local** : `localStorage` (par appareil) + export/import JSON (pratique en dépannage).

### 4.3 Synchro automatique Google Agenda (demandé)
- **OAuth Google** dans le navigateur via **Google Identity Services** ; scope `https://www.googleapis.com/auth/calendar.events`.
- Créer/mettre à jour un **événement par séance planifiée** (titre `🏊🚴🏃 …`, durée, description = déroulé). **Idempotent** via un identifiant stocké (ex. `extendedProperties.private.coachtriId = session.id`).
- **« Auto »** = re-synchroniser à **chaque changement de plan** (génération, adaptation, saisie d'un résultat) + un **bouton « Resynchroniser »**. (Un vrai cron nécessiterait un backend ; côté client, on synchronise à l'ouverture de l'app et à chaque modif.)
- Prérequis : un **projet Google Cloud gratuit** (activer *Google Calendar API*, créer un *OAuth client ID (Web)*, déclarer l'origine `https://<user>.github.io`). Doc existante réutilisable : `docs/GOOGLE_CALENDAR.md`.

### 4.4 Saisie manuelle des données (remplace Garmin/Health — demandé)
Un écran **« Journal »** avec deux formulaires alimentant **exactement** le même moteur (donc CTL/ATL/TSB, ACWR, adaptation, analyse post-séance, records fonctionnent pareil) :
- **Sommeil / récupération du jour** → `DailyReadiness` : heures de sommeil, qualité, FC repos, VFC (optionnel), + le check-in subjectif (forme/courbatures/motivation).
- **Entraînement réalisé** → `CompletedActivity` : sport, date, durée, distance, FC moy/max, **puissance moy/normalisée** (vélo), allure (course/nat), longueurs (piscine), RPE, notes.
- Ces enregistrements remplacent le « provider » santé : créer un **`ManualProvider`** qui renvoie `activities` + `readiness` depuis les saisies (l'app iOS a déjà cette abstraction : `HealthDataProvider` avec `MockHealthProvider`/`AppleHealthProvider` — reprendre le même contrat).
- **Import optionnel de fichiers** `.FIT`/`.TCX`/`.GPX`/`.CSV` (déposer un fichier exporté de Garmin Connect) pour éviter de tout ressaisir — bonus.

### 4.5 Fonctionnalités à reprendre (parité avec l'app)
Onboarding riche · Cockpit adaptatif (forme, check-in, météo, bannières, séance du jour) · Plan + détail structuré · Génération/périodisation + slider de progression · Adaptation quotidienne · Analyse (dashboards + analyse post-séance + records) · Prédictions de course · Blessures (schéma + catalogue + rééducation) · Recalibrage par tests · Multi-courses + objectifs de temps · Disponibilités par jour/lieu · Export .ZWO/.FIT · **Google Agenda auto** · **Journal de saisie manuelle** · Météo (Open-Meteo, sans clé) · Mode démo.

### 4.6 Météo
`Open-Meteo` (gratuit, sans clé) : `https://api.open-meteo.com/v1/forecast?...&current=temperature_2m,precipitation,weather_code,wind_speed_10m`. Géolocalisation via l'API `navigator.geolocation` du navigateur (repli sur une ville par défaut). Logique déjà écrite : `App/Weather/WeatherService.swift`.

---

## 5. Démarrer la nouvelle conversation Claude Code

Dans la copie du dossier, ouvre une nouvelle conversation et donne à peu près ce prompt :

> « Je veux convertir cette app iOS de coach triathlon en **site web** (Vite + React + TypeScript, PWA, déployable sur **GitHub Pages**). Lis d'abord **`RECAP-ET-PORTAGE-WEB.md`** à la racine, puis **porte le moteur** `Packages/TriathlonEngine/…` en TypeScript (avec des tests Vitest sur les valeurs de référence). Recrée toutes les fonctionnalités décrites. Ajoute deux choses nouvelles : un **Journal de saisie manuelle** (sommeil + entraînements réalisés) qui alimente le moteur via un `ManualProvider`, et la **synchro automatique Google Agenda** (OAuth navigateur + Calendar API, idempotent). Pour la persistance multi-appareils, propose Firebase (Auth Google + Firestore) ou Google Drive appDataFolder. Commence par l'architecture et le portage du moteur avec ses tests, puis l'UI. »

Fichiers de référence utiles dans le dossier :
- Moteur : `Packages/TriathlonEngine/Sources/TriathlonEngine/` (+ tests `Tests/` et harnais `Sources/EngineChecks/main.swift`).
- Design : `Packages/DesignSystem/Sources/DesignSystem/` (palette, composants).
- App (features) : `App/Features/…` (onboarding, cockpit, plan, analyse, prédictions, blessures, journal, réglages…).
- Providers/données : `App/Providers/` (contrat `HealthDataProvider`), `App/Weather/`, catalogues `App/Features/Health/InjuryCatalog.swift`.
- Docs existantes : `docs/ARCHITECTURE.md`, `docs/GAP_ANALYSIS.md`, `docs/GOOGLE_CALENDAR.md`, `docs/GARMIN.md`, `docs/PHASE1_SETUP.md`.

---

## 6. Déploiement GitHub (résumé)
1. Créer un repo GitHub, y pousser la copie du dossier.
2. Config Vite `base: '/<nom-du-repo>/'` (pour GitHub Pages).
3. GitHub Action « build & deploy » vers la branche `gh-pages` (ou Pages « GitHub Actions »).
4. Activer **Pages** dans les réglages du repo → l'app est en ligne sur `https://<user>.github.io/<repo>/`.
5. PWA : ajouter un `manifest.webmanifest` + service worker → « Ajouter à l'écran d'accueil » sur le téléphone.
6. Déclarer l'origine GitHub Pages comme **origine autorisée** dans le projet Google Cloud (OAuth) pour l'agenda.

---

*Rédigé comme point de départ du portage web. Le moteur (la vraie valeur) est du calcul pur, directement transcriptible en TypeScript à partir des fichiers Swift fournis.*
