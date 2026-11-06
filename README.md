# Zieuton

Vois qui se désabonne de ton compte Instagram, à partir de l'**export officiel** d'Instagram. Aucune connexion à ton compte, aucun bot : aucun risque de restriction.

Zieuton est une **app iPhone** (iOS 17 ou plus). Elle est en test sur TestFlight ; sortie sur l'App Store visée le 3 décembre 2026. Le site https://vic-tard.github.io/abo-insta/ affiche seulement « Bientôt sur l'App Store » quand on l'ouvre dans un navigateur.

**Ce que fait l'app, et ce qu'elle ne fera pas : voir [`docs/SPEC.md`](docs/SPEC.md).** C'est la référence en cas de doute.

## Utilisation

1. Ouvre Zieuton sur ton iPhone et touche « Demande ta liste à Instagram ».
2. Dans Instagram (ouvert dans l'app), le bandeau guide te dit quoi toucher : garder seulement « Followers et suivi(e)s », période « Depuis le début », format JSON, « Une fois ».
3. Quand ta liste est prête, c'est toi qui touches « Télécharger » : Zieuton récupère le fichier et l'importe tout seul.
4. Refais un export quand tu veux : l'app te montre les départs et les arrivées.

## Données

Tout reste sur ton téléphone. Rien n'est envoyé sur un serveur : la seule copie hors du téléphone est la sauvegarde automatique dans ton iCloud. Tu peux aussi garder un fichier `.zieuton` de sauvegarde.

## Pour les développeurs

- [`docs/SPEC.md`](docs/SPEC.md) : ce que fait l'app, ce qu'elle ne fera pas.
- [`CLAUDE.md`](CLAUDE.md) : architecture et règles de travail (une PR par tâche, tests avant la PR, numéro `BUILD`, Xcode nécessaire ou non).

## Vérifications automatiques

À chaque pull request, GitHub lance tout seul une série de vérifications (onglet **Checks** de la PR). Si une case est rouge, on ne fusionne pas.

| Vérification | Ce qu'elle protège |
| --- | --- |
| Syntaxe JavaScript des pages | Une faute de frappe dans `index.html` laisserait l'app toute blanche. |
| Copie de `js/zieuton-core.js` | La lecture de l'export et la comparaison sont écrites dans `js/zieuton-core.js` et recopiées dans `index.html`. Les deux doivent rester identiques. |
| Tests d'import | Petit compte, 50 000 abonnés, export partiel refusé, export d'un autre compte, exports dans le désordre, même export importé deux fois, fichier qui n'est pas du JSON, .zip abîmé. |
| Console de la page | La page est ouverte dans un vrai navigateur, comme dans l'app puis comme sur le site : aucune erreur ne doit apparaître. |
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
