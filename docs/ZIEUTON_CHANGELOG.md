# Zieuton : historique des changements

> Dernière mise à jour : 23 novembre 2026 (base FOU-123). Du 4 nov. à aujourd'hui : d'après l'historique Git de `main` (numéros de PR). Avant le 4 nov. : d'après la mémoire du projet (le clone ne contient pas l'historique plus ancien), donc moins détaillé.
> **Page** = visible sans Xcode (canal test d'abord). **Coque** = visible seulement après un nouveau build Xcode.
> Pour ajouter une entrée : en haut de la bonne date, une ligne par PR fusionnée, avec ticket et type.

## Builds envoyés à Apple (TestFlight)

| Build | Date | Contenu notable |
| --- | --- | --- |
| 1.0 (1) | 4 nov. | Premier envoi, testeur interne |
| 1.0 (2) | 4 nov. | iCloud, menu photo, bandeau, notifications (#83 #85 #86 #89 #90) ; approuvé pour les testeurs externes |
| 1.0 (3) | 6 nov. | Mises à jour sûres, signature, versions (#98 #102 #103) |
| 1.0 (4) | – | Jamais envoyé |
| 1.0 (5) | 10 nov. | Mises à jour via zieuton.com (#111, #112) |
| 1.0 (7) | 15 nov. | « Build 6 » : notifications (#116), confidentialité Apple (#122) |
| 1.0 (15) | 16 nov. | Export P1 à P6 (#132, #134 à #138) |
| 1.0 (17) | 17 nov. | Notifications FOU-126 (#142, #143) ; non validé sur iPhone |
| 1.0 (21) | 18 nov. | Correctifs FOU-126 (#146 à #150) |
| 1.0 (22) | 21 nov. | Sécurité du suivi (#155) |
| 1.0 (23) | 21 nov. | Bandeau « Un fichier est disponible » (#156) ; **candidat actuel**, installé chez Victor |

## Novembre 2026

### 22 nov.
- #160 FOU-131 PR 2 : démo pendant l'attente, bulles du zieuteur, « Mon export » (page 2026-11-22-2329, fusionnée à 23 h 37, canal test seulement ; tests iPhone et stable à faire)
- #161 Nouveau planning : sortie le 15 déc. (doc)
- #159 Canal stable = page du 21 nov. (2026-11-21-1638), validée sur l'iPhone de Victor (FOU-126 / FOU-129)
- #158 Ménage : branches fusionnées supprimées, roadmap, handoff (doc, 21 nov. au soir)

### 21 nov.
- #157 Après un import : « Est-ce bien le fichier de ta demande ? » (page, FOU-126 / FOU-131)
- #156 Bandeau « Un fichier est disponible » redessiné quand « Télécharger » apparaît (coque, build 23, FOU-126)
- #155 Sécurité du suivi dans la coque, fin du suivi seulement sur preuve (coque, build 22, FOU-126)
- #154 La page ne dit plus « plus en attente » au démarrage (page, FOU-126)
- #153 La démo ne fait plus oublier la demande suivie (page, FOU-126)
- #152 Écrans après la demande d'export A, B, D, E et frise (page, FOU-131 PR 1)
- #151 Test obligatoire « page du build 17 » (test, FOU-126)

### 18 nov.
- #146 à #150 Correctifs du build 17 : lecture de la vraie liste d'Instagram, plus de faux « Touche Télécharger », demande du jour, cartes « Expire le » (coque build 21 + page + doc, FOU-126)

### 17 nov.
- #145 Résultats des tests Mac (doc) ; #144 plan de validation du build 17 + note Apple (doc, remplace #140 fermée) ; #143 page et #142 coque des notifications fiables (FOU-126, build 17)
- #141 « Voir la démo d'abord » sur la bienvenue, prénoms de démo au hasard (page, FOU-51)

### 16 nov.
- #131 Règles de collaboration Claude / ChatGPT (doc, FOU-122)
- #130 Écran « Zieuton en haut, Instagram en bas » + bandeau cookies (page + coque, FOU-121)
- #129 « Faisons connaissance » supprimé, plan avant Instagram allégé (page, FOU-121)
- #128 Bienvenue qui s'affiche petit à petit (page, FOU-121)

### 15 nov.
- #127 Liste des 8 branches fusionnées à supprimer (FOU-120)
- #126 Plan clair avant Instagram, flèche corail, fenêtre « C'était moi » (page + coque, FOU-118)
- #125 Page zieuton.com/potes (FOU-117)
- #124 Code de sécurité raté et fichier « En attente » mieux gérés (coque, FOU-115)
- #123 Notes pour l'examinateur Apple (doc, FOU-111)
- #122 Déclaration de confidentialité Apple pour la date de sauvegarde iCloud (coque, FOU-104)

### 12 nov.
- #121 Mur devant le zieuteur de la roue, or réservé à Plus (page, FOU-102/103)
- #120 Village en canal stable (FOU-78)
- #116 Prévenu dès que le fichier Instagram est prêt (coque, FOU-100)

### 10 nov.
- #119 Village plus détaillé (FOU-108) ; #117 village sur une île (FOU-106) ; #115 village dans la page Jeux (FOU-78)
- #118 Action de nettoyage des branches (FOU-45)
- #114 GitHub Pages (secours) ne fait plus échouer la publication (FOU-97)
- #113 Adresse, SIRET, réclamations dans les textes légaux (FOU-68)
- #112 Pages Aide, Confidentialité, Conditions, Mentions légales sur zieuton.com (coque, FOU-93)
- #111 Build 4 : mises à jour prises sur zieuton.com, GitHub en secours (coque, FOU-92)
- #110 Publication aussi sur Cloudflare Pages (FOU-90)

### 7 nov.
- #109 Canal stable = page du 6 nov. 16h33 (FOU-76)
- Suspension du compte GitHub (FOU-80), levée le 10 nov.

### 6 nov.
- #108 Graphiques à dérouler et 8 nouveaux (FOU-74/75) ; #107 écran doré après achat (FOU-73) ; #106 Réglages sobres (FOU-71) ; #105 « Faisons connaissance » (FOU-69, retiré le 16 nov.)
- #104 Textes légaux à jour (FOU-34)
- #103 La CI vérifie les numéros de version (FOU-44) ; #102 page signée (coque, FOU-29) ; #98 canaux test / stable et retour automatique (coque, FOU-28)
- #101 Code mort Drive / Gmail retiré (FOU-43) ; #100 données versionnées, copie légère pour gros comptes (FOU-39/40)
- #99 Journal d'erreurs, « Envoyer un rapport », note Apple (FOU-30/32)
- #97 SPEC + CLAUDE.md (FOU-27) ; #96 tests d'import + CI (FOU-26)
- #92 Bandeau ne demande plus le mot de passe sur la page des cases (FOU-35)

### 5 nov.
- #93 à #95 Écrans d'attente du premier export (corail et lilas)
- #91 Gros bouton « Télécharger mon export »

### 4 nov.
- #90 Projet Xcode réglé sur l'équipe de Victor
- #89 Notifications même si le bandeau s'est trompé, textes iCloud
- #88 Pastilles Demander / Attendre / Télécharger cliquables ; #87 « Voir les offres » si Plus actif
- #86 Bandeau reconnaît le résumé sans titre (coque) ; #85 menu photo natif (coque)
- #84 Prix dans la monnaie de l'App Store
- #83 Sauvegarde iCloud, page rangée dans l'app, site Safari fermé, plus de clic auto sur « Télécharger » (coque)
- #82 Prix 2,99 / 14,99 / 29,99 € et comptes 2–3
- #73 à #77 (d'après la mémoire) : libellés des comptes, gratuit au premier compte, bandeau corrigé après les vidéos de Victor

### 1er au 3 nov. (d'après la mémoire)
- #33 Arrivée autonome ; #34 notifications détaillées ; #36 à #38 multi-comptes ; #39 carte « Mettre à jour » épurée ; #69 notification « sûrement prête » ; #70 clic auto sur « Télécharger » (retiré le 4 nov.)
- #28 Renommage en Zieuton ; #22 Zieuton Plus (StoreKit 2) ; #21 confidentialité et préparation TestFlight ; #16 à #19 notifications d'export ; #4 écran d'ouverture, hors ligne, vibrations
- 1er nov. : coque iPhone créée (Xcode, WKWebView) ; mini-jeux et pages en swipe

## Octobre 2026 (d'après la mémoire)

- 26 oct. : premier outil « Abo Insta » (script Python + page locale, SQLite).
- 27 oct. : version téléphone en artefact claude.ai (historique stocké en ligne).
- 28 oct. : virage vers une app propre hébergée sur GitHub Pages ; carte « Export de la semaine ».
- 29–31 oct. : analyse juridique, concurrents, choix du nom « Zyeuto ».

## Régressions connues

- Détection d'un export « Année dernière » : corrigée le 3 nov., revue chez les testeurs le 15 nov. (BUG-04).
- Note examinateur Apple possiblement périmée après #129 (BUG-08).
