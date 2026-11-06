# CLAUDE.md : instructions pour Claude Code sur Zieuton

Lis aussi `docs/SPEC.md` (ce que fait l'app, ce qu'elle ne fera pas). En cas de doute sur une fonction, la spec gagne.

## Le projet en bref

Zieuton est une app iPhone qui compare les exports officiels Instagram d'un utilisateur pour lui montrer qui s'est désabonné. Pas de serveur, pas de compte : tout reste sur le téléphone (+ sauvegarde iCloud). Propriétaire : Victor, non développeur. Il valide chaque changement.

## Architecture

- `index.html` : toute l'interface et la logique (HTML + CSS + JS, environ 7 100 lignes, aucune étape de construction). Servi par GitHub Pages (https://vic-tard.github.io/abo-insta/) ET embarqué dans l'app.
- `js/zieuton-core.js` : lecture des exports et comparaison. Recopié dans `index.html` entre les repères `ZIEUTON-CORE`. Ne modifie jamais ce bloc dans `index.html` : modifie `js/zieuton-core.js`, puis `node scripts/sync-core.mjs`.
- `ios/Zieuton/` : coque Swift (UIKit + WKWebView). `WebViewController.swift` contient plusieurs classes : `WebViewController` (page, pont, mises à jour), `MetaViewController` (Instagram dans l'app + bandeau guide), `ExportWatcher` (notifications), `PlusStore` (StoreKit 2), `ICloudBackup`.
- Pont page ⇄ coque : la page envoie `window.webkit.messageHandlers.zyeuto.postMessage({type: ...})`, la coque répond via `window.zyeutoMeta`, `window.zyeutoICloud`, etc. `window.ZYEUTO_APP.version` dit ce que la coque sait faire : toute nouvelle fonction native augmente ce numéro et la page doit garder un repli pour les anciennes versions.
- Données : IndexedDB (principal) + localStorage (copie), un état par compte (`acct:<id>`), réglages dans `abo-prefs`.

## Règles de travail

1. **Une PR par tâche, jamais de push direct sur `main`.** Ne fusionne pas toi-même : Victor valide.
2. Cite le ticket Linear dans le titre ou la description de la PR (ex. `ZIE-12`).
3. Avant d'ouvrir la PR : `npm test`, `node scripts/check-syntax.mjs`, `node scripts/sync-core.mjs --check`. Tout doit passer.
4. **Numéros de version (FOU-44, vérifiés par la CI).** Toute PR qui change `index.html` lance `npm run version` (met `const BUILD` à l'heure de Paris ; sinon les apps ne reçoivent pas la mise à jour). Toute PR qui change la coque (`ios/Zieuton/`, `ios/Zieuton.xcodeproj/`) augmente `CURRENT_PROJECT_VERSION` de 1 (Debug et Release) ; en même temps, si la page doit savoir ce que la coque sait faire, augmente aussi `ZYEUTO_APP.version`. Une PR qui ne change que des tests, la doc ou `channel.json` n'y touche pas. La case « Numéros de version » de la CI échoue sinon (`node scripts/check-versions.mjs origin/main` pour la lancer chez toi).
5. Précise toujours dans la PR si **Xcode est nécessaire** (changement de la coque Swift = nouveau build TestFlight) ou non (changement de la page = en ligne tout de suite).
6. Écris la description de PR en français simple, pour quelqu'un qui n'est pas développeur : ce qui change pour l'utilisateur, comment le vérifier.
7. Reste dans le périmètre du ticket. Pas de refonte « au passage ».
8. Ne laisse pas d'erreur muette : pas de nouveau `catch {}` vide.
9. **Canaux de mise à jour (FOU-28, détails dans `docs/MISES-A-JOUR.md`).** Toute PR qui change la page incrémente `BUILD` ; elle n'arrive qu'aux iPhones en canal test. Pour la donner à tout le monde : après validation de Victor sur son iPhone, PR séparée avec `npm run canal -- valider` (cite le même ticket). Ne jamais retirer le message `started` de la fin du démarrage de `index.html`. Urgence : `npm run canal -- urgence on`.

## Interdits (promesses de l'app)

- Aucun scraping, aucune connexion automatisée à Instagram, jamais demander le mot de passe Instagram.
- Ne jamais toucher « Télécharger » à la place de l'utilisateur dans Instagram.
- Aucun envoi de données utilisateur vers un serveur (pas d'analytics, pas de SDK tiers) sans décision écrite de Victor.
- Aucune mention de Claude ou d'IA dans l'app ni dans les textes visibles.
- Ne change pas les identifiants techniques : `fr.zyeuto.app`, `fr.zyeuto.plus.*`, `fr.zyeuto.plus2.*`, `fr.zyeuto.plus3.*` (ancien nom gardé exprès).

## Style

- Textes de l'app en français, tutoiement, ton chaleureux et court.
- Palette rose poudré. L'or est réservé à Zieuton Plus ; ailleurs, lilas ou corail.
- Chaque écran doit marcher en clair et en sombre.
- Nom de l'app : **Zieuton** (avec un I). Le personnage : le zieuteur (toujours au masculin).
- Quand une icône change, renomme le fichier (cache iOS).

## Tests

- `npm test` : tests Node de l'import et de la comparaison (`tests/`), avec des exports d'exemple dans `tests/fixtures/`.
- `npm run check:page` : ouvre la page dans Playwright et échoue s'il y a une erreur dans la console.
- GitHub Actions (`.github/workflows/verifications.yml`) relance tout à chaque PR, plus la compilation Xcode sans signature.
- Ajoute un test à chaque bug corrigé dans l'import ou la comparaison.
