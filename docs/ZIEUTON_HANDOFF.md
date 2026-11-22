# Zieuton : document de transmission pour ChatGPT

> Dernière mise à jour : 23 novembre 2026, nuit (audit Linear de Victor et ChatGPT ; base créée par FOU-123). **À coller tel quel au début d'une conversation ChatGPT**, ou à lui faire lire sur GitHub (`docs/ZIEUTON_HANDOFF.md` du dépôt Vic-tard/abo-insta). Ce document se suffit à lui-même : ChatGPT n'a pas accès aux conversations Claude ni à leurs fichiers.
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

## 5. Où en est le projet (23 nov., d'après Linear)

**Planning du projet « Zieuton 1.0 »** (décision de Victor du 22 nov. : tout décalé de 10 jours) :
- **Build validé** : 2 déc. ;
- **Soumission à Apple** : 5 déc. ;
- **Sortie sur l'App Store** : 15 déc., avec publication manuelle.

Rien n'est soumis sans l'accord explicite de Victor.

**Build candidat : 1.0 (23)**, installé chez Victor. Historique des builds :
- 15 : export P1 à P6 ;
- 17 : notifications, non validé ;
- 21 : correctifs du 18 nov. ;
- 22 : sécurité du suivi ;
- 23 : bandeau « Un fichier est disponible ».

Un build 24 ne se fera que si la coque doit changer.

**Canal stable** : page du 21 nov. (2026-11-21-1638), promue le 22 nov. (PR #159). La PR #160, fusionnée le 22 nov., n'y est **pas** : elle est en canal test seulement. Son passage en stable demandera une promotion séparée, après les tests sur iPhone et l'accord de Victor.

### Tickets (Linear fait foi)

| Ticket | Sujet | Statut | Échéance | Remarque |
| --- | --- | --- | --- | --- |
| FOU-131 | Écrans après la demande d'export | Done | – | « Done » vaut pour le code fusionné (#152, #157). Les tests UX réels restants sont suivis dans FOU-105. La PR #160 (démo pendant l'attente) a été **fusionnée le 22 nov. à 23 h 37** (commit 33ce02e, page 2026-11-22-2329), avec la correction demandée : « Mon export » ramène à l'écran B ou E sans ouvrir Instagram, et le balayage est bloqué pendant les bulles. Elle est en canal test seulement. Ses tests sur iPhone (U11 à U14) restent à faire dans FOU-105. |
| FOU-129 | Canal stable | Done | – | Promotion du 22 nov. seulement. |
| FOU-126 | Notifications fiables | Done | – | Lignes restantes de la matrice suivies dans FOU-105. |
| FOU-105 | Valider le build final sur iPhone | In Progress | 2 déc. | Restent : transitions UX (dont #160), notifications, non-régression, iCloud, compte 2, parcours de l'examinateur Apple. Bloque FOU-130. |
| FOU-128 | Achats et restauration (sandbox) | Todo | 4 déc. | En parallèle de FOU-105, avant la soumission. |
| FOU-82 | Médiateur de la consommation | Todo | 4 déc. | Avant la soumission. |
| FOU-130 | Soumission à Apple, publication manuelle | In Progress (depuis le 23 nov., 0 h 18) | 5 déc. | Ticket de soumission officiel. FOU-51 a été classé doublon. Statut lu dans Linear le 23 nov. ; « In Progress » veut dire que la préparation a commencé, rien n'est soumis. La soumission reste bloquée par FOU-105 et demande l'accord de Victor. |
| FOU-83 | ACRE | In Progress | 18 déc. | Documents de l'Urssaf reçus le 21 nov. |
| FOU-116 | Essai Higgsfield | Done | – | Cinq vidéos livrées. **Résiliation du renouvellement non confirmée** : à vérifier sur le compte Higgsfield. |

**Backlog** (gelé ou après la sortie) :
- com : FOU-56 calendrier du 1er au 29 déc., FOU-59, FOU-60, FOU-63 annonce le 15 déc. ;
- FOU-119 (3D) et le village ;
- FOU-41 et FOU-55 (technique, après la sortie).

Les dates exactes sont dans Linear.

## 6. Prochaines étapes, dans l'ordre

1. PR #160 (déjà fusionnée le 22 nov., en canal test) : tests sur iPhone U11 à U14, consignés dans FOU-105. Ensuite seulement, et avec l'accord de Victor, une PR séparée la passe en canal stable.
2. FOU-105 : tests restants sur le build 23, à consigner.
3. FOU-128 : achats en sandbox, avant le 4 déc.
4. FOU-82 : médiateur, avant le 4 déc.
5. FOU-83 : demande d'ACRE.
6. FOU-130 (In Progress) : soumission le 5 déc., sortie le 15 déc., avec l'accord de Victor.

Garde-fous : aucune fusion, aucun build, aucun passage en stable et aucune soumission sans l'accord explicite de Victor.

## 7. Bugs et risques ouverts (détail : `docs/ZIEUTON_BUG_TRACKER.md`)

- **Cas V2 du build 21** : une vraie demande a été vue « à vérifier ». Cause non démontrée (piste : une demande du même jour lue avant la touche). L'écran D reste le repli honnête.
- **Risque Apple 5.2.2** (vue Instagram intégrée) : plan B en réserve (`PLAN-B-APPLE-5-2-2.md`, FOU-33).
- **Compte testeur verrouillé** : cause non prouvée.
- **Lien du questionnaire testeurs** : c'est un lien d'édition.

## 8. Questions où un second avis serait utile

1. **PR #160** (fusionnée, canal test) : après les tests sur iPhone, la passe-t-on en canal stable avant la soumission ?
2. **Build 23 comme build final** : quelles lignes de la matrice sont indispensables avant de soumettre ?
3. **Risque 5.2.2** : faut-il une réponse prête pour l'examinateur ?
4. **Lancement** : quel minimum de com, avec la sortie au 15 déc. ?

## 9. Où trouver le reste

Côté Claude, Victor travaille dans trois fils : « 00 — TABLEAU DE BORD ZIEUTON », « 01 — EXPORT INSTAGRAM », « 02 — LANCEMENT APP STORE ».


Dépôt Vic-tard/abo-insta, dossier `docs/` : `ZIEUTON_MASTER_CONTEXT.md` (vue d'ensemble), `ZIEUTON_ROADMAP.md`, `ZIEUTON_DECISIONS.md`, `ZIEUTON_UX_RESEARCH.md`, `ZIEUTON_BUSINESS.md`, `ZIEUTON_CHANGELOG.md`, `SPEC.md`. Linear : équipe FOU, projet « Zieuton 1.0 ».
