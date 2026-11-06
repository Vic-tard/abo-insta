# Mises à jour de la page dans l'app iPhone (FOU-28)

La page Zieuton (`index.html`) est rangée dans l'app. À chaque ouverture, l'app regarde si une version plus
récente est en ligne et la télécharge. Ce document explique les trois sécurités qui empêchent une mauvaise
mise en ligne de bloquer un client, et comment les vérifier.

Ces sécurités sont dans la coque (`ios/Zieuton/WebViewController.swift`) : elles ne marchent qu'à partir du
build Xcode qui les contient. Les anciens builds continuent de prendre la dernière page en ligne, sans filet.

## 1. Retour automatique si une page ne démarre pas

- Quand l'accueil est affiché, la page envoie à l'app le message `{ type: "started", build: BUILD }`.
- Une page **téléchargée** a 10 secondes pour l'envoyer (le chrono repart à zéro si l'app passe en arrière-plan).
- Si le signal n'arrive pas, ou si l'app ou la page plante 2 fois de suite pendant le démarrage, l'app note ce
  `BUILD` comme **mauvais** : elle revient à la dernière page qui a bien démarré (sinon à celle rangée dans l'app)
  et ne retélécharge plus jamais ce `BUILD`. La version suivante (corrigée, avec un nouveau `BUILD`) passe normalement.
- La page rangée dans l'app n'est jamais abandonnée : c'est le dernier recours.

Conséquence pour chaque PR : la ligne `nativePost({ type: "started", build: BUILD })` à la fin du démarrage
de `index.html` ne doit jamais disparaître (un test le vérifie). Sans elle, toutes les nouvelles versions
seraient refusées.

## 2. Deux canaux : normal (stable) et test

`channel.json`, à la racine du dépôt (en ligne sur https://vic-tard.github.io/abo-insta/channel.json) :

```json
{
  "stable": "2026-11-06-1300",
  "urgence": false
}
```

- **Canal normal** (tous les clients) : l'app ne prend pas de page plus récente que `stable`.
- **Canal test** : l'app prend la dernière page en ligne, même pas encore validée.
- Passer un iPhone en canal test : Réglages → Aide et confidentialité → toucher 5 fois vite la ligne
  « Version » (ou le petit texte de version en bas des Réglages). Un message confirme, et la version affiche
  « · canal test ». 5 touches de plus : retour au canal normal.
- Si `channel.json` est absent ou mal écrit, l'app garde les dernières consignes lues. Si elle n'en a jamais lu,
  elle fait comme avant (dernière page en ligne).

### Le circuit d'une mise à jour de la page

1. La PR est fusionnée : la nouvelle page est en ligne, mais seuls les iPhones en **canal test** la reçoivent.
2. Victor l'ouvre sur son iPhone (canal test) et vérifie que tout va bien.
3. On la valide pour tout le monde : `npm run canal -- valider` (met `stable` = le `BUILD` actuel), PR, fusion.

## 3. Interrupteur d'urgence

`"urgence": true` dans `channel.json` : à la prochaine ouverture (ou au prochain retour dans l'app), **tous**
les iPhones, canal test compris, reviennent à la page rangée dans l'app et ne téléchargent plus rien.
`"urgence": false` : tout reprend normalement.

- Activer : `npm run canal -- urgence on`, PR, fusion (GitHub Pages met 1 à 2 minutes à publier).
- Éteindre : `npm run canal -- urgence off`, PR, fusion.
- On peut aussi modifier le fichier directement sur github.com (crayon ✏️ → « Commit changes »).

Attention : la page rangée dans l'app est celle du jour du build Xcode. L'urgence fait donc revenir à cette version-là.

## Tests automatiques

- `npm test` : `channel.json` bien écrit ; la page envoie bien le signal « started ».
- `npm run check:page` : dans un vrai navigateur, la page envoie « started » une seule fois avec son `BUILD`,
  et 5 touches sur la version demandent le changement de canal (seulement avec une coque version 8).
- `npm run test:ios` (Mac seulement, lancé par les vérifications GitHub) : les règles de choix de la page
  (`PageGuard`) : page cassée, deux plantages, canaux, urgence, lecture de `channel.json`.

## Vérification à la main sur l'iPhone (après le build Xcode)

À faire une fois, avec l'iPhone de Victor branché au Mac et l'app lancée par ▶ dans Xcode
(les messages « Zieuton : … » s'affichent en bas de Xcode).

1. **Comportement normal.** Ouvrir l'app : l'accueil s'affiche comme avant. Rien d'autre ne change.
2. **Canal test.** Réglages → Aide et confidentialité → 5 touches sur « Version » : message « Canal test activé »,
   la version affiche « · canal test ». Refaire 5 touches : « Canal normal ».
3. **Page cassée.** Passer en canal test. Fusionner une PR d'essai qui casse la page exprès (par exemple
   `throw new Error("essai")` juste avant la ligne `started`, avec un nouveau `BUILD`). Ouvrir l'app : après
   environ 10 secondes, elle revient toute seule à la page d'avant, et Xcode affiche
   « Zieuton : la page … n'a pas démarré ». Fermer et rouvrir l'app : la page cassée ne revient pas.
   Annuler la PR d'essai (nouvelle PR avec un `BUILD` encore plus récent) : cette version-là est bien reçue.
4. **Canal normal protégé.** Pendant l'étape 3, un iPhone en canal normal ne reçoit pas la page d'essai.
5. **Urgence.** Mettre `"urgence": true`, fusionner, attendre 2 minutes, rouvrir l'app (ou y revenir) :
   la version affichée dans Réglages est celle du build Xcode. Remettre `false` : la dernière page revient.
