# Zieuton : document de transmission pour ChatGPT

> Dernière mise à jour : 16 novembre 2026 (FOU-123). **À coller tel quel au début d'une conversation ChatGPT**, ou à lui faire lire sur GitHub (`docs/ZIEUTON_HANDOFF.md` du dépôt Vic-tard/abo-insta). Ce document se suffit à lui-même : ChatGPT n'a pas accès aux conversations Claude ni à leurs fichiers.
> À mettre à jour par Claude après chaque étape importante (fin de PR, décision, build).

## 1. Le projet en 10 lignes

Zieuton est une app iPhone (français, iOS 17+) qui montre qui s'est désabonné d'un compte Instagram, en comparant les exports officiels que l'utilisateur demande lui-même à Instagram. Pas de serveur, pas de compte, jamais de mot de passe : tout reste sur le téléphone (+ sauvegarde iCloud). Modèle : gratuit (2 imports, puis 1 par mois) + Zieuton Plus (2,99 €/mois, 14,99 €/an, 29,99 € à vie). Propriétaire : Victor, seul, non développeur, micro-entreprise. Sortie visée sur l'App Store : 3 décembre 2026. App en test sur TestFlight auprès d'amis (build 1.0 (7)).

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

## 5. Priorité actuelle : l'export Instagram (ticket FOU-121)

Récupérer l'export doit être simple et fiable. Plan validé par Victor et ChatGPT le 16 nov. :
- **P1 (PR #132 ouverte, à relire)** : une étape n'avance que sur une preuve visible ; « C'est bon » seulement après vérification fiable ; une demande n'est confirmée que par une nouvelle ligne « En attente » dans la liste d'Instagram ; jamais de nouvelle demande à la place de l'utilisateur (après 20 s, proposer « Vérifier l'état de ma demande ») ; **compte verrouillé** seulement sur un signal explicite → arrêt et renvoi vers l'app Instagram officielle, texte neutre.
- **P2 à P6** : à faire ensuite (présentation du bandeau, 4 phases, erreurs douces, petits iPhone et clavier ouvert, chemin de secours par l'app Instagram).
- Une PR à la fois. Aucun build Xcode ni fusion sans l'accord de Victor.
- **Après P1** (liste de Victor) : vérifier le parcours de démo pour Apple ; aligner les statuts Linear sur le travail réel ; fixer le minimum avant soumission ; tester le canal stable et les parcours sur les iPhone des testeurs ; revoir le calendrier. Pas de changement de statut Linear ni de nouvelle PR technique sans l'accord de Victor.

## 6. Bugs non résolus (détail : `docs/ZIEUTON_BUG_TRACKER.md`)

- Bandeau qui demande le mot de passe à tort ; « récupère ton fichier » sur une fenêtre blanche ; « touche Télécharger » hors écran ; demande en « Année dernière » non détectée (régression) ; conseils coupés après 2 lignes.
- Un testeur a eu son compte verrouillé (cause non prouvée).
- La note pour l'examinateur Apple décrit peut-être un chemin de démo qui n'existe plus (à vérifier).
- Le lien du questionnaire testeurs est un lien d'édition (lien public à récupérer).

## 7. État du lancement

Fiche App Store, captures, achats, confidentialité : prêts. Reste : export fiable → build final → test par un inconnu → soumission (prévue « vers le 20 nov. », probablement à décaler) → sortie le 3 déc. Toute la com est gelée.

## 8. Questions où un second avis serait utile

1. **Date** : faut-il décaler la soumission ou la sortie du 3 décembre pour finir P1 à P6 ? Quel minimum avant soumission ?
2. **Risque Apple 5.2.2** : la vue Instagram intégrée est le risque de refus n°1. Faut-il préparer le plan B (FOU-33, ex. ouvrir Instagram hors de l'app) avant de soumettre ?
3. **Compte verrouillé** : quels signaux d'Instagram sont assez explicites pour dire « verrouillé » sans confondre avec un simple code de sécurité ?
4. **Test utilisateur** : comment organiser un test « inconnu, sans aide » (FOU-37) utile en peu de temps ?
5. **Lancement** : la com gelée peut-elle encore tenir le 3 décembre ? Quel minimum (comptes, 3 vidéos, 10 créateurs) ?
6. **Prix** : 2,99 €/mois et 29,99 € à vie sont-ils cohérents avec les concurrents (FollowMeter, FANS, Unfollr, Reports+) ?

## 9. Où trouver le reste

Côté Claude, Victor travaille dans trois fils : « 00 — TABLEAU DE BORD ZIEUTON », « 01 — EXPORT INSTAGRAM », « 02 — LANCEMENT APP STORE ».


Dépôt Vic-tard/abo-insta, dossier `docs/` : `ZIEUTON_MASTER_CONTEXT.md` (vue d'ensemble), `ZIEUTON_ROADMAP.md`, `ZIEUTON_DECISIONS.md`, `ZIEUTON_UX_RESEARCH.md`, `ZIEUTON_BUSINESS.md`, `ZIEUTON_CHANGELOG.md`, `SPEC.md`. Linear : équipe FOU, projet « Zieuton 1.0 ».
