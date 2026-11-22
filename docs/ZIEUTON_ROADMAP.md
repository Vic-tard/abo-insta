# Zieuton : roadmap

> Dernière mise à jour : 23 novembre 2026 (audit Linear de Victor et ChatGPT). Les statuts recopient Linear au 23 nov. Source de vérité des tâches : **Linear** (équipe FOU, projet « Zieuton 1.0 »). En cas d'écart, Linear gagne.
> Statuts : **À faire** / **En cours** / **Bloqué** / **Terminé**. Une ligne = un ticket Linear quand il existe.

## 1. Priorités actuelles (dans l'ordre)

Règle de Victor : **un seul sujet à la fois**. Jalons Linear :
- **Build validé** : 2 déc. ;
- **Soumis à Apple** : 5 déc. ;
- **Sortie** : 15 déc.

| # | Tâche | Ticket | Statut | Échéance |
| --- | --- | --- | --- | --- |
| 1 | PR #160 (démo pendant l'attente) : correction demandée le 22 nov., relecture, test iPhone, fusion puis stable avec l'accord de Victor | FOU-131 (Done pour le code fusionné) | PR ouverte | – |
| 2 | Valider le build 23 sur iPhone : transitions UX, notifications, non-régression, parcours Apple | FOU-105 | En cours | 2 déc. |
| 3 | Achats et restauration en sandbox | FOU-128 | À faire | 4 déc. |
| 4 | Médiateur de la consommation | FOU-82 | À faire | 4 déc. |
| 5 | Soumission à Apple, publication manuelle | FOU-130 | À faire | 5 déc. |
| 6 | Sortie sur l'App Store | FOU-130 (FOU-51 classé doublon) | – | **15 déc.** |

Dépendances : FOU-105 bloque FOU-130. FOU-128 et FOU-82 sont menés en parallèle, avant la soumission.

Terminé récemment : FOU-129 (canal stable, 22 nov.), FOU-131 (code des écrans A à E), FOU-126 (notifications), FOU-116 (vidéos Higgsfield, mais résiliation non confirmée).

## 2. Démarches administratives

| Tâche | Ticket | Statut | Note |
| --- | --- | --- | --- |
| ACRE à l'URSSAF | FOU-83 | En cours | Documents de l'Urssaf reçus le 21 nov. ; demande à remplir le 22 nov. Objectif de dépôt : 18 décembre 2026 ; limite probable 2 janvier 2027 (60 jours après le début d'activité du 3 nov., à confirmer auprès de l'Urssaf). Voir `PROPOSITIONS-LINEAR-2026-11-16.md` |
| Médiateur de la consommation | FOU-82 | À faire (4 déc.) | Obligatoire pour vendre à des particuliers **[Déduit]**, à faire avant la sortie |
| Small Business Program Apple (15 %) | – | En cours | Demande envoyée le 4 nov., réponse non reçue à notre connaissance |
| Essai Higgsfield (vidéos) + résiliation | FOU-116 | Done (5 vidéos livrées) | **Résiliation du renouvellement non confirmée** : vérifier le compte Higgsfield |

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

FOU-56 calendrier J-14 à J+14, FOU-57 vidéos saison 1, FOU-58 vidéos « brainrot », FOU-59 comptes Instagram/TikTok, FOU-60 liste de 10 à 20 micro-influenceurs, FOU-61 kit influenceurs, FOU-63 annonce du 15 déc., FOU-65 suivi des résultats, FOU-66 site vitrine.

**[Déduit]** Avec la sortie au 15 décembre, FOU-56, FOU-59 et FOU-60 devraient démarrer vers le 1er décembre (J-14). À arbitrer par Victor : la com est gelée.

## 5. Dépendances clés

```
PR #160 (+ nouvelle promotion stable) → validation build 23 (FOU-105) + achats (FOU-128) + médiateur (FOU-82) → soumission 5 déc. (FOU-130) → sortie 15 déc.
Page fusionnée → test en canal test → PR « canal valider » → visible pour tous
FOU-41 (découpage) → FOU-53 (Orca)
```

## 6. Objectifs à moyen et long terme

- **[Confirmé]** Après la sortie : Android, version anglaise, site vitrine (SPEC §5).
- **[Confirmé, 28 oct.]** Vision longue : vendre l'app largement, notamment via des influenceurs.
- **[Inconnu]** Objectifs chiffrés (téléchargements, abonnés Plus, revenu) : jamais fixés par écrit. Les scénarios du business model (1er nov.) sont des hypothèses.

## 7. Terminé récemment (repère)

FOU-122 règles Claude/ChatGPT (16 nov.), FOU-118 plan clair avant Instagram (15 nov.), FOU-115 code de sécurité raté (15 nov., coque), FOU-117 page potes, FOU-111/FOU-62/FOU-50 fiche App Store, FOU-104 vérif coque, FOU-100 notifications, FOU-78 village. Historique complet : [`ZIEUTON_CHANGELOG.md`](ZIEUTON_CHANGELOG.md).
