# Zyeuto pour iPhone

L'app affiche Zyeuto (le site https://vic-tard.github.io/abo-insta/) et ajoute « Partager → Zyeuto » :
touche ton fichier Instagram (.zip) dans Safari ou dans Fichiers, puis Partager, puis Zyeuto. L'import se fait tout seul.

Les mises à jour du site arrivent dans l'app sans la réinstaller.

## Installer sur ton iPhone (gratuit, avec ton identifiant Apple)

1. Sur le Mac, ouvre Xcode, puis Xcode → Réglages → Comptes → « + » → Apple ID, et connecte-toi.
2. Ouvre `ios/Zyeuto.xcodeproj` (double-clic).
3. Dans la colonne de gauche, clique sur Zyeuto (l'icône bleue tout en haut), puis l'onglet « Signing & Capabilities ».
   Dans « Team », choisis ton nom « (Personal Team) ».
   Si Xcode dit que l'identifiant est déjà pris, remplace `fr.zyeuto.app` par `fr.zyeuto.victor`.
4. Branche ton iPhone au Mac avec le câble, et choisis-le tout en haut au milieu de Xcode.
5. Clique sur ▶ (en haut à gauche).
6. La première fois, l'iPhone demande deux choses :
   - Réglages → Confidentialité et sécurité → Mode développeur → activer (l'iPhone redémarre) ;
   - Réglages → Général → VPN et gestion de l'appareil → ton identifiant → Faire confiance.
   Puis clique encore sur ▶.

Avec un identifiant Apple gratuit, l'app marche 7 jours : il suffit de recliquer sur ▶ pour la prolonger.
Le compte développeur payant (99 €/an) n'est utile que pour la publier sur l'App Store.

## Bon à savoir

- Les données de l'app sont séparées de celles du site : la première fois, importe ta copie de sauvegarde
  (« J'ai une copie de sauvegarde ») ou refais un import.
- Le mode Gmail n'est pas proposé dans l'app : Google refuse la connexion à l'intérieur d'une app.
- Les liens (Instagram, profils) s'ouvrent dans Safari ou dans Instagram. Pour revenir, touche « ◀ Zyeuto » en haut à gauche.

## Zyeuto Plus (achats intégrés)

Gratuit : les deux premiers imports, puis une mise à jour par mois. Zyeuto Plus débloque les mises à jour illimitées :
`fr.zyeuto.plus.mois` (1,99 €/mois), `fr.zyeuto.plus.an` (9,99 €/an), `fr.zyeuto.plus.avie` (19,99 € une fois).
Sur le site (hors app), rien n'est vendu et il n'y a pas de limite.

### Tester sans payer (faux magasin)

Le fichier `Zyeuto/Zyeuto.storekit` est un faux App Store : les achats sont simulés, aucun argent n'est pris.
Il est déjà branché sur le bouton ▶. Si l'écran Plus affiche « L'achat n'a pas pu se faire » :
Product → Scheme → Edit Scheme… → Run → Options → StoreKit Configuration → choisir `Zyeuto.storekit`.

Pour recommencer à zéro : Debug → StoreKit → Manage Transactions…, sélectionner les achats et les supprimer.

### Pour de vrai (plus tard)

Compte développeur Apple (99 €/an), puis dans App Store Connect : contrat « Apps payantes », banque et impôts,
programme petites entreprises (15 %), et les trois produits avec exactement les mêmes identifiants.

## Pour la suite

`Zyeuto.xcodeproj` a été généré avec le script Ruby `xcodeproj`. On peut aussi le modifier directement dans Xcode.
