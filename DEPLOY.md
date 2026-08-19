# Déployer Coach Triathlon IA sur GitHub Pages

L'app web est dans `web/`. Un workflow GitHub Actions (`.github/workflows/deploy.yml`)
la construit et la publie automatiquement à chaque `git push` sur `main`.
Tout est **gratuit** et l'app est ensuite accessible 24/7 sur PC et téléphone.

## Ce qui est déjà prêt
- Le workflow de build + tests + déploiement (`.github/workflows/deploy.yml`).
- Le `base` de Vite est réglé automatiquement sur `/<nom-du-repo>/` en CI.
- Les icônes PWA (installable sur l'écran d'accueil).

---

## Étape 1 — Créer le dépôt GitHub
1. Va sur https://github.com/new
2. Nom du repo : par ex. `coach-triathlon` (retiens-le, il apparaîtra dans l'URL).
3. Laisse-le **vide** (ne coche ni README, ni .gitignore, ni licence).
4. Clique **Create repository**.

## Étape 2 — Pousser le code
Dans un terminal, à la racine du projet (là où se trouve ce fichier) :

```bash
git add -A
git commit -m "Coach Triathlon IA — app web"
git branch -M main
git remote add origin https://github.com/<TON_USER>/<TON_REPO>.git
git push -u origin main
```

Remplace `<TON_USER>` et `<TON_REPO>`. (Si Git demande un mot de passe, utilise un
**Personal Access Token** GitHub, pas ton mot de passe de compte.)

## Étape 3 — Activer GitHub Pages
1. Dans le repo → **Settings** → **Pages**.
2. **Build and deployment → Source : GitHub Actions**.
3. C'est tout : le workflow se lance seul (onglet **Actions** pour suivre).

## Étape 4 — C'est en ligne 🎉
Au bout de ~1–2 min, l'app est disponible sur :

```
https://<TON_USER>.github.io/<TON_REPO>/
```

Ouvre ce lien sur ton téléphone → menu du navigateur → **« Ajouter à l'écran
d'accueil »** (ou, sur Chrome/Android, le bouton « Installer » dans l'app, onglet
Réglages) pour l'utiliser comme une vraie app, plein écran et hors-ligne.

## Mettre à jour l'app plus tard
Fais tes modifs, puis :

```bash
git add -A && git commit -m "..." && git push
```

Le workflow reconstruit et redéploie tout seul. Tes données (profil, journal…)
restent sur ton appareil (localStorage) et ne sont pas affectées.

---

## Développer en local (facultatif)
```bash
cd web
npm install
npm run dev      # http://localhost:5173
npm test         # lance les 73 tests du moteur
```

---

## Options avancées (facultatif)

### Synchro Google Agenda
1. Console Google Cloud → active **Google Calendar API**.
2. Crée un **OAuth client ID (type Web)**.
3. Dans « Origines JavaScript autorisées », ajoute `https://<TON_USER>.github.io`.
4. Copie le **Client ID** dans l'app : **Réglages → Synchro Google Agenda**.
5. La synchro se lance depuis l'onglet **Plan → Synchro agenda**.

### Synchro multi-appareils (Firebase, facultatif)
Sans Firebase, l'app marche déjà en local + export/import JSON. Pour synchroniser
PC ↔ téléphone en temps réel :
1. Console Firebase → nouveau projet → active **Authentication (Google)** et **Firestore**.
2. Règle Firestore : `match /users/{uid} { allow read, write: if request.auth != null && request.auth.uid == uid; }`
3. Dans GitHub : **Settings → Secrets and variables → Actions** → ajoute les secrets
   `VITE_FIREBASE_API_KEY`, `VITE_FIREBASE_PROJECT_ID`, `VITE_FIREBASE_APP_ID`
   (+ éventuels `VITE_FIREBASE_AUTH_DOMAIN`, etc.).
4. Dans `.github/workflows/deploy.yml`, ajoute-les à l'étape `npm run build` :
   ```yaml
   - run: npm run build
     env:
       BASE_PATH: /${{ github.event.repository.name }}/
       VITE_FIREBASE_API_KEY: ${{ secrets.VITE_FIREBASE_API_KEY }}
       VITE_FIREBASE_PROJECT_ID: ${{ secrets.VITE_FIREBASE_PROJECT_ID }}
       VITE_FIREBASE_APP_ID: ${{ secrets.VITE_FIREBASE_APP_ID }}
   ```
5. Après redéploiement : **Réglages → Synchro cloud → Se connecter avec Google**.

---

## En cas de souci
- **Page blanche** : vérifie que Pages est bien sur « GitHub Actions » (Étape 3) et
  que le workflow est vert dans l'onglet **Actions**.
- **404 sur les fichiers** : le `base` doit valoir `/<nom-du-repo>/` — c'est
  automatique via le workflow, ne le force pas à la main.
- **Le build échoue** : ouvre le run dans **Actions** pour lire l'erreur ; en local,
  `cd web && npm ci && npm test && npm run build` reproduit exactement la CI.
