# Plan de validation du build 1.0 (17)

> Préparé le 16 novembre 2026 pour le build 16 (FOU-51, FOU-105), repris le 17 novembre pour le **build 17** (FOU-126) : Victor a décidé de ne pas faire de build 16 intermédiaire et de viser directement un build 17 candidat à la soumission. **Ce plan ne lance rien** : aucun build TestFlight, aucune soumission sans l'accord écrit de Victor.
> Chaque case porte un statut : **À faire** / **Fait (date, par qui)** / **Échec (note)**. Une case non faite reste écrite « À faire » : on ne la coche jamais par déduction.

## Résultat du build 17 sur iPhone (17 nov. 2026) : NON VALIDÉ

Build 1.0 (17) envoyé sur TestFlight et installé par Victor le 17 nov. vers 17 h 25. Premier test réel d'une demande (captures dans `notifications-build17/tests-iphone-17nov/` du dossier du projet) :

| Heure | Constat | Cause trouvée | Correctif |
| --- | --- | --- | --- |
| 17 h 32 | Instagram montre la nouvelle demande « En attente », datée du 17/11/2026, mais le bandeau dit « Je n'ai pas encore vu ta demande » | La liste est dans une fenêtre par-dessus la page : Zieuton ne la lisait que si « Créer une exportation » était visible. Et « En attente » est un titre de section : la date est dans la carte en dessous, jamais lue | #146 (lecteur) |
| 17 h 34 | Étape « Fichier » : « Touche Télécharger », avec le cercle sur le bouton d'un **ancien** export, alors que la demande est encore en attente | Pour récupérer le fichier, le bandeau avait un texte fixe et entourait tout bouton « Télécharger » visible, sans consulter la preuve « prêt ». Aucune notification « prêt » n'est partie | #147 (bandeau) |
| 17 h 35 | Écran d'attente : « Une demande était déjà en cours chez Instagram » | C'était la demande de 17 h 32, vue en retard, présentée comme ancienne | #148 (textes) |

Conséquence : les sections 3 et 4 sont à refaire avec le build suivant (numéro 20 après fusion de #146 à #148). Les cases ci-dessous restent « À faire ». Les cas 4.17 à 4.23 sont nouveaux (4.22 et 4.23 : relecture ChatGPT du 18 nov.).

**Limites des tests automatiques (relecture ChatGPT du 18 nov.).** Les pages Instagram des tests sont reconstituées à partir des captures du 17 nov. : elles reprennent les textes vus, pas le vrai code d'Instagram, qui peut être différent et changer sans prévenir. Elles prouvent que Zieuton lit ces textes, pas qu'il lira toujours la vraie page. C'est pourquoi le lecteur reste prudent : s'il ne trouve pas de date lisible sur une ligne, Zieuton ne dit jamais « c'est demandé » ni « c'est prêt » ; il affiche « Vérifie la date de ton export ». Seul le test sur iPhone (cas 4.17 à 4.23) valide le vrai comportement.

## 0. Ce que contient le build 17

| Élément | Source | Vérifié où aujourd'hui |
| --- | --- | --- |
| Tout ce qui était dans 1.0 (15) : P1 à P6 de l'export (PR #132, #134 à #138) | `main` f3a1433 | iPhone de Victor (build 15, export et import réels déclarés le 16 nov.) |
| FOU-124, partie coque : bouton « Revenir dans Zieuton » dans le bandeau, geste du bandeau qui laisse passer les boutons (PR #139) | `main` 31a5d87 | Tests seulement. **Jamais vu sur iPhone** (le build 16 n'a jamais été compilé) |
| FOU-124, partie page : écran d'attente « Instagram prépare ta liste », « Découvrir Zieuton en attendant », « Refaire la demande » confirmé | `main` 31a5d87 | Tests page ; en ligne seulement en **canal test** |
| FOU-51 : « Voir la démo d'abord » sur la bienvenue, prénoms de démo au hasard (PR #141) | `main` 75029f4 | Tests page ; canal test |
| **FOU-126, coque (N1)** : notifications fiables. « C'est demandé ✓ » seulement sur preuve, « Ton fichier est prêt 🎉 » seulement si une nouvelle ligne prête datée du jour de la demande est vue, rappels 30 min et 24 h annulés dès que l'attente se termine, alertes « expire » supprimées, pont v10 (`zyeutoNotif`, `zyeutoWatch`) | PR #142 (**pas encore fusionnée**) | Tests Node (`tests/coque-notifications.test.mjs`, lecteur) ; tests Swift écrits (`tests/ios/ExportProofTests.swift`, cas 22 à 25) mais **pas encore lancés** (Mac) |
| **FOU-126, page (N2)** : écran « Je te préviens ? » avant Instagram (« Activer les notifications » / « Plus tard », pause de 7 jours), état de l'attente lisible (rappel activé, notifications refusées, vérification impossible), demande liée au bon compte | PR #143 (**pas encore fusionnée**, à fusionner après #142) | Tests page (`tests/page/notifications.test.mjs`) ; captures clair, sombre, petit écran |
| Numéros : `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 17`, `ZYEUTO_APP.version 10` | PR #142 | Lecture du dépôt |

Changements de la coque entre 15 et 17 : `WebViewController.swift` (PR #139 et #142), `AppDelegate.swift` (#142) et le numéro de build. Rien dans StoreKit ni iCloud : ces blocs sont revérifiés quand même (règle « un seul build final », D-36).

## 1. Avant de lancer le build (sans iPhone)

| # | Vérification | Comment | Statut |
| --- | --- | --- | --- |
| 1.1 | Tests Node, syntaxe, copie du cœur, numéros | `npm test`, `npm run check:syntax`, `npm run check:versions` (CI GitHub, partie Linux) | Fait (17 nov., Claude) : vert sur `main` a823ea5 (51 + 43 tests) |
| 1.2 | Lecteur d'écrans Instagram et écrans de la page | `npm run test:lecteur` | Fait (17 nov., Claude) : 78 tests verts sur `main` |
| 1.3 | Tests Swift (preuve de demande, preuve « prêt », plan des notifications, textes) | Sur le Mac, la CI Mac étant bloquée jusqu'au 1er décembre : commandes A et B ci-dessous | Fait (17 nov. 17h12, Mac de Victor) : « Tout est vert. », cas 26 multicompte compris |
| 1.4 | Compilation Xcode sans erreur | Commande C ci-dessous, puis Xcode → Product → Build | Commande C faite (17 nov. 17h12, Mac de Victor) : `** BUILD SUCCEEDED **`, aucune ligne `error:` (seul message : avertissement d'Xcode sur l'appareil générique, sans effet) |
| 1.5 | PR #142, #143 et #144 relues par ChatGPT, puis fusionnées avec l'accord de Victor | GitHub | Fait (17 nov.) : `main` a823ea5 ; #140 fermée, remplacée par #144 |
| 1.6 | Aucune autre PR coque ouverte qui devrait entrer dans ce build | Liste des PR GitHub | À faire |
| 1.7 | Décision écrite de Victor : « on fait le build 17 » | Message dans le fil 02 | À faire |

Commandes à coller dans Terminal sur le Mac (une à la fois). Depuis la fusion (17 nov.), elles prennent `main`.

A. Récupérer le code :

```
cd /tmp && rm -rf zieuton-verif && git clone --depth 1 https://github.com/Vic-tard/abo-insta.git zieuton-verif && cd zieuton-verif && git log --oneline -1
```

B. Tests Swift (la dernière ligne doit dire que tout est passé) :

```
sh scripts/test-page-guard.sh && sh scripts/test-export-proof.sh
```

C. Compilation sans signature (doit finir par `BUILD SUCCEEDED`) :

```
xcodebuild build -project ios/Zieuton.xcodeproj -scheme Zieuton -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" | tee build.log | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

## 2. Installation et données (iPhone de Victor, puis un iPhone de testeur)

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 2.1 | Mise à jour de 15 vers 17 par TestFlight, **sans désinstaller** | L'app s'ouvre, version affichée « 1.0 (17) » en bas des Réglages | À faire |
| 2.2 | Données gardées après la mise à jour | Même nombre d'imports, mêmes listes, même compte affiché, même niveau et trophées | À faire |
| 2.3 | Multi-comptes gardés (si plusieurs comptes) | Les comptes 2 et 3 sont toujours là, chacun avec son historique | À faire |
| 2.4 | Canal de mise à jour gardé | iPhone de Victor toujours en « canal test » ; iPhone de testeur en canal normal | À faire |
| 2.5 | Installation neuve (iPhone sans Zieuton ou après suppression, **pas** l'iPhone principal de Victor) | Écran de bienvenue → « C'est parti ! » → plan « On va chercher tes abonnés chez Instagram » | À faire |

## 3. Export Instagram (le cœur, ne pas modifier le moteur)

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 3.1 | Parcours complet dans l'app : connexion, réglages, « Commencer l'exportation » | Bandeau en 4 phases ; « C'est demandé » seulement quand une nouvelle ligne apparaît dans la liste d'Instagram | À faire |
| 3.2 | **Bouton « Revenir dans Zieuton »** (nouveau depuis 15) | Visible après une demande vérifiée, fichier pas prêt ; le toucher ramène à l'écran d'attente ; invisible pendant un téléchargement ou une erreur | À faire |
| 3.3 | Geste du bandeau (nouveau depuis 15) | Les boutons du bandeau répondent à la première touche ; balayer le bandeau marche toujours | À faire |
| 3.4 | Écran d'attente | « Instagram prépare ta liste », pas de délai promis ; « Regarder si c'est prêt » ; « Refaire la demande » demande une confirmation et n'efface rien sans elle | À faire |
| 3.5 | « Découvrir Zieuton en attendant » | Ouvre la démo ; « Ma liste » / « Récupérer ma liste » en haut ramène au parcours | À faire |
| 3.6 | Fichier prêt → « Récupérer ma liste » → l'utilisateur touche « Télécharger » | Import automatique, bilan affiché | À faire |
| 3.7 | Chemin de secours « Passer par l'app Instagram » | Ouvre Instagram, captures pas à pas, puis Partager → Zieuton | À faire |
| 3.8 | Demande déjà en cours chez Instagram | Message « inutile d'en refaire une », aucune nouvelle demande automatique | À faire (si la situation se présente) |
| 3.9 | Compte verrouillé | Non testable volontairement. Couvert par `npm run test:lecteur` seulement : à écrire tel quel dans le bilan | Non testable |

## 4. Notifications (FOU-126, le cœur de ce build)

Règle : iOS ne laisse pas une app vérifier en permanence quand elle est fermée ou suspendue. On note **ce qui s'est passé**, avec l'heure, sans conclure sur un seul essai. Un « prêt » n'est attendu que si Zieuton a pu regarder (app ouverte, ou réveil accordé par iOS).

| # | Situation | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 4.1 | Première demande, autorisation jamais demandée | Avant d'ouvrir Instagram : écran « Je te préviens ? ». « Activer les notifications » → fenêtre d'iOS, puis Instagram s'ouvre | À faire |
| 4.2 | Même chose avec « Plus tard » | Instagram s'ouvre quand même ; l'écran ne revient pas avant 7 jours ; l'écran d'attente propose « Activer les rappels » | À faire |
| 4.3 | Autorisation déjà accordée | Pas d'écran « Je te préviens ? » | À faire |
| 4.4 | Demande vérifiée, **app ouverte** | Notification « C'est demandé ✓ » visible en haut de l'écran ; texte sans promesse (« Tu pourras vérifier son état dans Zieuton ») | À faire |
| 4.5 | Demande vérifiée puis app en arrière-plan | Rappel à 30 min ; s'il n'est pas prêt, rappel à 24 h. Toucher le rappel ouvre l'accueil de Zieuton | À faire |
| 4.6 | Fichier prêt, app ouverte (ou rouverte) | « Ton fichier est prêt 🎉 » une seule fois ; les rappels prévus sont annulés ; la toucher ouvre Instagram sur « Télécharger » (l'utilisateur touche lui-même) | À faire |
| 4.7 | App **fermée de force** (balayée) pendant l'attente | Aucun « prêt » promis ; les rappels 30 min / 24 h arrivent ; à la réouverture, Zieuton revérifie | À faire |
| 4.8 | **Mode avion** pendant une vérification | Écran d'attente : « Pas de connexion internet : je n'ai pas pu regarder. » Aucun « prêt » | À faire |
| 4.9 | Session Instagram expirée | Écran d'attente : « Reconnecte-toi à Instagram pour que je puisse regarder ». Aucun « prêt » | À faire |
| 4.10 | Notifications **refusées** puis réactivées dans Réglages d'iOS | Refus : l'écran le dit et propose « Ouvrir les réglages », aucun rappel promis. Après réactivation : « Rappel activé » au retour dans Zieuton | À faire |
| 4.11 | Un **ancien export encore téléchargeable** dans la liste d'Instagram | Pas de faux « prêt » : seule une nouvelle ligne prête du jour de la demande compte | À faire (si la situation se présente) |
| 4.12 | Demande déjà en cours chez Instagram | « Une demande était déjà en cours chez Instagram ✓ » ; on suit cette demande-là | À faire (si la situation se présente) |
| 4.13 | **Deux comptes** : demande sur le compte 1, puis passage au compte 2 | L'attente du compte 1 n'est ni annulée ni affichée sur le compte 2, et ses rappels 30 min / 24 h arrivent quand même (double protection : page et coque) ; retour au compte 1 : l'attente est toujours là | À faire |
| 4.14 | Bout en bout : fichier vraiment prêt → « Télécharger » touché par l'utilisateur → import | Import automatique, bilan affiché, plus aucun rappel ensuite | À faire |
| 4.15 | Aucune notification « expire bientôt » ou « dernier jour » | Jamais vue, même avec un ancien rappel programmé par le build 15 (il est effacé au premier lancement du build 17) | À faire |
| 4.16 | Page ancienne (canal stable) + coque 17 | Les notifications marchent quand même (l'autorisation est demandée au moment de la preuve) | À faire |
| 4.17 | **Liste dans la fenêtre par-dessus la page** (croix en haut), juste après « Commencer l'exportation » (cas du 17 nov., 17 h 32) | La carte « En attente », « Demandée le » du jour, est reconnue : « C'est demandé ✓ » dans le bandeau et la notification, sans « Vérifier son état » | À faire (build 20) |
| 4.18 | **Ancien export prêt + nouvelle demande en attente**, ouverture pour récupérer le fichier (cas du 17 nov., 17 h 34) | Bandeau « Pas encore prêt : ta demande du JJ/MM est en attente ». Aucun cercle, aucun « Touche Télécharger » | À faire (build 20) |
| 4.19 | Même liste, quand la carte du jour reçoit « Télécharger » | « C'est prêt ! Touche Télécharger ». Cercle seulement s'il n'y a qu'un bouton « Télécharger » à l'écran. « Ton fichier est prêt 🎉 » une seule fois | À faire (build 20) |
| 4.20 | Demande du jour vue en retard (cas du 17 nov., 17 h 35) | « Une demande d'aujourd'hui est en cours », jamais « Une demande était déjà en cours » ni « Ta demande » (une date ne prouve pas que c'est la tienne) | À faire (build 20) |
| 4.21 | Vraie demande d'un autre jour encore en attente | « Une demande est déjà en cours » (texte inchangé) | À faire (si la situation se présente) |
| 4.22 | **Deux exports le même jour** : un premier demandé le matin et déjà prêt, puis une nouvelle demande (relecture ChatGPT du 18 nov.) | Tant que la nouvelle est « En attente » : « Pas encore prêt », aucun cercle, aucune notification « prêt ». « Prêt » seulement quand une deuxième ligne du jour a « Télécharger » | À faire (si possible) |
| 4.23 | Ouvrir Instagram pour récupérer un fichier **sans demande faite dans Zieuton** (par exemple faite dans l'app Instagram) | « Vérifie la date de ton export », jamais « Touche Télécharger », aucun cercle | À faire (build 20) |

## 5. Achats (sandbox ou TestFlight, aucun vrai paiement)

Dernier test complet des achats : **build 3** seulement. À refaire en entier sur le build 17.

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 5.1 | Réglages → Zieuton Plus : les 3 offres du compte 1 avec les prix de l'App Store (2,99 € / 14,99 € / 29,99 €) | Prix et conditions de renouvellement affichés | À faire |
| 5.2 | Achat mensuel (compte de test) | Plus actif, or affiché, mises à jour illimitées | À faire |
| 5.3 | Achat à vie | Plus actif sans date de fin | À faire |
| 5.4 | **Restaurer mes achats** après réinstallation | Plus retrouvé sans repayer | À faire |
| 5.5 | Compte 2 : son propre Plus (1,99 / 9,99 / 19,99 €) | L'app demande le Plus du compte 2 avant son import au-delà du gratuit | À faire |
| 5.6 | Limite gratuite : 2 premiers imports puis 1 par mois | Le 3e import du mois propose Plus | À faire |
| 5.7 | Annulation dans la feuille d'achat | Aucun message d'erreur rouge, rien ne change | À faire |

## 6. iCloud et sauvegarde

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 6.1 | Sauvegarde iCloud automatique après un import | Date de dernière sauvegarde mise à jour dans Réglages | À faire |
| 6.2 | Restauration après réinstallation | L'historique revient depuis iCloud | À faire |
| 6.3 | « Sauvegarder une copie » puis « J'ai une sauvegarde » | Le fichier `.zieuton` est relu et refusé s'il est modifié | À faire |
| 6.4 | iCloud désactivé | L'app marche, un message clair, aucune erreur muette | À faire |

## 7. Parcours de l'examinateur Apple (note `docs/note-revue-apple.md`)

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 7.1 | Installation neuve : sur la bienvenue, toucher « Voir la démo d'abord » (PR #141) | La démo s'ouvre, remplie de données inventées, bandeau « Démo » en haut | À faire sur iPhone (vérifié en simulation navigateur le 17 nov.) |
| 7.2 | Explorer la démo : accueil, listes, graphiques, jeux | Tout s'affiche, aucune erreur, rien n'est enregistré | À faire |
| 7.3 | Toucher « Quitter la démo » | Retour à la bienvenue (« C'est parti ! », « Voir la démo d'abord ») | À faire sur iPhone (vérifié en simulation navigateur le 17 nov.) |
| 7.4 | Deuxième méthode : télécharger `zieuton-exemple-1.zip`, Fichiers → Partager → Zieuton | Import accepté, le parcours guidé se ferme, l'accueil s'affiche | À faire sur iPhone (vérifié en simulation navigateur le 16 nov.) |
| 7.5 | Puis `zieuton-exemple-2.zip` | 4 désabonnés, 3 nouveaux abonnés | À faire |
| 7.6 | Réglages → « Voir la démo », puis « Quitter la démo », avec les données d'exemple importées | Démo remplie, sortie propre, données d'exemple gardées | À faire |
| 7.7 | Version courte de la note collée dans App Store Connect | Moins de 4 000 caractères (3 767 au 17 nov.), chemin identique à ce qu'on voit | À faire |

## 8. Divers

| # | Vérification | Statut |
| --- | --- | --- |
| 8.1 | Mode clair et mode sombre sur l'écran d'attente et le bandeau | À faire |
| 8.2 | Petit iPhone (SE) et clavier ouvert dans Instagram | À faire |
| 8.3 | « Envoyer un rapport » prépare un mail lisible, rien n'est envoyé seul | À faire |
| 8.4 | Hors connexion : l'app s'ouvre avec la page embarquée | À faire |

## 9. Ce qui reste hors de ce build

- **Canal stable** encore au 10 novembre (`2026-11-10-1618`). Les potes en canal normal ne voient ni P1 à P6 côté page ni FOU-124, FOU-126 (partie page) tant qu'une PR « canal valider » n'est pas fusionnée. À décider par Victor **après** les sections 3 et 7.
- Test « un inconnu, sans aide » (FOU-37) : après ce plan, pas pendant.
- Aucune soumission : FOU-51 reste suspendu à l'accord de Victor.

## 10. Critère pour dire « build 17 validé »

Toutes les cases des sections 1 à 7 en « Fait » (sauf 3.8, 3.9, 4.11 et 4.12, notées telles quelles si la situation ne se présente pas), aucune régression des données (section 2), achats et restauration OK (section 5). Une seule case en échec = pas de soumission avec ce build ; on corrige, puis un nouveau build (18) avec ce même plan.
