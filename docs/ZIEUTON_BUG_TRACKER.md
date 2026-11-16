# Zieuton : suivi des bugs

> Dernière mise à jour : 16 novembre 2026 (FOU-123). Reconstitué à partir de la mémoire du projet, de Linear et de l'historique Git. Les bugs C1 à C13 du diagnostic de l'export (https://claude.ai/artifact/EoLTde9KQffLq2JGBuwqkj) ne sont **pas recopiés** ici : ce document les référence, le fil export les traite.
> Gravité : **Critique** (bloque l'usage ou la sortie) / **Haute** / **Moyenne** / **Basse**.
> États : **Ouvert** / **En cours** / **Corrigé, à vérifier** (code fusionné mais pas vu sur iPhone) / **Vérifié** / **Contourné**.
> Pour ajouter un bug : prendre le numéro suivant, remplir toutes les colonnes, citer le ticket Linear.

## 1. Bugs ouverts ou à vérifier

| ID | Description | Gravité | Reproduction | Cause connue ou suspectée | État | Correction | Vérification |
| --- | --- | --- | --- | --- | --- | --- | --- |
| BUG-01 | Le bandeau dit « tape ton mot de passe » alors que ce n'est pas l'étape | Haute | Vu sur captures des potes, build 1.0 (7) | Reconnaissance d'écran trop large (suspecté) | En cours (FOU-121 P1) | – | – |
| BUG-02 | « Récupère ton fichier » affiché sur une fenêtre blanche | Haute | Captures des potes | Écran en chargement pris pour l'écran final (suspecté) | En cours (FOU-121) | – | – |
| BUG-03 | « Touche Télécharger » alors que le bouton est hors écran | Moyenne | Captures des potes | Bandeau ne tient pas compte du défilement | Ouvert (FOU-121) | – | – |
| BUG-04 | Demande partie en « Année dernière » non détectée ; bandeau resté sur « Créer une exportation » | Haute | Captures des potes | Détection de la période ; **déjà corrigé une fois le 3 nov.** → possible régression | Ouvert (FOU-121) | – | – |
| BUG-05 | Code de sécurité raté, mais « je guette ton fichier » quand même ; fichier « En attente » mal géré | Haute | Build 1.0 (7), test de Victor | Avancée d'étape sans preuve | Corrigé, à vérifier | PR #124 (FOU-115, coque) | Pas encore dans un build testé |
| BUG-06 | Conseils du bandeau coupés (plus de 2 lignes, ~95 caractères) | Moyenne | Textes Swift de connexion / code de sécurité | `tipLabel` limité à 2 lignes | Ouvert | – | – |
| BUG-07 | Notifications d'export mal affichées | Moyenne | Build 5 | – | Corrigé, à vérifier | PR #116 (FOU-100) | Présent dans le build 1.0 (7) ; vérification iPhone non notée |
| BUG-08 | Chemin « démo » de la note examinateur peut-être faux (prénom → « Continuer » → « Voir la démo ») depuis la suppression de « Faisons connaissance » | **Critique pour la soumission** | Lire `docs/note-revue-apple.md` puis suivre le parcours actuel | PR #129 a retiré l'écran prénom et la démo du plan (**[Déduit]**, à vérifier sur iPhone) | Ouvert, nouveau | – | – |
| BUG-09 | Un testeur a eu son compte Instagram verrouillé pendant l'export | Haute | Rapport d'un pote | Non prouvée ; la fenêtre de connexion compte comme « nouvel appareil » | En cours (FOU-121 P1 : arrêt propre ; P6 : chemin par l'app Instagram) | – | – |
| BUG-22 | Le lien du questionnaire testeurs est le lien d'**édition** du Google Forms (seul Victor peut l'ouvrir) | Moyenne | Ouvrir le lien depuis un autre compte | Mauvais lien copié | Ouvert : attend le lien public `forms.gle/…` de Victor (fil vidéo com, 15 nov.) | – | – |
| BUG-10 | Notification « prêt » rarement reçue quand l'app est fermée | Moyenne | App fermée après la demande | Limite d'iOS (BGAppRefreshTask) | Contourné | Notification « sûrement prête » à 10 min (PR #69) | Partielle |

## 2. Bugs corrigés (historique)

| ID | Description | Gravité | Correction | Vérification |
| --- | --- | --- | --- | --- |
| BUG-11 | Aucune mise à jour de page n'arrivait : Cloudflare « Email Address Obfuscation » modifiait la page signée | Critique | Option désactivée par Victor (10 nov.) | Vérifié sur iPhone. **Risque de retour** si l'option est réactivée |
| BUG-12 | Nouveautés invisibles (graphiques à dérouler) : canal stable pas avancé | Haute | PR #109 (FOU-76) | Vérifié. Cause de fond = procédure, voir audit R3 |
| BUG-13 | Bandeau qui revenait d'une étape en arrière, résumé non reconnu, « C'est parti » trop tôt… (vidéo du 4 nov.) | Haute | PR #75, #77 | Vérifié par Victor (« on est bon ») |
| BUG-14 | Bandeau demandait le mot de passe sur la page des cases | Haute | PR #92 (FOU-35) | Vérifié |
| BUG-15 | Résumé d'export non reconnu sans son titre | Moyenne | PR #86 | Build 1.0 (2) |
| BUG-16 | Notification « prêt » partait d'une mauvaise première vérification | Moyenne | PR #19 | Test réel 2 nov. |
| BUG-17 | Prix « €/mois » collé à un prix en dollars | Basse | PR #84 | Vérifié |
| BUG-18 | Le prototype du village n'affichait rien sur iPhone | Moyenne | Prototype v2 (moteur intégré, sans WebGL) | Vérifié (FOU-98) |
| BUG-19 | Lien TestFlight « Not Found » depuis une story Instagram | Haute | Page zieuton.com/potes (PR #125, FOU-117) | Testé par Victor **[Déduit]** |
| BUG-20 | Échec de publication quand GitHub Pages (secours) tombe | Moyenne | PR #114 (FOU-97) | CI |
| BUG-21 | Erreurs silencieuses (`catch {}` vides) | Moyenne | PR #99 (FOU-30) : journal d'erreurs + « Envoyer un rapport » | CI |

## 3. Pièges d'outillage (pas des bugs de l'app)

- Xcode : « Failed to open index.html / Operation not permitted » → donner à Xcode l'accès complet au disque.
- Xcode : le fichier `Zieuton.storekit` ne se branche pas tout seul → Edit Scheme → Run → Options → StoreKit Configuration.
- CI : le job macOS reste parfois 15 min sans Mac puis « Annulé » → relancer.
- Captures de Victor parfois prises sur une ancienne page : toujours vérifier la version (`BUILD`) avant de corriger.

## 4. Zones peu testées (risque de régression)

- Bandeau guide (Swift) : aucun test automatique sur de vraies pages Instagram ; P1 ajoute des pages reconstituées.
- Achats : testés une seule fois en sandbox (build 3). À refaire sur le build final.
- Restauration iCloud sur un nouvel iPhone : pas de trace d'un test réel **[Inconnu]**.
- Multi-comptes avec achats sur comptes 2 et 3 : testé sur build 3 (compte 2).
