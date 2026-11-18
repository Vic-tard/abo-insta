# Vidéo iPhone du 18 nov. 2026 (14 h 30, build 17) : diagnostic et correctif 4 (FOU-126)

Vidéo de 30 s, regardée image par image. Elle a été tournée avec le **build 17**, donc **sans** les correctifs #146 à #148.

## Ce qu'on voit, seconde par seconde

| Moment | Écran d'Instagram | Bandeau de Zieuton |
|---|---|---|
| 0 à 1 s | Fenêtre de la liste, défilée jusqu'à « En attente » : carte « Demandée le 18/11/2026 », bouton Annuler | « Je ne vois pas encore de nouvelle demande » |
| 2 à 6 s | Même liste, puis remontée en haut : « Exporter vos informations », « Créer une exportation », « Téléchargements disponibles » | « Je n'ai pas encore vu ta demande : Vérifier son état » |
| 7 à 12 s | Trois cartes prêtes : **« Expire le 22/11/2026 · Moins de 1 Mo »**, « Expire le 21/11/2026 » (deux fois), chacune avec Télécharger et Annuler. Puis la carte « En attente » du 18/11 | « Demande à vérifier : regarde la liste » |
| 13 s | Même liste | Retour à « Je ne vois pas encore de nouvelle demande » |
| 14 à 18 s | Retour dans Zieuton : écran « Zieuton en haut, Instagram en bas », puis « J'ai compris, on y va » | |
| 19 à 25 s | Instagram se rouvre sur la liste | « Touche Créer une exportation », avec le cercle, alors qu'une demande du jour est dans la liste |
| 26 à 28 s | Liste défilée jusqu'à « En attente » | **« Oups, pas le bon bouton ! »** |

## Une découverte importante : la carte d'un fichier prêt

La vidéo montre pour la première fois le haut d'une carte prête. Elle ne dit **pas** « Demandée le … » mais **« Expire le 22/11/2026 · Moins de 1 Mo »**. Instagram garde le fichier 4 jours (« Vous disposerez de 4 jours pour télécharger les fichiers »).

Le 17 nov., le haut de cette carte était caché. Dans #146, j'avais **supposé** qu'elle ressemblait à la carte « En attente ». Cette supposition était écrite en tête de la page de test, mais c'était une erreur du même type que celles du build 17. Conséquence, si #146 à #148 partaient tels quels :
- Zieuton n'aurait **jamais** dit « Ton fichier est prêt ». C'est sans danger, puisqu'il n'y a pas de faux « prêt », mais la notification C ne serait jamais partie.
- Le bandeau serait resté sur « Pas encore prêt » ou « Vérifie la date ».

## Ce que #146, #147 et #148 corrigent déjà

| Problème vu | Corrigé par | Comment |
|---|---|---|
| « Je ne vois pas encore de nouvelle demande » alors que la carte du 18/11 est là | #146 | La liste est lue dans la fenêtre, carte par carte, avec sa date « Demandée le … ». La demande du jour est confirmée |
| « Demande à vérifier » sans raison | #146 | Même cause : la date n'était pas lue |
| Mauvais « Touche Télécharger » pour récupérer le fichier | #147 | Le bandeau suit la preuve « prêt » |
| « Une demande était déjà en cours » à tort | #148 | Textes « Une demande d'aujourd'hui est en cours » |

## Ce qui restait ouvert (correctif 4, PR séparée)

1. **Carte prête « Expire le … » (principe 6).** Elle est maintenant lue comme une carte prête, jamais comme une demande en attente. La preuve « prêt » compte les fichiers qui expirent au plus tôt 4 jours après le jour de la demande. Un fichier qui expire plus tôt est forcément un ancien export. Les fichiers déjà prêts le même jour forment la référence. « Prêt » ne vient que si la demande a quitté « En attente » **et** qu'un fichier de plus est arrivé. Si un fichier arrive pendant que la demande est encore « En attente », la réponse reste « pas encore prêt ».
2. **Retour vers « Créer une exportation » avec une demande déjà là (principes 1 et 7).** Zieuton ne reconnaissait une demande déjà en cours que si « Créer une exportation » restait visible 1,5 s. Avec la liste défilée, ou dans la fenêtre du 17 nov., ça n'arrivait pas : c'était encore vrai avec #146. Désormais, une liste lue depuis 1,5 s suffit. En attendant, le bandeau dit « Un instant : une demande est déjà là », sans cercle sur « Créer une exportation ».
3. **« Oups, pas le bon bouton ! » sur la liste (principe 3).** Sur la liste des exports, changer d'onglet, toucher une carte ou faire défiler ne déclenche plus jamais d'alerte.
4. **Texte rassurant quand la preuve manque (principes 2, 3 et 5).** Si « Commencer » a été touché sans preuve mais qu'une carte « En attente » du jour est à l'écran, le bandeau dit : « Demande du jour trouvée : ne refais rien ». Une touche sur le bandeau ouvre la confirmation « Cette ligne est-elle ta demande ? ».
5. **Confirmation à la main (principe 2).** Quand l'utilisateur confirme lui-même la ligne, Zieuton ne dit plus « C'est demandé ✓ », car ce n'est pas une preuve automatique. Il dit « Une demande d'aujourd'hui est en cours ✓ ». Le réglage de la demande (« Une fois », « Depuis le début », JSON) est quand même vérifié.
6. **« Revenir dans Zieuton » (principe 4).** Le bouton apparaît aussi quand la preuve est incertaine (« Demande à vérifier », ou une ligne du jour sans preuve). En revenant ensuite, la demande est reconnue tout de suite (point 2) et la page passe à l'attente.
7. **Import (principe 8).** Rien ne change dans le téléchargement ni l'import du fichier.

## Réserves finales de ChatGPT (18 nov., 14 h 09), traitées

1. **Plus de boucle en sortant d'Instagram sans preuve.** Si Instagram est fermé avec un signe de demande (« Commencer » touché, ligne à vérifier, ou ligne « En attente » du jour vue) mais sans preuve automatique, la page de Zieuton passe **directement** sur l'écran d'attente « Demande à vérifier ». Elle ne repasse jamais par « Zieuton en haut, Instagram en bas ».
   - Le texte de cet écran est honnête : « J'ai vu une demande d'aujourd'hui chez Instagram, sans pouvoir confirmer que c'est la tienne. Ne refais rien : vérifie-la. »
   - L'écran ne fait aucune promesse : pas de « C'est demandé », pas de rappel, pas de guet.
   - Le bouton « Vérifier dans Instagram » rouvre la liste. La demande déjà là y est reconnue, puis l'attente normale reprend, sans refaire le parcours.
   - Une demande déjà prouvée n'est jamais rétrogradée.
   - Sans aucun signe de demande (Instagram ouvert puis refermé tout de suite), rien n'est noté, puisque rien n'a été demandé.
   - Avec une coque plus ancienne, rien ne change. La page actuellement sur `main` ignore ce nouveau message sans erreur, et c'est testé.
2. **Fichier prêt reconnu seulement si la correspondance est sûre.**
   - Chaque carte a une empreinte : le compte, la catégorie et le format, sans les dates ni les boutons. Un fichier d'un autre compte ou d'une autre catégorie ne compte jamais.
   - La référence n'est fixée que s'il y a **une seule** carte « En attente » du jour. Avec deux, on ne sait pas laquelle suivre, donc jamais « prêt » automatique.
   - « Prêt » demande **exactement un** fichier de plus que la référence, revu au moins 2 s plus tard. Si un autre export devient prêt en même temps, il y a deux fichiers nouveaux : « à vérifier ». Si la carte « En attente » manque une seule fois dans la lecture, « prêt » retombe.
   - Si un ancien fichier du jour expire ou est supprimé, il n'y en a pas « un de plus » : « à vérifier ».
   - Dans tous ces cas : pas de notification « prêt », et pas de cercle sur Télécharger.
3. **Numéro de build.** Ce correctif prépare le build **21**. La doc de #149 est corrigée en conséquence.

## Limites

- Les pages de test sont **reconstituées** d'après la vidéo : mêmes textes, mêmes boutons, balises neutres. Elles prouvent que Zieuton lit ces textes, pas qu'il lira toujours le vrai code d'Instagram.
- La date d'expiration est lue seulement au format vu, « Expire le JJ/MM/AAAA ». Écrite autrement, elle ne compte pas : jamais de « prêt » automatique, l'utilisateur vérifie lui-même.
- La règle des 4 jours vient du texte d'Instagram. Si Instagram la change, Zieuton peut ne plus dire « prêt », mais il ne dira jamais « prêt » à tort.

## Scénario de test complet sur iPhone (build 21, qui contiendra #146 à #148 et le correctif 4)

Préparation : idéalement, avoir déjà au moins un fichier prêt dans la liste (comme dans la vidéo).

| N° | Action | Résultat attendu |
|---|---|---|
| S1 | Zieuton → « J'ai compris, on y va » → suivre le bandeau jusqu'à « Commencer l'exportation » | Bandeau et notification « C'est demandé ✓ ». Bouton « Revenir dans Zieuton ». La carte « Demandée le » du jour est dans « En attente » |
| S2 | Rester dans Instagram, faire défiler la liste, changer d'onglet, toucher une carte | Jamais « Oups, pas le bon bouton ! ». Jamais « Touche Créer une exportation » |
| S3 | Toucher « Revenir dans Zieuton » | Écran d'attente « Instagram prépare ta liste ». Rien à refaire |
| S4 | Fermer Zieuton (balayer vers le haut), attendre 1 min, rouvrir | Toujours l'écran d'attente, sans nouvelle demande proposée. « C'est demandé » n'est pas renvoyé |
| S5 | Rouvrir Instagram depuis l'attente (« Vérifier ») tant que la carte est « En attente » | « Pas encore prêt : en attente ». Aucun cercle, aucun « Touche Télécharger » |
| S6 | Attendre que la carte quitte « En attente » et qu'une carte « Expire le » (date du jour + 4) arrive | « C'est prêt ! Touche Télécharger ». Notification « Ton fichier est prêt 🎉 » une seule fois. Cercle seulement s'il n'y a qu'un « Télécharger » à l'écran |
| S7 | Toucher soi-même « Télécharger » sur la carte la plus récente | Import comme au build 15 (inchangé) |
| S8 | Variante de la vidéo : revenir dans Zieuton **avant** la preuve | Zieuton montre « Demande à vérifier » (jamais « Zieuton en haut »). « Vérifier dans Instagram » : Instagram s'ouvre : « Un instant : une demande est déjà là », puis « ✓ Demande du jour en cours : rien d'autre à faire ». Jamais « Touche Créer une exportation » |
| S9 | Variante sans preuve : la carte du jour est visible mais Zieuton ne l'a pas confirmée | « Demande du jour trouvée : ne refais rien ». Toucher le bandeau donne « Cette ligne est-elle ta demande ? ». « Oui » donne « Une demande d'aujourd'hui est en cours ✓ », jamais « C'est demandé » |
| S10 | Deux demandes le même jour : une première déjà prête (expire J+4), puis une nouvelle | Tant que la nouvelle est « En attente » : « pas encore prêt ». « Prêt » seulement quand une 2e carte « Expire le J+4 » arrive |
| S11 | Mode avion pendant l'attente, puis retour du réseau | « Instagram ne répond pas » puis reprise, jamais « prêt » sans la liste |
| S12 | Toucher « Commencer l'exportation », puis fermer Instagram tout de suite (avant « C'est demandé ») | Zieuton montre « Demande à vérifier », jamais « Zieuton en haut, Instagram en bas ». Pas de notification « C'est demandé » |
| S13 | Depuis « Demande à vérifier », toucher « Vérifier dans Instagram » | La liste s'ouvre, « Un instant : une demande est déjà là », puis « Demande du jour en cours ». De retour dans Zieuton : attente normale |
| S14 | Ouvrir Instagram depuis Zieuton puis le refermer sans rien toucher | Pas d'attente inventée : Zieuton reste avant la demande |
| S15 | Deux comptes Instagram : un fichier prêt arrive pour l'autre compte | Jamais « C'est prêt » pour celui-ci |

## Bandeau plus court (demande de Victor, 18 nov. 14 h 57)

Le bandeau doit se comprendre sans tout lire. Un titre court dit la situation, et une seule phrase courte dit quoi faire (75 caractères au plus, vérifié par un test).

| Situation | Titre | Phrase |
|---|---|---|
| Demande prouvée | **C'est demandé** (au-dessus, en petit : ✓ Rien d'autre à faire ici) | Instagram prépare ton fichier. Tu peux revenir dans Zieuton. (+ bouton) |
| Demande du jour déjà là | **Demande du jour en cours** (au-dessus : ✓ Rien d'autre à faire ici) | idem |
| On la reconnaît | Un instant : une demande est déjà là | N'en crée pas d'autre, je vérifie. |
| Ligne du jour sans preuve | Demande du jour trouvée : ne refais rien | C'est la tienne ? Touche ce bandeau pour la suivre. (+ bouton) |
| Ligne nouvelle à vérifier | À vérifier : ta ligne « En attente » | Datée d'aujourd'hui ? Touche ce bandeau. Sinon, ne refais rien. |
| Pas encore vue | Pas encore vue : vérifie son état | Ne la refais pas : touche ce bandeau, j'ouvre la liste. |
| Récupérer, pas prêt | Pas encore prêt : en attente | Ta demande du 18/11 est en préparation. Tu peux revenir plus tard. |
| Récupérer, prêt | C'est prêt ! Touche Télécharger | Sur la ligne de ta demande du 18/11. |
| Récupérer, sans preuve | Vérifie la date de ton export | « En attente » : pas prêt. Le plus récent a la date la plus lointaine. |

### Bandeau centré (Victor, 18 nov. 15 h 03)

Tout est centré. En haut, les 4 étapes, avec le zieuteur à droite. Au milieu, en gros, la situation. Dessous, le bouton (« Revenir dans Zieuton » ou le bouton à toucher). En bas, en petit, la consigne. Le fond du bandeau garde sa couleur selon la situation : lilas quand tout est bon, rose quand il y a une action, corail quand il y a une alerte.
