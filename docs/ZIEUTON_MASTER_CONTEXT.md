# Zieuton : contexte de référence

> Dernière mise à jour : 23 novembre 2026 (base FOU-123). L'état au jour le jour est dans `ZIEUTON_HANDOFF.md`. À relire au début de toute nouvelle conversation.
> Légende : **[Confirmé]** = vu dans le dépôt, Linear ou une décision écrite de Victor. **[Déduit]** = recoupement raisonnable, à vérifier. **[Inconnu]** = information manquante.

Ce document résume le projet. Il ne remplace pas les documents existants, il pointe vers eux :

| Sujet | Document de référence |
| --- | --- |
| Ce que fait l'app et ce qu'elle ne fera pas | [`SPEC.md`](SPEC.md) (la spec gagne en cas de doute) |
| Règles de code pour Claude | [`../CLAUDE.md`](../CLAUDE.md) |
| Rôles Claude / ChatGPT / Victor | [`COLLABORATION.md`](COLLABORATION.md) |
| Mises à jour de la page, canaux, signature | [`MISES-A-JOUR.md`](MISES-A-JOUR.md) |
| Note pour l'examinateur Apple | [`note-revue-apple.md`](note-revue-apple.md) |
| Priorités et tâches | [`ZIEUTON_ROADMAP.md`](ZIEUTON_ROADMAP.md) |
| Bugs | [`ZIEUTON_BUG_TRACKER.md`](ZIEUTON_BUG_TRACKER.md) |
| Décisions | [`ZIEUTON_DECISIONS.md`](ZIEUTON_DECISIONS.md) |
| Expérience utilisateur et tests | [`ZIEUTON_UX_RESEARCH.md`](ZIEUTON_UX_RESEARCH.md) |
| Business, prix, com | [`ZIEUTON_BUSINESS.md`](ZIEUTON_BUSINESS.md) |
| Historique des changements | [`ZIEUTON_CHANGELOG.md`](ZIEUTON_CHANGELOG.md) |
| Résumé à donner à ChatGPT | [`ZIEUTON_HANDOFF.md`](ZIEUTON_HANDOFF.md) |
| Audit du 16 nov., risques, rangement des fils | [`ZIEUTON_AUDIT_2026-11-16.md`](ZIEUTON_AUDIT_2026-11-16.md) |

## 0. Qui fait foi

**[Confirmé, Victor, 16 nov.]**
- **Linear** est la référence pour les tâches et leurs statuts.
- **GitHub** est la référence pour le code, les PR et les numéros de version.
- **Ces documents** gardent les décisions, le contexte et les analyses. En cas d'écart avec Linear ou GitHub, ce sont eux qui ont raison et on corrige le document.
- Les informations anciennes ou non vérifiées restent marquées [Déduit] ou [Inconnu].

## Où on parle de quoi (fils du projet Claude)

**[Confirmé, Victor, 16 nov.]** Trois fils de travail seulement : **00 — TABLEAU DE BORD ZIEUTON** (point d'entrée, synthèse, administratif), **01 — EXPORT INSTAGRAM** (FOU-121), **02 — LANCEMENT APP STORE** (build, soumission, sortie). Pas de nouveau fil sans demande de Victor.

## 1. Présentation

**[Confirmé]** Zieuton est une app iPhone qui montre à une personne qui s'est désabonnée de son compte Instagram (et qui l'a rejoint), en comparant les exports officiels de ses données Instagram. Aucune connexion automatisée, aucun serveur, aucun compte Zieuton : tout reste sur le téléphone, avec une sauvegarde dans l'iCloud de l'utilisateur.

- Nom : **Zieuton** (avec un I). Ancien nom « Zyeuto », encore présent dans les identifiants techniques (`fr.zyeuto.app`, `fr.zyeuto.plus*`), gardés exprès. Nom de travail initial : « Abo Insta ».
- Mascotte : le zieuteur (masculin), toujours dessiné derrière un mur.
- Propriétaire : Victor Fourneret, entreprise individuelle (micro-entreprise), nom commercial Zieuton, immatriculée le 5 nov. 2026. Victor n'est pas développeur ; il valide chaque changement.
- Début du projet : 26 oct. 2026 (premier fil « Build Instagram unfollow tracker »).

## 2. Problème résolu et proposition de valeur

**[Confirmé]** Instagram ne dit pas qui se désabonne. Concurrents repérés : FollowMeter, FANS, Unfollr, « Reports+ ». **[Déduit]** Une partie de ces apps se connecte au compte ou demande le mot de passe, ce qui expose à des restrictions d’Instagram (détail par concurrent non revérifié).

Proposition de valeur de Zieuton :
1. **Zéro risque pour le compte** : uniquement l'export officiel, jamais le mot de passe.
2. **Rien ne quitte le téléphone** (hors iCloud de l'utilisateur).
3. **Simple et ludique** : guide pas à pas dans Instagram, puis listes, graphiques et jeux.

**[Confirmé, 16 nov.]** Priorité unique de Victor : **l'export**. « Le récupérer simplement et correctement, c'est ce que je veux vendre. »

## 3. Public cible

**[Confirmé, SPEC]** Utilisateurs Instagram francophones de 16 à 35 ans ; en second, petits créateurs et micro-influenceurs. iPhone uniquement (iOS 17+). Pays de vente : France, Belgique, Suisse, Luxembourg, Canada.

## 4. Fonctionnalités existantes (dans le code de `main`)

**[Confirmé]** sauf mention contraire. Détail dans `SPEC.md` §4.

| Bloc | État |
| --- | --- |
| Import `followers_1.json` / `following.json` / `.zip`, comparaison, refus des exports partiels, d'un autre compte, plus anciens, HTML | Fait, couvert par `npm test` |
| Guide du premier export : vue Instagram dans l'app + bandeau qui lit l'écran | Fait, **en refonte (FOU-121, P1 à P6)** : bugs encore vus chez les testeurs |
| Notifications « demande envoyée » / « fichier prêt » | Fait ; fiabilité limitée par iOS quand l'app est fermée |
| Accueil (4 cases), listes, recherche, graphiques à dérouler, Mes records | Fait |
| Jeux : niveaux, zieuteur, roue, pronostics, mini-jeux, trophées, village du zieuteur | Fait (village en canal stable depuis le 12 nov.) |
| Multi-comptes (3 max), un Plus par compte | Fait |
| Zieuton Plus : 9 achats StoreKit 2 | Fait, testé en sandbox sur le build 3 seulement |
| Sauvegarde iCloud auto + fichier `.zieuton` scellé | Fait |
| Mode démo | Fait (accès : Réglages → « Voir la démo ») |
| Réglages, Aide, Confidentialité, « Envoyer un rapport » (journal d'erreurs local) | Fait |
| Mises à jour de la page signées, canal test / stable, retour automatique | Fait |

Non commencé ou en attente : Android, version anglaise, accessibilité, découpage du code, builds automatiques (voir la roadmap).

## 5. Architecture technique

**[Confirmé]** (dépôt au 16 nov. 2026)

- `index.html` : toute l'interface et la logique (HTML + CSS + JS, **8 593 lignes**, sans étape de construction). Embarqué dans l'app et mis à jour depuis le site.
- `js/zieuton-core.js` (297 lignes) : lecture des exports et comparaison, recopié dans `index.html` par `node scripts/sync-core.mjs`.
- `ios/Zieuton/` : coque Swift (UIKit + WKWebView). `WebViewController.swift` (**3 129 lignes**) contient la page, le pont, les mises à jour, la vue Instagram et son bandeau, les notifications, StoreKit et iCloud.
- Pont page ⇄ coque : `window.webkit.messageHandlers.zyeuto`, réponses via `window.zyeutoMeta`, `window.zyeutoICloud`… `window.ZYEUTO_APP.version` = **9** aujourd'hui.
- Données : IndexedDB (principal) + localStorage (copie), un état par compte (`acct:<id>`), réglages dans `abo-prefs`. Origine des données : `vic-tard.github.io` (à ne jamais changer, sinon les données locales sont perdues).
- Hébergement de la page : **zieuton.com** (Cloudflare Pages, principal) + GitHub Pages (secours). Publication par GitHub Actions (`publier.yml`), page signée avec une clé privée (secret `PAGE_SIGNING_KEY`).
- Canaux : `channel.json` → `stable` = `2026-11-10-1618`. La page de `main` a `BUILD = 2026-11-16-0338` : **tout ce qui a été fusionné depuis le 10 nov. n'est visible qu'en canal test** tant qu'une PR « canal valider » n'est pas fusionnée.
- Numéros : `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 10` dans `main`. Dernier build envoyé sur TestFlight : **1.0 (7)**, le 15 nov.
- Vérifications automatiques (`verifications.yml`) : syntaxe, copie du cœur, tests d'import, console de la page (Playwright), numéros de version, compilation Xcode sans signature.

## 6. Contraintes importantes

**[Confirmé]**
- Interdits : scraping, connexion automatisée, mot de passe Instagram, toucher « Télécharger » à la place de l'utilisateur, envoyer des données à un serveur, mentionner Claude ou l'IA dans l'app.
- Apple : règles 5.2.2 (service tiers dans une vue web), 2.5.2 (code téléchargé), 3.1.1 (achats). Risque principal de refus : la vue Instagram intégrée (plan B = FOU-33, non fait).
- Une PR par tâche, jamais de push sur `main`, Victor fusionne ou demande la fusion. ChatGPT relit, ne pousse rien.
- Toute modif de coque = nouveau build Xcode fait par Victor sur son Mac (débutant). Victor ne veut qu'**un seul build** quand il est satisfait.
- Style : français, tutoiement, rose poudré ; or réservé à Zieuton Plus ; clair et sombre.

## 7. État général (16 nov. 2026)

- **[Confirmé]** Build candidat **1.0 (23)** sur TestFlight (23 nov.). Avant lui, le build 1.0 (7) avait été testé par des amis (groupe « TEST ZIEUTON POTES », 50 places). Leurs retours ont montré que l'export restait difficile (connexion, alerte « appareil non reconnu », réglages, un compte verrouillé).
- **[Confirmé]** Export fiabilisé : P1 à P6 (FOU-121, 16 nov.), notifications fiables (FOU-126), écrans après la demande (FOU-131). Canal stable = page du 21 nov. Validation finale en cours (FOU-105).
- **[Confirmé]** Gelé : com, zieuteur 3D, village (améliorations).
- **[Confirmé]** Fiche App Store remplie, captures déposées, achats créés, App Privacy « Données non collectées ».

## 8. Objectifs à court terme

1. Valider le build 23 sur iPhone (FOU-105), les achats (FOU-128) et le médiateur (FOU-82).
2. Soumettre à Apple le **5 décembre** (FOU-130), avec publication manuelle.
3. Sortie sur l'App Store le **15 décembre 2026**. Le planning a été décalé de 10 jours le 22 nov. ; l'ancienne date était le 3 déc.

## 9. Liens et références

- Dépôt : https://github.com/Vic-tard/abo-insta (branche `main`)
- Site : https://zieuton.com (secours https://vic-tard.github.io/abo-insta/), page testeurs https://zieuton.com/potes
- Linear : équipe FOU, projet « Zieuton 1.0 »
- Diagnostic export (16 nov.) : https://claude.ai/artifact/EoLTde9KQffLq2JGBuwqkj
- Bilan d'architecture (6 nov.) : https://claude.ai/artifact/SqrsfMSSgRtY8eHx6a1CfA
- Récap « ce qu'on attend encore » : https://claude.ai/artifact/QpXL1UHCUrnmsh9rF9tuyh
- Fiche App Store : https://claude.ai/artifact/9W4g4seDyUh96k4oacqtK1
- Fichiers de travail (maquettes, captures, vidéos) : dossier partagé du projet Claude `abo-insta/` (non accessible à ChatGPT)
