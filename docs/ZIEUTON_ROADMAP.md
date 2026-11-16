# Zieuton : roadmap

> Dernière mise à jour : 16 novembre 2026 (FOU-123). Les statuts ci-dessous recopient Linear au 16 nov. ; deux écarts connus (FOU-121 « Done », FOU-119 « In Progress ») ne sont pas encore corrigés, à la demande de Victor. Source de vérité des tâches : **Linear** (équipe FOU, projet « Zieuton 1.0 »). Ce document donne l'ordre et les dépendances ; en cas d'écart, Linear gagne, puis on corrige ce fichier.
> Statuts : **À faire** / **En cours** / **Bloqué** / **Terminé**. Une ligne = un ticket Linear quand il existe.

## 1. Priorités actuelles (dans l'ordre)

Règle de Victor : **un seul sujet à la fois**, clôturé à 100 % avant le suivant. Tout ce qui n'est pas l'export est gelé.

| # | Tâche | Ticket | Statut | Dépend de |
| --- | --- | --- | --- | --- |
| 1 | Export fiable, P1 : détection fiable des étapes et des demandes, compte verrouillé | FOU-121 | En cours : PR #132 ouverte (coque) | – |
| 2 | Export, P2 à P6 (voir le diagnostic) | FOU-121 | À faire | P1 relu par ChatGPT et validé par Victor |
| 3 | Valider en canal stable la page actuelle (`npm run canal -- valider`) | pas encore de ticket | À faire | Test de Victor en canal test |
| 4 | Build final unique (coque ≥ version 11) + test iPhone complet, achats compris | FOU-105 (parent FOU-101) | En cours | 1, 2 |
| 5 | Premier export réussi par un inconnu, sans aide | FOU-37 | À faire | 4 |
| 6 | Retours des potes TestFlight | FOU-113 | À faire | 4 |
| 7 | Soumission à Apple, publication manuelle (visée vers le 25 nov., orientation de Victor du 16 nov.) | FOU-51 | En cours | 4, 5 ; note examinateur corrigée le 16 nov. (à revérifier sur iPhone) ; plan `VALIDATION-BUILD-16.md` |
| 8 | Sortie le 3 décembre 2026 | FOU-51 | À faire | 7 |

**Après P1, à faire (liste de Victor, 16 nov.)** : vérifier le parcours de démonstration destiné à Apple ; corriger l'écart entre les statuts Linear et le travail réel ; fixer le minimum indispensable avant soumission ; tester le canal stable et les parcours sur les iPhone des testeurs ; revoir le calendrier de soumission. D'ici là : aucun statut Linear changé et aucune nouvelle PR technique sans l'accord de Victor.

**[Déduit]** La soumission était prévue vers le 20 novembre. Avec P1 à P6 encore à faire dans la coque, cette date est à reconfirmer par Victor (voir l'audit, risque R2).

## 2. Démarches administratives

| Tâche | Ticket | Statut | Note |
| --- | --- | --- | --- |
| ACRE à l'URSSAF | FOU-83 | Bloqué | Attend le numéro de compte URSSAF (courrier). Objectif de dépôt : 18 décembre 2026 ; limite probable 2 janvier 2027 (60 jours après le début d'activité du 3 nov., à confirmer auprès de l'Urssaf). Voir `PROPOSITIONS-LINEAR-2026-11-16.md` |
| Médiateur de la consommation | FOU-82 | À faire (Backlog) | Obligatoire pour vendre à des particuliers **[Déduit]**, à faire avant la sortie |
| Small Business Program Apple (15 %) | – | En cours | Demande envoyée le 4 nov., réponse non reçue à notre connaissance |
| Essai Higgsfield (vidéos) + résiliation immédiate | FOU-116 | À faire (gelé) | Ne pas lancer sans Victor |

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
| Zieuteur en 3D | FOU-119 | En cours dans Linear mais gelé ; 4 styles proposés le 15 nov. (pâte à modeler, vinyle, pastel, animation), choix de Victor en attente |

## 4. Communication et lancement (tout en Backlog depuis le 10 nov., FOU-99)

FOU-56 calendrier J-14 à J+14, FOU-57 vidéos saison 1, FOU-58 vidéos « brainrot », FOU-59 comptes Instagram/TikTok, FOU-60 liste de 10 à 20 micro-influenceurs, FOU-61 kit influenceurs, FOU-63 annonce du 3 déc., FOU-65 suivi des résultats, FOU-66 site vitrine.

**[Déduit]** Si la sortie reste au 3 décembre, FOU-56, FOU-59 et FOU-60 devront démarrer au plus tard vers le 19 novembre (J-14). À arbitrer par Victor.

## 5. Dépendances clés

```
FOU-121 P1 → P2…P6 → build final (FOU-105) → test inconnu (FOU-37) → soumission (FOU-51) → sortie 3 déc.
                                     ↘ test achats sur le build final (revérif FOU-36)
Page fusionnée → test en canal test → PR « canal valider » → visible pour tous
FOU-41 (découpage) → FOU-53 (Orca)
```

## 6. Objectifs à moyen et long terme

- **[Confirmé]** Après la sortie : Android, version anglaise, site vitrine (SPEC §5).
- **[Confirmé, 28 oct.]** Vision longue : vendre l'app largement, notamment via des influenceurs.
- **[Inconnu]** Objectifs chiffrés (téléchargements, abonnés Plus, revenu) : jamais fixés par écrit. Les scénarios du business model (1er nov.) sont des hypothèses.

## 7. Terminé récemment (repère)

FOU-122 règles Claude/ChatGPT (16 nov.), FOU-118 plan clair avant Instagram (15 nov.), FOU-115 code de sécurité raté (15 nov., coque), FOU-117 page potes, FOU-111/FOU-62/FOU-50 fiche App Store, FOU-104 vérif coque, FOU-100 notifications, FOU-78 village. Historique complet : [`ZIEUTON_CHANGELOG.md`](ZIEUTON_CHANGELOG.md).
