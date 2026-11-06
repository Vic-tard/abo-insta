# Zieuton pour iPhone

L'app contient la page Zieuton (`index.html`, le logo et les images du guide, à la racine du dépôt) :
elle s'ouvre tout de suite, même sans internet. Elle ajoute « Partager → Zieuton » :
touche ton fichier Instagram (.zip) dans Safari ou dans Fichiers, puis Partager, puis Zieuton. L'import se fait tout seul.

Mises à jour de la page : à chaque ouverture (et à chaque retour dans l'app), l'app regarde si une version plus
récente est en ligne sur https://vic-tard.github.io/abo-insta/ (ligne `const BUILD` de `index.html`).
Si oui, elle la télécharge, la garde sur le téléphone et l'affiche aussitôt (sauf pendant un import ou quand
Instagram est ouvert dans l'app). Pas besoin de réinstaller l'app pour une retouche de page.
Sécurité : une page téléchargée qui ne démarre pas (plantage, écran bloqué) est abandonnée toute seule,
l'app revient à la version d'avant. Le fichier `channel.json` à la racine du dépôt dit quelle version est
validée pour tout le monde, et contient un interrupteur d'urgence. Tout est expliqué dans `docs/MISES-A-JOUR.md`.
Xcode ne sert que pour la partie native (achats, notifications, partage, icône, écran de lancement)
et pour envoyer une nouvelle version à Apple. Chaque nouvelle version envoyée embarque la page du moment.

La page s'affiche toujours à l'adresse du site : les données gardées sur le téléphone ne changent pas.

L'app s'appelait Zyeuto avant. Les identifiants techniques (`fr.zyeuto.app`, achats `fr.zyeuto.plus.*`)
gardent l'ancien nom exprès : personne ne les voit, et Apple ne permet pas de les changer une fois créés.

## Installer sur ton iPhone (gratuit, avec ton identifiant Apple)

1. Sur le Mac, ouvre Xcode, puis Xcode → Réglages → Comptes → « + » → Apple ID, et connecte-toi.
2. Ouvre `ios/Zieuton.xcodeproj` (double-clic).
3. Dans la colonne de gauche, clique sur Zieuton (l'icône bleue tout en haut), puis l'onglet « Signing & Capabilities ».
   Dans « Team », choisis ton nom « (Personal Team) ».
   Si Xcode dit que l'identifiant est déjà pris, remplace `fr.zyeuto.app` par `fr.zyeuto.victor`.
4. Branche ton iPhone au Mac avec le câble, et choisis-le tout en haut au milieu de Xcode.
5. Clique sur ▶ (en haut à gauche).
6. La première fois, l'iPhone demande deux choses :
   - Réglages → Confidentialité et sécurité → Mode développeur → activer (l'iPhone redémarre) ;
   - Réglages → Général → VPN et gestion de l'appareil → ton identifiant → Faire confiance.
   Puis clique encore sur ▶.

Avec un identifiant Apple gratuit, l'app marche 7 jours : il suffit de recliquer sur ▶ pour la prolonger.
Le compte développeur payant (99 €/an) sert pour TestFlight (faire tester par d'autres) et l'App Store.

## Envoyer une version sur TestFlight (compte développeur payant)

1. Dans « Signing & Capabilities », choisis l'équipe payante (ton nom, sans « Personal Team »).
2. Tout en haut au milieu, à la place de l'iPhone, choisis « Any iOS Device (arm64) ».
3. Menu Product → Archive. Quand c'est fini, la fenêtre Organizer s'ouvre.
4. Distribute App → App Store Connect → Distribute (laisser Xcode gérer le numéro de version).
5. Dix à trente minutes plus tard, la version apparaît dans App Store Connect → Zieuton → TestFlight.

À chaque nouvelle version : refaire 2 à 4. Xcode augmente le numéro de build tout seul.
La page de confidentialité demandée par Apple : https://vic-tard.github.io/abo-insta/confidentialite.html

## Bon à savoir

- Les données de l'app sont séparées de celles du site : la première fois, importe ta copie de sauvegarde
  (« J'ai une copie de sauvegarde ») ou refais un import.
- Le mode Gmail n'est pas proposé dans l'app : Google refuse la connexion à l'intérieur d'une app.
- Les liens (Instagram, profils) s'ouvrent dans Safari ou dans Instagram. Pour revenir, touche « ◀ Zieuton » en haut à gauche.

## Zieuton Plus (achats intégrés)

Gratuit : les deux premiers imports, puis une mise à jour par mois. Zieuton Plus débloque les mises à jour illimitées :
`fr.zyeuto.plus.mois` (2,99 €/mois), `fr.zyeuto.plus.an` (14,99 €/an), `fr.zyeuto.plus.avie` (29,99 € une fois).
Dans Safari, le site n'affiche plus que « Zieuton arrive sur l'App Store » : tout se passe dans l'app.

### Tester sans payer (faux magasin)

Le fichier `Zieuton/Zieuton.storekit` est un faux App Store : les achats sont simulés, aucun argent n'est pris.
Il est déjà branché sur le bouton ▶. Si l'écran Plus affiche « L'achat n'a pas pu se faire » :
Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration → choisir `Zieuton.storekit`.

Pour recommencer à zéro : Debug → StoreKit → Manage Transactions…, sélectionner les achats et les supprimer.

### Pour de vrai (plus tard)

Compte développeur Apple (99 €/an), puis dans App Store Connect : contrat « Apps payantes », banque et impôts,
programme petites entreprises (15 %), et les trois produits avec exactement les mêmes identifiants.

## Pour la suite

`Zieuton.xcodeproj` a été généré avec le script Ruby `xcodeproj`. On peut aussi le modifier directement dans Xcode.

## Sauvegarde iCloud automatique

Après chaque changement, l'app range tout l'historique du téléphone (les 3 comptes, réglages, zieuteurs, jeux)
dans un fichier caché de l'iCloud de l'utilisateur (`zieuton-icloud.zieuton`, conteneur `iCloud.fr.zyeuto.app`).
Sur un nouvel iPhone (ou après réinstallation), Zieuton propose « Reprendre mon historique ». Rien ne passe par un serveur.

Dans Xcode, une seule fois : Signing & Capabilities → la rubrique iCloud (déjà présente grâce à `Zieuton.entitlements`)
→ cocher « iCloud Documents » et le conteneur `iCloud.fr.zyeuto.app` (bouton « + » s'il n'existe pas encore).
