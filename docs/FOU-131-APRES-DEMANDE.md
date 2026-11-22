# FOU-131 : écrans après la demande d'export (PR 1)

Proposition validée par Victor et ChatGPT le 21 nov. 2026 : https://claude.ai/artifact/C4f3gRZgc7566TYyawP3LP

La PR 1 change seulement la page (`index.html`). Elle ne touche ni la coque, ni les preuves de demande ou de fichier prêt, ni les notifications, ni le moteur de lecture des exports.

## Ce que fait la PR 1

| Écran | Quand | Ce qui change |
| --- | --- | --- |
| A « C'est parti ! » | Évènement `requested` d'une demande **nouvelle** (prouvée par l'app) | Remplace l'ancienne fenêtre « C'est demandé ! ». Un seul bouton : « Continuer dans Zieuton ». |
| B « Ton export se prépare 👀 » | Demande en cours, fichier pas vu prêt | Frise de 4 étapes ; « Découvrir Zieuton » (principal) et « Vérifier mon export » visibles sans défiler ; rappels et « Refaire la demande » plus bas. |
| D « Vérifions ta demande » | Évènement `unsure` | Mêmes règles qu'avant, textes plus rassurants, étape 1 « Demande à vérifier » en orange. |
| E « Ton export est prêt ! 🎉 » | Évènement `ready` | Frise étapes 1 à 3 cochées, « Touche toi-même « Télécharger » », bouton « Récupérer mon export ». |

La carte de l'accueil (utilisateurs qui ont déjà importé) prend les mêmes mots : « Ton export se prépare », « Vérifier mon export ».

## Point 1 : retour d'Instagram vers l'écran A

Le constat : la coque envoie `requested` pendant qu'Instagram est encore affiché en plein écran par-dessus Zieuton (`MetaViewController`, `finishRequest`). L'utilisateur reste ensuite sur Instagram jusqu'à « Revenir dans Zieuton » ou « ‹ Zieuton ».

Ce que fait la page :
- À la réception de `requested` (nouvelle demande), la page note en mémoire la demande à fêter (`celebrateFor`).
- Si la page est cachée (`document.visibilityState === "hidden"`), A attend. Il s'ouvre à l'évènement `visibilitychange`, quand Zieuton redevient visible.
- Si iOS ne cache pas la page derrière Instagram, A s'ouvre tout de suite, derrière Instagram. Il reste ouvert jusqu'au bouton : on le voit donc au retour.
- A n'est jamais rejoué. La note est seulement en mémoire, et elle est effacée dès qu'A s'ouvre. Fermer l'app ou recharger la page ramène sur B.
- Il n'y a pas de double confirmation : une demande « déjà en cours », la vérification après D, ou un fichier déjà vu prêt n'ouvrent jamais A.
- La notification « C'est demandé » touchée laisse A ouvert. La notification « prêt » le referme et mène à E.

Tests : `tests/page/ecrans-apres-demande.test.mjs` déroule le cycle complet : Instagram par-dessus, `requested`, retour, A, Continuer, B, Instagram rouvert et refermé, pas de A. Il couvre aussi le rechargement et les cas sans A.

**À vérifier sur iPhone (U1 à U3) :** ce que WebKit fait de la visibilité derrière un écran plein écran. Les deux cas sont couverts, mais seul l'iPhone dira lequel se produit. Une seule différence possible : si la page n'est pas cachée, la petite animation des confettis peut avoir déjà joué au retour.

## Point 2 : cas V2 du build 21 (vidéo du 21 nov., 12 h 45)

Ce que montre la vidéo :
1. « Commencer l'exportation » est touché.
2. Instagram redemande le mot de passe, puis montre « Nouvelle connexion à ton compte ».
3. Le bandeau dit « Bien joué ! Instagram enregistre… ». La touche « Commencer » a donc bien été vue (`sentAt` noté).
4. Vers 12 h 47, le bandeau passe à « À vérifier : ta ligne « En attente » ».
5. La liste ne montre qu'une seule carte en attente : « Demandée le 21/11/2026 ». Il y a aussi deux anciens exports prêts (« Expire le 22/11 » et « Expire le 24/11 »).

Ce que dit le code (`ExportProof.verdict`, bloc EXPORT-PROOF) : « à vérifier » veut dire qu'il y a une ligne en attente de plus qu'avant, mais pas une ligne **datée d'aujourd'hui** de plus qu'avant (`recent > recentBefore` faux, alors que `tapped` est vrai). La ligne « Demandée le 21/11/2026 » est bien reconnue comme datée du jour. Il faut donc qu'une ligne en attente datée du 21/11 ait été lue **avant** la touche (`recentBefore ≥ 1`).

Pistes encore ouvertes :
- Une demande du 21/11 en attente avant le tournage (un essai plus tôt ce jour-là, annulé ensuite) aurait été lue au début du parcours. À confirmer par Victor.
- Une lecture de la liste pendant la nouvelle authentification. Pour la trancher, il faut voir la page réelle d'Instagram à ce moment-là, qui n'est pas dans les pages reconstituées de `tests/lecteur/pages`.

Décision : **aucun critère de preuve n'est changé** dans FOU-131. D reste le repli honnête. Un correctif éventuel ira dans une PR de coque à part (FOU-126, build 22), seulement une fois la cause démontrée.

## Point 4 : suivi local expiré (plus de 5 jours)

Le comportement actuel : `reqPending()` considère qu'une demande de plus de 5 jours n'attend plus rien. Instagram garde le fichier 4 jours. La page repart alors sur le début du parcours (« Zieuton en haut, Instagram en bas »).

Ce qui protège déjà contre une deuxième demande : dans Instagram, avant toute touche, la coque lit la liste. Si une carte « En attente » est là (`ExportProof.alreadyPending`), le bandeau dit « Un instant : une demande est déjà là. N'en crée pas d'autre, je vérifie. » La demande est alors suivie comme « déjà en cours » (écran B, étape 1 « Demande trouvée chez Instagram »), sans écran A.

Risques qui restent (non traités dans FOU-131, à décider plus tard) :
- La page ne dit rien avant d'ouvrir Instagram : l'utilisateur voit l'écran de départ normal, comme pour une première demande.
- Si la liste d'Instagram ne s'affiche pas ou change de forme, la coque ne voit pas la carte en attente. Le bandeau peut alors guider vers « Créer une exportation » : risque de doublon.
- Sur le site web (hors app), il n'y a pas de coque, donc pas cette protection.
- Le cas est rare : une demande d'abonnés reste rarement plus de 5 jours en attente chez Instagram.

## Point 3 : B sans défiler

Vérifié par les tests, en clair et en sombre : titre, frise, « Découvrir Zieuton » et « Vérifier mon export » tiennent dans l'écran sur 320 × 568, 375 × 667 (iPhone SE) et 393 × 852 (iPhone 15). Les rappels et « Refaire la demande » sont plus bas. Le zieuteur rapetisse sur les écrans bas, puis disparaît sous 600 points de haut.

Grandes polices : la page utilise des tailles fixes. Le réglage « Taille du texte » d'iOS ne change donc pas ses polices (c'est déjà le cas aujourd'hui, FOU-131 n'y touche pas). Le « Zoom d'affichage » de l'iPhone revient à un écran de 320 points de large : il est testé.

## Tests sur iPhone (PR 1)

| N° | Quoi faire | Attendu |
| --- | --- | --- |
| U1 | Nouvelle demande, jusqu'à « Commencer », mot de passe, puis « Revenir dans Zieuton » | A, un seul bouton « Continuer dans Zieuton » |
| U2 | Toucher « Continuer dans Zieuton » | B, frise : étape 1 ✓, étape 2 en cours |
| U3 | Fermer Zieuton de force, rouvrir | B directement, jamais A |
| U4 | Sur B, « Vérifier mon export », puis revenir | Instagram sur la liste ; retour : B, pas de A |
| U5 | Sortie sans preuve (comme la vidéo du 21) | D, pastille orange, jamais « C'est parti » |
| U6 | Depuis D, « Vérifier dans Instagram » | B avec « Demande trouvée chez Instagram », sans A |
| U7 | Fichier prêt, app ouverte | E, étapes 1 à 3 cochées |
| U8 | Sur E, « Récupérer mon export », puis Télécharger toi-même | Import, puis bilan |
| U9 | Notifications coupées dans les Réglages iPhone | B dit « Tes notifications sont coupées », bouton Réglages |
| U10 | Mode sombre ; puis Zoom d'affichage (Réglages, Luminosité et affichage) | Tout lisible, titre, frise et deux boutons sans défiler |

## Point 5 : suivi perdu après la démo (vidéo du 21 nov., 13 h 50)

Ce que montre la vidéo : une demande suivie (« Demande trouvée chez Instagram »), la démo ouverte puis quittée, puis « Vérifier mon export ». Instagram montre un fichier prêt (« Expire le 25/11/2026 »), mais le bandeau dit « Vérifie la date de ton export. « En attente » : pas prêt » et Zieuton reste sur « Préparation chez Instagram ».

La cause, reproduite en test :
1. `enterDemo()` remplace les réglages par ceux de la démo : pas de demande, compte « a1 ».
2. `renderWeekly()` voit « pas de demande » et envoie à la coque `exportState { pending: false, acct: "a1" }`.
3. La coque (`ExportWatcher.pageEndedWait`) efface la demande suivie si elle est sur « a1 » ou sans compte noté, ce qui est le cas le plus courant. Plus de rappel, plus de preuve « prêt », et le bandeau passe en « sans demande suivie » (`GetBanner.unproven`).
4. En quittant la démo, `pending: true` est renvoyé, mais la coque l'ignore. La demande reste perdue côté coque, même si la page la garde.

Le correctif (page, sans Xcode) : la page n'envoie plus jamais `exportState` pendant la démo. Tests : `tests/page/demo-suivi.test.mjs`. Les trois cas (demande sur « a1 », sans compte, sur le 2e compte) échouent sans le correctif.

Une demande déjà perdue ne peut pas être rendue à la coque par la page. Pour la demande de la vidéo : sur la liste d'Instagram, le fichier « Expire le 25/11/2026 » est celui demandé le 21/11. On le télécharge soi-même, et l'import le vérifie.

ReadyProof sans référence : jamais « prêt » automatique, au mieux « vérifie la date » (déjà testé dans `tests/ios/ExportProofTests.swift`, cas r3 et r30c). Rien à changer.

Pour le build 22 (coque, à décider) :
- Défense en double : `pending: false` n'efface la demande que si la page dit pourquoi (import fait, demande refaite, effacement).
- Bandeau `unproven` quand un « Télécharger » est visible : ne plus dire « En attente : pas prêt », mais « Un fichier est disponible. Regarde sa date « Expire le » pour savoir si c'est le tien : le plus récent a la date la plus lointaine. »

## PR 2 : écran C, la démo pendant l'attente (22 nov.)

Page seule (`index.html`), sans Xcode.

- Bandeau du haut : « DÉMO · Données d'exemple » (avant : « Données inventées »). Pendant une vraie demande, le bouton s'appelle « Mon export » (avant : « Ma liste » / « Récupérer ma liste ») et ramène à B, ou à E quand le fichier est prêt ; le bandeau dit alors « Ton export est prêt 🎉 ». Sans demande en cours : « Quitter la démo », comme avant.
- « Données d'exemple » tient en entier à côté de « Mon export » dès 375 points (iPhone SE, iPhone 15). Plus étroit (zoom d'affichage), seule l'étiquette DÉMO reste.
- Visite par le zieuteur, à l'entrée dans la démo depuis B (« Découvrir Zieuton ») : 4 bulles posées sur les vraies cartes (Départs, Arrivées, Pas en retour, bouton Graphiques), « Suivant » (dernière : « J'ai compris ») et une croix qui arrête la visite. On reste libre dans la démo.
- Une seule fois : notée (`demoTourDone`) dans les vrais réglages dès le début de la visite, donc jamais rejouée, même après réouverture.
- La démo de la bienvenue (FOU-51) n'a pas de visite et n'écrit toujours rien sur le téléphone.

Tests : `tests/page/demo-visite.test.mjs` (ordre et cible des bulles, croix, pas rejouée, réouverture, fichier prêt pendant la démo, démo de bienvenue, 320/375/393 points en clair et en sombre : bulle dans l'écran, sans cacher sa carte, boutons de 44 points). Captures : `/mnt/project-files/abo-insta/fou131-pr2/`.

Tests iPhone : U11 à U14 du tableau de la proposition.
