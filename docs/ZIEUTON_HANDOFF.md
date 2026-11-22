# Zieuton : document de transmission pour ChatGPT

> Dernière mise à jour : 22 novembre 2026, soir (nouveau planning : sortie le 15 décembre ; base créée par FOU-123). **À coller tel quel au début d'une conversation ChatGPT**, ou à lui faire lire sur GitHub (`docs/ZIEUTON_HANDOFF.md` du dépôt Vic-tard/abo-insta). Ce document se suffit à lui-même : ChatGPT n'a pas accès aux conversations Claude ni à leurs fichiers.
> À mettre à jour par Claude après chaque étape importante (fin de PR, décision, build).

## 1. Le projet en 10 lignes

Zieuton est une app iPhone (français, iOS 17+) qui montre qui s'est désabonné d'un compte Instagram, en comparant les exports officiels que l'utilisateur demande lui-même à Instagram. Pas de serveur, pas de compte, jamais de mot de passe : tout reste sur le téléphone (+ sauvegarde iCloud). Modèle : gratuit (2 imports, puis 1 par mois) + Zieuton Plus (2,99 €/mois, 14,99 €/an, 29,99 € à vie). Propriétaire : Victor, seul, non développeur, micro-entreprise. Sortie visée sur l'App Store : **15 décembre 2026** (décalée de 10 jours le 22 nov.). Build candidat actuel : 1.0 (23) sur TestFlight.

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

## 5. Où en est le projet (22 nov. au soir)

- **Nouveau planning (Victor, 22 nov.) : tout décalé de 10 jours.**
  - Build validé : 2 déc.
  - Soumission à Apple : 5 déc. (FOU-130, publication manuelle).
  - Sortie sur l'App Store : **15 déc.**
  - Les jalons Linear sont à ces dates.
- **Build candidat : 1.0 (23)**, installé chez Victor. Historique des builds :
  - 15 : export P1 à P6 ;
  - 17 : notifications, non validé ;
  - 21 : correctifs du 18 nov. ;
  - 22 : sécurité du suivi ;
  - 23 : bandeau « Un fichier est disponible ».

  Aucun nouveau build n'est prévu tant que la coque ne change pas.
- **Canal stable** : page du 21 nov. (2026-11-21-1638), validée par Victor sur son iPhone. PR #159 fusionnée le 22 nov. (FOU-129 terminé).
- **FOU-131** (écrans après la demande d'export) : la PR 1 (#152) et la question après l'import (#157) sont fusionnées. La **PR 2 (#160)** est ouverte, page seule, à relire. Elle porte sur la démo pendant l'attente : bandeau « DÉMO · Données d'exemple », bouton « Mon export », visite du zieuteur en 4 bulles affichée une seule fois. Après validation, il faudra repasser cette page en canal stable.
- **FOU-126** (notifications) : terminé. Les lignes restantes de la matrice `VALIDATION-BUILD-21.md` sont suivies dans **FOU-105** (validation du build final).
- **Linear au 22 nov.** (ChatGPT a classé FOU-51 en doublon de FOU-130, qui est le ticket de soumission) :
  - **En cours** : FOU-131, FOU-105, FOU-83 (ACRE, documents de l'Urssaf reçus le 21 nov., dépôt avant le 18 déc.).
  - **À faire** : FOU-128 achats (2 déc.), FOU-82 médiateur (4 déc.), FOU-130 soumission (5 déc.).
  - **Backlog** : com, 3D (FOU-119), village, et tout ce qui vient après la sortie.
- Com, 3D et village restent **gelés**.

## 6. Prochaines étapes, dans l'ordre

1. Relire et valider la PR #160 (FOU-131 PR 2), test iPhone en canal test, fusion, puis canal stable.
2. FOU-83 : préparer la demande d'ACRE avec les documents de l'Urssaf.
3. FOU-105 : lignes restantes de la matrice sur le build 23, et le parcours de l'examinateur Apple.
4. FOU-128 : achats et restauration en sandbox.
5. FOU-82 : adhérer à un médiateur et l'ajouter aux textes légaux.
6. FOU-130 : soumission le 5 déc., publication manuelle le 15 déc.

Garde-fous : aucune fusion, aucun build, aucun passage en stable et aucune soumission sans l'accord explicite de Victor.

## 7. Bugs et risques ouverts (détail : `docs/ZIEUTON_BUG_TRACKER.md`)

- **Cas V2 du build 21** : une vraie demande a été vue « à vérifier ». Cause non démontrée (piste : une demande du même jour lue avant la touche). L'écran D reste le repli honnête.
- **Risque Apple 5.2.2** (vue Instagram intégrée) : plan B en réserve (`PLAN-B-APPLE-5-2-2.md`, FOU-33).
- **Compte testeur verrouillé** : cause non prouvée.
- **Lien du questionnaire testeurs** : c'est un lien d'édition.

## 8. Questions où un second avis serait utile

1. **FOU-131 PR 2 (#160)** : la visite en bulles et le bouton « Mon export » sont-ils sûrs avant la soumission ?
2. **Build 23 comme build final** : quelles lignes de la matrice sont indispensables avant de soumettre ?
3. **Risque 5.2.2** : faut-il une réponse prête pour l'examinateur ?
4. **Lancement** : quel minimum de com, avec la sortie au 15 déc. ?

## 9. Où trouver le reste

Côté Claude, Victor travaille dans trois fils : « 00 — TABLEAU DE BORD ZIEUTON », « 01 — EXPORT INSTAGRAM », « 02 — LANCEMENT APP STORE ».


Dépôt Vic-tard/abo-insta, dossier `docs/` : `ZIEUTON_MASTER_CONTEXT.md` (vue d'ensemble), `ZIEUTON_ROADMAP.md`, `ZIEUTON_DECISIONS.md`, `ZIEUTON_UX_RESEARCH.md`, `ZIEUTON_BUSINESS.md`, `ZIEUTON_CHANGELOG.md`, `SPEC.md`. Linear : équipe FOU, projet « Zieuton 1.0 ».
