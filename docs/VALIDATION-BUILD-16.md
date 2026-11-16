# Plan de validation du build 1.0 (16)

> Préparé le 16 novembre 2026 (FOU-51, FOU-105). **Ce plan ne lance rien** : aucun build TestFlight, aucune soumission sans l'accord écrit de Victor. Il sert à savoir, le jour où Victor décide de faire le build 16, ce qu'il faut vérifier et dans quel ordre.
> Chaque case porte un statut : **À faire** / **Fait (date, par qui)** / **Échec (note)**. Une case non faite reste écrite « À faire » : on ne la coche jamais par déduction.

## 0. Ce que contient le build 16

| Élément | Source | Vérifié où aujourd'hui |
| --- | --- | --- |
| Tout ce qui était dans 1.0 (15) : P1 à P6 de l'export (PR #132, #134 à #138) | `main` f3a1433 | iPhone de Victor (build 15, export et import réels déclarés le 16 nov.) |
| FOU-124, partie coque : bouton « Revenir dans Zieuton » dans le bandeau, geste du bandeau qui laisse passer les boutons (PR #139) | `main` 31a5d87 | Tests seulement (`tests/ios/ExportProofTests.swift`, `tests/page/bandeau-geste.test.mjs`). **Jamais vu sur iPhone** |
| FOU-124, partie page : écran d'attente « Instagram prépare ta liste », « Découvrir Zieuton en attendant », « Refaire la demande » confirmé | `main` 31a5d87 (page `BUILD 2026-11-16-1951`) | Tests page (`tests/page/attente-ux.test.mjs`) ; en ligne seulement en **canal test** |
| Numéros : `MARKETING_VERSION 1.0`, `CURRENT_PROJECT_VERSION 16`, `ZYEUTO_APP.version 9` | `project.pbxproj`, `WebViewController.swift` | Lecture du dépôt |

Changements de la coque entre 15 et 16 : `WebViewController.swift` (+67 / −9 lignes environ) et le numéro de build. Rien dans StoreKit, iCloud, notifications ou le pont : ces blocs sont revérifiés quand même (règle « un seul build final », D-36).

## 1. Avant de lancer le build (sans iPhone)

| # | Vérification | Comment | Statut |
| --- | --- | --- | --- |
| 1.1 | Tests Node, syntaxe, copie du cœur, numéros | `npm test`, `npm run check:syntax`, `npm run check:versions` (CI GitHub, partie Linux) | À faire le jour J (CI verte sur `main` au 16 nov.) |
| 1.2 | Lecteur d'écrans Instagram et écrans de la page | `npm run test:lecteur` | À faire le jour J |
| 1.3 | Tests Swift (preuve de demande, « Revenir dans Zieuton », garde de page) | Sur le Mac : `npm run test:ios`. La CI Mac est bloquée (quota) jusqu'au 1er décembre : Victor colle la commande dans Terminal | À faire |
| 1.4 | Compilation Xcode sans erreur ni nouvel avertissement | Xcode → Product → Build | À faire |
| 1.5 | Aucune PR coque ouverte qui devrait entrer dans ce build | Liste des PR GitHub | À faire |
| 1.6 | Décision écrite de Victor : « on fait le build 16 » | Message dans le fil 02 | À faire |

## 2. Installation et données (iPhone de Victor, puis un iPhone de testeur)

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 2.1 | Mise à jour de 15 vers 16 par TestFlight, **sans désinstaller** | L'app s'ouvre, version affichée « 1.0 (16) » en bas des Réglages | À faire |
| 2.2 | Données gardées après la mise à jour | Même nombre d'imports, mêmes listes, même compte affiché, même niveau et trophées | À faire |
| 2.3 | Multi-comptes gardés (si plusieurs comptes) | Les comptes 2 et 3 sont toujours là, chacun avec son historique | À faire |
| 2.4 | Canal de mise à jour gardé | iPhone de Victor toujours en « canal test » ; iPhone de testeur en canal normal | À faire |
| 2.5 | Installation neuve (iPhone sans Zieuton ou après suppression, **pas** l'iPhone principal de Victor) | Écran de bienvenue → « C'est parti ! » → plan « On va chercher tes abonnés chez Instagram » | À faire |

## 3. Export Instagram (le cœur, ne pas modifier le moteur)

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 3.1 | Parcours complet dans l'app : connexion, réglages, « Commencer l'exportation » | Bandeau en 4 phases ; « C'est demandé » seulement quand une nouvelle ligne apparaît dans la liste d'Instagram | À faire |
| 3.2 | **Bouton « Revenir dans Zieuton »** (nouveau dans 16) | Visible après une demande vérifiée, fichier pas prêt ; le toucher ramène à l'écran d'attente ; invisible pendant un téléchargement ou une erreur | À faire |
| 3.3 | Geste du bandeau (nouveau dans 16) | Les boutons du bandeau répondent à la première touche ; balayer le bandeau marche toujours | À faire |
| 3.4 | Écran d'attente | « Instagram prépare ta liste », pas de délai promis ; « Regarder si c'est prêt » ; « Refaire la demande » demande une confirmation et n'efface rien sans elle | À faire |
| 3.5 | « Découvrir Zieuton en attendant » | Ouvre la démo ; « Ma liste » / « Récupérer ma liste » en haut ramène au parcours | À faire |
| 3.6 | Fichier prêt → « Récupérer ma liste » → l'utilisateur touche « Télécharger » | Import automatique, bilan affiché | À faire |
| 3.7 | Chemin de secours « Passer par l'app Instagram » | Ouvre Instagram, captures pas à pas, puis Partager → Zieuton | À faire |
| 3.8 | Demande déjà en cours chez Instagram | Message « inutile d'en refaire une », aucune nouvelle demande automatique | À faire (si la situation se présente) |
| 3.9 | Compte verrouillé | Non testable volontairement. Couvert par `npm run test:lecteur` seulement : à écrire tel quel dans le bilan | Non testable |

## 4. Notifications

| # | Vérification | Résultat attendu | Statut |
| --- | --- | --- | --- |
| 4.1 | Autorisation demandée au bon moment | Une seule fois, après la demande d'export | À faire |
| 4.2 | Rappel quand l'app est fermée | Un rappel local arrive (iOS peut le retarder : noter l'heure) | À faire |
| 4.3 | « Ton fichier est prêt » | Arrive si iOS a laissé l'app vérifier ; sinon l'app le voit à la réouverture. Noter ce qui s'est passé, sans conclure sur un seul essai | À faire |

## 5. Achats (sandbox ou TestFlight, aucun vrai paiement)

Dernier test complet des achats : **build 3** seulement. À refaire en entier sur le build 16.

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
| 7.1 | Installation neuve, sans Instagram : télécharger `zieuton-exemple-1.zip`, Fichiers → Partager → Zieuton | Import accepté, le parcours guidé se ferme, l'accueil s'affiche | À faire sur iPhone (vérifié en simulation navigateur le 16 nov.) |
| 7.2 | Puis `zieuton-exemple-2.zip` | 4 désabonnés, 3 nouveaux abonnés | À faire |
| 7.3 | Réglages → « Voir la démo », puis « Quitter la démo » | Démo remplie, sortie propre, données d'exemple gardées | À faire sur iPhone (vérifié en simulation le 16 nov.) |
| 7.4 | Version courte de la note collée dans App Store Connect | Moins de 4 000 caractères, chemin identique à ce qu'on voit | À faire |

## 8. Divers

| # | Vérification | Statut |
| --- | --- | --- |
| 8.1 | Mode clair et mode sombre sur l'écran d'attente et le bandeau | À faire |
| 8.2 | Petit iPhone (SE) et clavier ouvert dans Instagram | À faire |
| 8.3 | « Envoyer un rapport » prépare un mail lisible, rien n'est envoyé seul | À faire |
| 8.4 | Hors connexion : l'app s'ouvre avec la page embarquée | À faire |

## 9. Ce qui reste hors de ce build

- **Canal stable** encore au 10 novembre (`2026-11-10-1618`). Les potes en canal normal ne voient ni P1 à P6 côté page ni FOU-124 tant qu'une PR « canal valider » n'est pas fusionnée. À décider par Victor **après** les sections 3 et 7.
- Test « un inconnu, sans aide » (FOU-37) : après ce plan, pas pendant.
- Aucune soumission : FOU-51 reste suspendu à l'accord de Victor.

## 10. Critère pour dire « build 16 validé »

Toutes les cases des sections 1 à 7 en « Fait » (sauf 3.8 et 3.9, notées telles quelles), aucune régression des données (section 2), achats et restauration OK (section 5). Une seule case en échec = pas de soumission avec ce build ; on corrige, puis un nouveau build (17) avec ce même plan.
