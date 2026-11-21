# Zieuton : document de transmission pour ChatGPT

> Dernière mise à jour : 21 novembre 2026, soir (ménage Linear et GitHub ; base créée par FOU-123). **À coller tel quel au début d'une conversation ChatGPT**, ou à lui faire lire sur GitHub (`docs/ZIEUTON_HANDOFF.md` du dépôt Vic-tard/abo-insta). Ce document se suffit à lui-même : ChatGPT n'a pas accès aux conversations Claude ni à leurs fichiers.
> À mettre à jour par Claude après chaque étape importante (fin de PR, décision, build).

## 1. Le projet en 10 lignes

Zieuton est une app iPhone (français, iOS 17+) qui montre qui s'est désabonné d'un compte Instagram, en comparant les exports officiels que l'utilisateur demande lui-même à Instagram. Pas de serveur, pas de compte, jamais de mot de passe : tout reste sur le téléphone (+ sauvegarde iCloud). Modèle : gratuit (2 imports, puis 1 par mois) + Zieuton Plus (2,99 €/mois, 14,99 €/an, 29,99 € à vie). Propriétaire : Victor, seul, non développeur, micro-entreprise. Sortie visée sur l'App Store : 3 décembre 2026. Build candidat actuel : 1.0 (23) sur TestFlight.

Architecture : une page web unique `index.html` (~8 600 lignes, HTML/CSS/JS sans build) embarquée dans une coque Swift (`ios/Zieuton/WebViewController.swift`, ~3 100 lignes, WKWebView). La page se met à jour depuis zieuton.com (signée, canal test puis stable) ; la coque demande un build Xcode. Tests Node + CI GitHub.

## 2. Qui fait foi

- **Linear** (équipe FOU, projet « Zieuton 1.0 ») : les tâches et leurs statuts.
- **GitHub** (Vic-tard/abo-insta) : le code, les PR, les numéros de version.
- **`docs/`** : les décisions, le contexte, les analyses. Ce qui est ancien ou non vérifié est marqué [Déduit] ou [Inconnu].

## 3. Rôles (règles officielles, `docs/COLLABORATION.md`)

- **Claude** écrit tout le code, ouvre les PR, tient la documentation.
- **ChatGPT** audite : relit les PR et commente sur GitHub, commente Linear. Il ne pousse rien, ne fusionne rien, ne change aucun statut Linear, ne crée aucun ticket sans l'accord de Victor.
- **Victor** décide. En cas de désaccord, il tranche.
- ChatGPT classe chaque remarque : **Bug confirmé** (preuve : étapes, fichier et ligne, capture) / **Risque potentiel** / **Recommandation**.

## 4. Promesses à ne jamais contredire

Pas de scraping ni de connexion automatisée à Instagram ; jamais le mot de passe ; l'utilisateur touche lui-même « Télécharger » ; aucune donnée envoyée à un serveur (pas d'analytics, pas de SDK) sans décision écrite de Victor ; aucune mention d'IA dans l'app ; identifiants `fr.zyeuto.*` intouchables.

## 5. Où en est le projet (21 nov. au soir)

- **Build candidat : 1.0 (23)**, installé chez Victor. Historique des builds :
  - 15 : export P1 à P6 ;
  - 17 : notifications, non validé ;
  - 21 : correctifs du 18 nov. ;
  - 22 : sécurité du suivi ;
  - 23 : bandeau « Un fichier est disponible ».

  Aucun nouveau build n'est prévu tant que la coque ne change pas.
- **Fusionné le 21 nov.** :
  - #151 : test ;
  - #152 : FOU-131 PR 1, écrans A, B, D, E et frise ;
  - #153 : la démo ne fait plus oublier la demande ;
  - #154 et #155 : sécurité du suivi, build 22 ;
  - #156 : build 23 ;
  - #157 : « Est-ce bien le fichier de ta demande ? ».

  La page de ces PR est en canal test seulement. Vidéo de Victor à 16 h 48 : export réel, import de 1 140 abonnés, réponse « Oui », rappels retirés, accueil et données intacts après la réouverture. Ce scénario est validé, pas tous les cas.
- **FOU-126** (notifications) : « Done ». Les lignes restantes de la matrice `VALIDATION-BUILD-21.md` (V2, V7, V9 à V17) sont suivies dans **FOU-105**.
- **FOU-131** (écrans après la demande) : rouvert « In Progress ». Il reste l'audit des transitions, puis la PR 2 (démo : bulles du zieuteur, « Mon export ») si nécessaire, puis les tests U1 à U10.
- **Canal stable** toujours au 10 nov. (FOU-129, à faire avant la soumission).
- **ACRE (FOU-83)** : documents de l'Urssaf reçus le 21 nov., demande à remplir le 22 nov. Dépôt visé avant le 18 déc.
- **Ménage du 21 nov.** :
  - FOU-127 (« build 20 ») annulé comme obsolète.
  - FOU-132 créé par erreur, puis annulé comme doublon de FOU-119.
  - FOU-116 (Higgsfield, com gelée) passé en Backlog.
  - FOU-119 (visuels 3D) passé en Todo pour le 22 nov.
  - Aucune PR ouverte.
  - Les branches déjà fusionnées sont listées dans `scripts/branches-a-supprimer.txt`.
- **Jalons Linear** : Build validé (22 nov., en pratique le 23), Soumis à Apple (25 nov.), Sortie (3 déc.).

## 6. Plan du 22 novembre

1. **FOU-131** : auditer toutes les transitions sur pages simulées, sans nouvelle demande Instagram. Les transitions sont : A → B → démo → B → E → import → question → accueil, et D sans fausse validation. Une seule revue des défauts, puis la PR 2 (page seule) si nécessaire.
2. **FOU-119** : 3 directions du zieuteur 3D, toujours derrière un mur, palette rose, lilas et corail. Aucune intégration dans l'app avant la soumission.
3. **FOU-83** : lire les documents de l'Urssaf et préparer la demande d'ACRE.
4. Ensuite (23 et 24 nov.) :
   - FOU-105 : lignes restantes sur le build 23 ;
   - FOU-128 : achats en sandbox ;
   - FOU-82 : médiateur ;
   - FOU-129 : canal stable.

   Puis FOU-130 : soumission le 25 nov.

Garde-fous : aucune fusion, aucun build, aucun passage en stable et aucune soumission sans l'accord explicite de Victor.

## 7. Bugs et risques ouverts (détail : `docs/ZIEUTON_BUG_TRACKER.md`)

- **Cas V2 du build 21** : une vraie demande a été vue « à vérifier ». Cause non démontrée (piste : une demande du même jour lue avant la touche). L'écran D reste le repli honnête.
- **Risque Apple 5.2.2** (vue Instagram intégrée) : plan B en réserve (`PLAN-B-APPLE-5-2-2.md`, FOU-33).
- **Compte testeur verrouillé** : cause non prouvée.
- **Lien du questionnaire testeurs** : c'est un lien d'édition.

## 8. Questions où un second avis serait utile

1. **FOU-131** : la liste des transitions à auditer est-elle complète ? La PR 2 (bulles dans la démo) vaut-elle le risque avant la soumission ?
2. **Build 23 comme build final** : quelles lignes de la matrice sont indispensables avant de soumettre ?
3. **Risque 5.2.2** : faut-il une réponse prête pour l'examinateur ?
4. **Lancement** : quel minimum de com, avec la sortie au 3 déc. ?

## 9. Où trouver le reste

Côté Claude, Victor travaille dans trois fils : « 00 — TABLEAU DE BORD ZIEUTON », « 01 — EXPORT INSTAGRAM », « 02 — LANCEMENT APP STORE ».


Dépôt Vic-tard/abo-insta, dossier `docs/` : `ZIEUTON_MASTER_CONTEXT.md` (vue d'ensemble), `ZIEUTON_ROADMAP.md`, `ZIEUTON_DECISIONS.md`, `ZIEUTON_UX_RESEARCH.md`, `ZIEUTON_BUSINESS.md`, `ZIEUTON_CHANGELOG.md`, `SPEC.md`. Linear : équipe FOU, projet « Zieuton 1.0 ».
