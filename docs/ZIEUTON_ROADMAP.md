# Zieuton : roadmap

> Dernière mise à jour : 22 novembre 2026, soir (nouveau planning de Victor : tout décalé de 10 jours, sortie le 15 déc.). Les statuts recopient Linear au 22 nov. Source de vérité des tâches : **Linear** (équipe FOU, projet « Zieuton 1.0 »). En cas d'écart, Linear gagne.
> Statuts : **À faire** / **En cours** / **Bloqué** / **Terminé**. Une ligne = un ticket Linear quand il existe.

## 1. Priorités actuelles (dans l'ordre)

Règle de Victor : **un seul sujet à la fois**. Jalons Linear : **Build validé** 2 déc., **Soumis à Apple** 5 déc., **Sortie** 15 déc.

État au 22 nov. au soir :
- Build candidat **1.0 (23)**.
- Canal stable = page du 21 nov. (fait).
- PR #160 ouverte (FOU-131 PR 2).

| # | Tâche | Ticket | Statut | Échéance |
| --- | --- | --- | --- | --- |
| 1 | Écrans après la demande. PR 2 #160 (démo : bulles, « Mon export ») à relire, à tester sur iPhone et à fusionner, puis canal stable | FOU-131 | En cours | 2 déc. |
| 2 | ACRE : demande à préparer avec les documents de l'Urssaf | FOU-83 | En cours | 18 déc. (légal) |
| 3 | Valider le build 23 sur iPhone (matrice restante, parcours Apple) | FOU-105 | En cours | 2 déc. |
| 4 | Achats et restauration en sandbox | FOU-128 | À faire | 2 déc. |
| 5 | Médiateur de la consommation | FOU-82 | À faire | 4 déc. |
| 6 | Soumission à Apple, publication manuelle | FOU-130 | À faire | 5 déc. |
| 7 | Sortie sur l'App Store | FOU-130 (FOU-51 classé doublon) | – | **15 déc.** |

Terminé récemment : FOU-129 (canal stable, 22 nov.), FOU-126 (notifications fiables). Un build 24 ne serait fait que si la coque doit changer, avec l'accord de Victor.

## 2. Démarches administratives

| Tâche | Ticket | Statut | Note |
| --- | --- | --- | --- |
| ACRE à l'URSSAF | FOU-83 | En cours | Documents de l'Urssaf reçus le 21 nov. ; demande à remplir le 22 nov. Objectif de dépôt : 18 décembre 2026 ; limite probable 2 janvier 2027 (60 jours après le début d'activité du 3 nov., à confirmer auprès de l'Urssaf). Voir `PROPOSITIONS-LINEAR-2026-11-16.md` |
| Médiateur de la consommation | FOU-82 | À faire (4 déc.) | Obligatoire pour vendre à des particuliers **[Déduit]**, à faire avant la sortie |
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

**[Déduit]** Avec la sortie au 15 décembre, FOU-56, FOU-59 et FOU-60 devraient démarrer vers le 1er décembre (J-14). À arbitrer par Victor : la com est gelée.

## 5. Dépendances clés

```
FOU-131 (+ canal stable) → validation build 23 (FOU-105) + achats (FOU-128) + médiateur (FOU-82) → soumission 5 déc. (FOU-130) → sortie 15 déc.
Page fusionnée → test en canal test → PR « canal valider » → visible pour tous
FOU-41 (découpage) → FOU-53 (Orca)
```

## 6. Objectifs à moyen et long terme

- **[Confirmé]** Après la sortie : Android, version anglaise, site vitrine (SPEC §5).
- **[Confirmé, 28 oct.]** Vision longue : vendre l'app largement, notamment via des influenceurs.
- **[Inconnu]** Objectifs chiffrés (téléchargements, abonnés Plus, revenu) : jamais fixés par écrit. Les scénarios du business model (1er nov.) sont des hypothèses.

## 7. Terminé récemment (repère)

FOU-122 règles Claude/ChatGPT (16 nov.), FOU-118 plan clair avant Instagram (15 nov.), FOU-115 code de sécurité raté (15 nov., coque), FOU-117 page potes, FOU-111/FOU-62/FOU-50 fiche App Store, FOU-104 vérif coque, FOU-100 notifications, FOU-78 village. Historique complet : [`ZIEUTON_CHANGELOG.md`](ZIEUTON_CHANGELOG.md).
