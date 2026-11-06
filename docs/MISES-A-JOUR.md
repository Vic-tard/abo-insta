# Mises à jour de la page dans l'app iPhone (FOU-28, FOU-29)

La page Zieuton (`index.html`) est rangée dans l'app. À chaque ouverture, l'app regarde si une version plus
récente est en ligne et la télécharge. Ce document explique les sécurités qui empêchent une mauvaise
mise en ligne de bloquer un client (parties 1 à 3), celle qui empêche quelqu'un d'autre que Victor de
pousser une page dans l'app (partie 4, la signature), et comment les vérifier.

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

## 4. Signature : seul Victor peut envoyer une page dans l'app (FOU-29)

Le robot de mise en ligne signe la page avec une **clé secrète** que seul Victor possède. L'app connaît la
**clé publique** qui va avec (elle est écrite dans la coque). Avant d'enregistrer une page téléchargée, l'app
vérifie la signature : si elle est absente ou fausse, elle **garde la page qu'elle a déjà** (et ignore aussi un
`channel.json` mal signé). Même quelqu'un qui arriverait à modifier le site ne pourrait donc rien installer
dans les iPhones sans cette clé.

- Le robot : `.github/workflows/publier.yml`. À chaque fusion sur `main`, il signe `index.html` et `channel.json`,
  publie `index.html.sig` et `channel.json.sig` à côté, puis met le site en ligne.
- La clé secrète n'est **jamais** dans le dépôt : elle est rangée dans GitHub, dans le secret `PAGE_SIGNING_KEY`.
- Si le secret est vide ou ne va pas avec la clé écrite dans l'app, le robot s'arrête en rouge et rien n'est mis
  en ligne (le site reste comme avant).
- Ça ne marche qu'à partir du build Xcode qui le contient (coque version 9). Les anciens builds ne vérifient rien.

### À faire une seule fois (Victor, environ 15 minutes)

**A. Créer la clé sur le Mac**

1. Ouvre le **Terminal** : `Cmd` + `Espace`, tape `Terminal`, `Entrée`.
2. Copie toute la ligne ci-dessous, colle-la dans le Terminal (`Cmd` + `V`) et appuie sur `Entrée`.
   Elle télécharge `scripts/creer-cle.swift` dans Téléchargements et le lance :

   ```
   curl -sL -o ~/Downloads/creer-cle.swift https://github.com/Vic-tard/abo-insta/raw/main/scripts/creer-cle.swift && swift ~/Downloads/creer-cle.swift
   ```

3. Attends 10 à 20 secondes. Deux longues lignes de lettres apparaissent :
   - **1) CLÉ SECRÈTE** (environ 44 caractères, finit souvent par `=`),
   - **2) CLÉ PUBLIQUE** (même longueur).

   Si un message parle de « license » ou de « xcrun » : ouvre Xcode une fois, accepte ce qu'il propose, puis
   recolle la ligne de l'étape 2.

**B. Ranger la clé secrète en lieu sûr**

4. Sélectionne la ligne sous « CLÉ SECRÈTE » (double-clic dessus, ou glisse la souris), `Cmd` + `C`.
5. Ouvre l'app **Mots de passe** du Mac → **+** (nouveau mot de passe). Titre : `Zieuton clé de signature`,
   Nom d'utilisateur : `PAGE_SIGNING_KEY`, Mot de passe : `Cmd` + `V`. Enregistre.
   (C'est ta sauvegarde : si tu la perds, voir « Clé perdue » plus bas.)

**C. La mettre dans les secrets GitHub**

6. Ouvre https://github.com/Vic-tard/abo-insta/settings/secrets/actions
   (ou : dépôt → **Settings** → menu de gauche **Secrets and variables** → **Actions**).
7. Touche le bouton vert **New repository secret**.
8. **Name** : `PAGE_SIGNING_KEY` (exactement, en majuscules). **Secret** : `Cmd` + `V` (la clé secrète).
9. Touche **Add secret**. GitHub ne te la remontrera plus jamais : c'est normal.

**D. Donner la clé publique**

10. Copie la ligne sous « CLÉ PUBLIQUE » et colle-la dans la discussion avec Claude. Elle n'est pas secrète :
    elle sera écrite dans l'app. Tant qu'elle n'y est pas, une case reste rouge sur la PR (c'est voulu).
11. Ferme la fenêtre du Terminal. Ne mets la clé secrète nulle part ailleurs (ni mail, ni message, ni note).

**E. Activer la double authentification GitHub (indispensable)**

La clé est aussi protégée que ton compte GitHub. Si ce n'est pas déjà fait :

12. Ouvre https://github.com/settings/security (photo en haut à droite → **Settings** → **Password and authentication**).
13. Dans **Two-factor authentication**, touche **Enable two-factor authentication** et suis les étapes
    (le plus simple : l'app **Mots de passe** de l'iPhone ou du Mac sait lire le QR code et donner les codes).
14. **Garde les codes de secours** (« recovery codes ») dans l'app Mots de passe, avec la clé.

**F. Juste avant de dire « fusionne »**

15. Ouvre https://github.com/Vic-tard/abo-insta/settings/pages
16. Dans **Build and deployment**, à **Source**, choisis **GitHub Actions** (au lieu de « Deploy from a branch »).
    À partir de là, c'est le robot « Publier le site » qui met le site en ligne (avec la signature).
17. Dis « fusionne ». Après la fusion, onglet **Actions** du dépôt : la ligne **Publier le site** doit devenir
    verte en 1 à 2 minutes. Vérification : https://vic-tard.github.io/abo-insta/index.html.sig affiche une ligne
    de lettres.

Ensuite seulement, fais le build Xcode (build 3) : il contient la clé publique.

### Clé perdue ou volée

- **Perdue** (plus dans Mots de passe, et il faut changer le secret) : refaire A à D avec une nouvelle clé. La
  nouvelle clé publique va dans l'app → nouveau build Xcode. Les iPhones qui ont l'ancien build gardent leur page
  actuelle (rien ne casse) jusqu'à leur mise à jour par l'App Store.
- **Volée** (quelqu'un d'autre l'a vue) : changer tout de suite le secret GitHub (étape C avec une nouvelle clé,
  bouton **Update** sur le secret existant), puis même chose que « Perdue ».

## Tests automatiques

- `npm test` : `channel.json` bien écrit ; la page envoie bien le signal « started ».
- `npm run check:page` : dans un vrai navigateur, la page envoie « started » une seule fois avec son `BUILD`,
  et 5 touches sur la version demandent le changement de canal (seulement avec une coque version 8).
- `npm run test:ios` (Mac seulement, lancé par les vérifications GitHub) : les règles de choix de la page
  (`PageGuard`) : page cassée, deux plantages, canaux, urgence, lecture de `channel.json` ; et la signature
  (`PageSignature`) : bonne, page modifiée, autre clé, absente, et une signature faite par le robot.
- `npm test` vérifie aussi le robot de signature (`tests/signature.test.mjs`) et que la clé publique est bien
  écrite dans l'app.

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
6. **Signature (FOU-29).** Après la première mise en ligne signée, en canal test : une nouvelle page arrive
   normalement (Xcode n'affiche pas « refusée »). Pour voir le refus : Settings → Pages → Source « Deploy from
   a branch » (le site repart sans signature), fusionner une petite PR avec un nouveau `BUILD`, rouvrir l'app :
   Xcode affiche « Zieuton : page … refusée, signature absente ou invalide » et l'app garde sa page.
   Remettre Source sur « GitHub Actions » et relancer **Publier le site** (onglet Actions → Run workflow).
