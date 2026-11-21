# Zieuton : roadmap

> Dernière mise à jour : 21 novembre 2026, soir (ménage Linear et GitHub demandé par Victor). Les statuts recopient Linear au 21 nov. Source de vérité des tâches : **Linear** (équipe FOU, projet « Zieuton 1.0 »). Ce document donne l'ordre et les dépendances ; en cas d'écart, Linear gagne, puis on corrige ce fichier.
> Statuts : **À faire** / **En cours** / **Bloqué** / **Terminé**. Une ligne = un ticket Linear quand il existe.

## 1. Priorités actuelles (dans l'ordre)

Règle de Victor : **un seul sujet à la fois**. Jalons Linear : **Build validé** 22 nov. (repoussé de fait au 23), **Soumis à Apple** 25 nov., **Sortie** 3 déc.

État au 21 nov. au soir :
- Build candidat **1.0 (23)**, installé chez Victor. Aucun build n'est prévu.
- Le canal stable est toujours au 10 nov.
- Aucune PR ouverte.

| # | Tâche | Ticket | Statut | Dépend de |
| --- | --- | --- | --- | --- |
| 1 | Écrans après la demande d'export. La PR 1 (#152) et les suites (#153 à #157) sont fusionnées. Il reste à **auditer toutes les transitions** (A → B → démo → B → E → import → question → accueil, plus l'écran D sans fausse validation). Ensuite, PR 2 (page seule, démo : bulles du zieuteur et « Mon export ») si les transitions restent incomplètes. Enfin, tests iPhone U1 à U10. | FOU-131 | En cours | – |
| 2 | Visuels du zieuteur 3D : 3 directions (face, trois-quarts, profil, 2 ou 3 expressions), toujours derrière un mur, lisibles sur petit écran en clair et en sombre. Aucune intégration dans l'app avant la soumission (FOU-125 reste reporté). | FOU-119 | À faire (22 nov.) | – |
| 3 | ACRE : lire les documents de l'Urssaf reçus le 21 nov., puis remplir et envoyer la demande | FOU-83 | En cours | – |
| 4 | Valider le build 23 sur iPhone : lignes restantes de `VALIDATION-BUILD-21.md` (V2, V7, V9 à V17) et parcours examinateur Apple | FOU-105 | En cours | 1 |
| 5 | Retester les achats et la restauration sur le build 23 (sandbox) | FOU-128 | À faire (23 nov.) | – |
| 6 | Médiateur de la consommation | FOU-82 | À faire (24 nov.) | – |
| 7 | Passer la page validée en canal stable (`npm run canal -- valider`) | FOU-129 | À faire (24 nov.) | 1, 4 |
| 8 | Soumettre le build validé à Apple, publication manuelle | FOU-130 (parent FOU-51) | À faire (25 nov.) | 4, 5, 6, 7 |
| 9 | Sortie le 3 décembre 2026 | FOU-51 | En cours | 8 |

Si un changement de coque redevient nécessaire, il faudra un build 24, seulement avec l'accord de Victor, puis refaire FOU-105.

## Plan du 22 novembre (après le travail de Victor)

1. **FOU-131, environ 1 h 30.**
   - Audit des transitions sur pages simulées, sans nouvelle demande Instagram réelle.
   - Une seule revue des défauts, à envoyer à Victor et ChatGPT.
   - Puis la PR 2 (page seule), si elle est nécessaire. Victor teste sur son iPhone en canal test.
2. **Visuels FOU-119, environ 1 h.** Planche de 3 directions dans `/mnt/project-files/abo-insta/zieuteur-3d/`. Victor choisit une direction, sans rien intégrer dans l'app.
3. **ACRE FOU-83, environ 30 min.** Victor envoie les documents de l'Urssaf. On les lit ensemble, puis on prépare la demande. Victor l'envoie lui-même.
4. **Si le temps le permet** : lignes restantes de FOU-105 sur le build 23, puis achats (FOU-128).

**Garde-fous** : aucune fusion, aucun build, aucun passage en stable et aucune soumission sans l'accord explicite de Victor. Le moteur d'export reste inchangé.

## 2. Démarches administratives

| Tâche | Ticket | Statut | Note |
| --- | --- | --- | --- |
| ACRE à l'URSSAF | FOU-83 | En cours | Documents de l'Urssaf reçus le 21 nov. ; demande à remplir le 22 nov. Objectif de dépôt : 18 décembre 2026 ; limite probable 2 janvier 2027 (60 jours après le début d'activité du 3 nov., à confirmer auprès de l'Urssaf). Voir `PROPOSITIONS-LINEAR-2026-11-16.md` |
| Médiateur de la consommation | FOU-82 | À faire (24 nov.) | Obligatoire pour vendre à des particuliers **[Déduit]**, à faire avant la sortie |
| Small Business Program Apple (15 %) | – | En cours | Demande envoyée le 4 nov., réponse non reçue à notre connaissance |
| Essai Higgsfield (vidéos) + résiliation immédiate | FOU-116 | Backlog (gelé) | Ne pas lancer sans Victor |

## 3. Fonctionnalités prévues après la sortie (Backlog)

| Tâche | Ticket | Priorité Linear |
| --- | --- | --- |
| Plan B si Apple refuse la vue Instagram intégrée | FOU-33 | Haute. Proposition du 16 nov. : plan en réserve, sans code avant la soumission (`PLAN-B-APPLE-5-2-2.md`) |
| Découper `index.html` en modules | FOU-41 | Haute |
| Découper `WebViewController.swift` | FOU-42 | Moyenne |
| Surveiller les changements d'Instagram | FOU-46 | Moyenne |
| Version anglaise | FOU-49 | Moyenne |
| Rapports de plantage anonymes (avec accord) | FOU-31 | Moyenne (décision écrite de Victor requise) |
| Demander une note App Store au bon moment | FOU-64 | Moyenne |
| v1.1 : plus d'infos tirées de l'export | FOU-114 | – |
| Améliorer le village | FOU-109 | – |
| Copie de secours pour 3 gros comptes | FOU-67 | Basse |
| Accessibilité (VoiceOver, grandes polices) | FOU-48 | Basse |
| Builds iPhone automatiques | FOU-55 | Basse |
| Orca + Claude Code sur le Mac | FOU-53 | Basse (après FOU-41) |
| Android | FOU-52 | Basse |
| Zieuteur vivant dans l'app (après la soumission) | FOU-125 | – |

## 4. Communication et lancement (tout en Backlog depuis le 10 nov., FOU-99)

FOU-56 calendrier J-14 à J+14, FOU-57 vidéos saison 1, FOU-58 vidéos « brainrot », FOU-59 comptes Instagram/TikTok, FOU-60 liste de 10 à 20 micro-influenceurs, FOU-61 kit influenceurs, FOU-63 annonce du 3 déc., FOU-65 suivi des résultats, FOU-66 site vitrine.

**[Déduit]** Si la sortie reste au 3 décembre, FOU-56, FOU-59 et FOU-60 devront démarrer au plus tard vers le 19 novembre (J-14). À arbitrer par Victor.

## 5. Dépendances clés

```
FOU-131 → validation build 23 (FOU-105) + achats (FOU-128) + médiateur (FOU-82) → canal stable (FOU-129) → soumission (FOU-130) → sortie 3 déc. (FOU-51)
Page fusionnée → test en canal test → PR « canal valider » → visible pour tous
FOU-41 (découpage) → FOU-53 (Orca)
```

## 6. Objectifs à moyen et long terme

- **[Confirmé]** Après la sortie : Android, version anglaise, site vitrine (SPEC §5).
- **[Confirmé, 28 oct.]** Vision longue : vendre l'app largement, notamment via des influenceurs.
- **[Inconnu]** Objectifs chiffrés (téléchargements, abonnés Plus, revenu) : jamais fixés par écrit. Les scénarios du business model (1er nov.) sont des hypothèses.

## 7. Terminé récemment (repère)

FOU-122 règles Claude/ChatGPT (16 nov.), FOU-118 plan clair avant Instagram (15 nov.), FOU-115 code de sécurité raté (15 nov., coque), FOU-117 page potes, FOU-111/FOU-62/FOU-50 fiche App Store, FOU-104 vérif coque, FOU-100 notifications, FOU-78 village. Historique complet : [`ZIEUTON_CHANGELOG.md`](ZIEUTON_CHANGELOG.md).
