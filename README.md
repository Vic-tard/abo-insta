# Zieuton

Vois qui se désabonne de ton compte Instagram, à partir de l'**export officiel** d'Instagram. Aucune connexion à ton compte, aucun bot : aucun risque de restriction.

## Utilisation

1. Ouvre l'app sur ton iPhone dans Safari, puis Partager → « Sur l'écran d'accueil ».
2. Suis le parcours guidé : choisis ton mode (Gmail ou téléphone), puis fais les étapes dans Instagram (Followers et suivi(e)s, Depuis le début, JSON).
3. Quand Instagram te prévient, l'app récupère ta liste (mode Gmail) ou tu touches « Importer mon fichier » (mode téléphone).
4. Refais un export quand tu veux : l'app te montre les départs et les arrivées.

## Données

Tout reste sur ton téléphone (IndexedDB + localStorage). Rien n'est envoyé sur internet. Garde une copie après chaque import avec « Sauvegarder une copie ».

## Vérifications automatiques (pour les développeurs)

À chaque pull request, GitHub lance tout seul une série de vérifications (onglet **Checks** de la PR). Si une case est rouge, on ne fusionne pas.

| Vérification | Ce qu'elle protège |
| --- | --- |
| Syntaxe JavaScript des pages | Une faute de frappe dans `index.html` laisserait l'app toute blanche. |
| Copie de `js/zieuton-core.js` | La lecture de l'export et la comparaison sont écrites dans `js/zieuton-core.js` et recopiées dans `index.html`. Les deux doivent rester identiques. |
| Tests d'import | Petit compte, 50 000 abonnés, export partiel refusé, export d'un autre compte, exports dans le désordre, même export importé deux fois, fichier qui n'est pas du JSON, .zip abîmé. |
| Console de la page | La page est ouverte dans un vrai navigateur, comme dans l'app puis comme dans Safari : aucune erreur ne doit apparaître. |
| Coque iPhone | Le projet Xcode doit compiler (sans signature, sur un Mac de GitHub). |

### Lancer les tests sur ton ordinateur

Il faut [Node.js](https://nodejs.org) (version 22 ou plus). Dans le Terminal, depuis le dossier du projet :

1. `npm test` : lance les tests d'import (quelques secondes, rien à installer).
2. `npm run check:syntax` : vérifie la syntaxe des pages et la copie de `js/zieuton-core.js`.
3. Pour la vérification de la console (facultatif) : `npm ci`, puis `npx playwright install chromium`, puis `npm run check:page`.

### Modifier la lecture de l'export ou la comparaison

Ce code est dans `js/zieuton-core.js` (et pas directement dans `index.html`). Après une modification :

1. `npm run sync` recopie le fichier dans `index.html` (entre les repères `ZIEUTON-CORE`).
2. `npm test` vérifie que tout marche encore.

`index.html` reste un seul fichier, qui marche sans aucune étape de construction : GitHub Pages et l'app le servent tel quel.
