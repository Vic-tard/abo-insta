# Plan B si Apple refuse la vue Instagram intégrée (FOU-33)

> Rédigé le 16 novembre 2026. **Document seul : rien n'est changé dans l'app.** Le parcours actuel (Instagram dans Zieuton, avec le bandeau, validé sur iPhone avec le build 1.0 (15)) reste le parcours principal. Ce plan dit quoi faire **si** Apple refuse au titre de la règle 5.2.2, et ce qui existe déjà.
> Légende : **[Vérifié]** = vu dans le code de `main` (31a5d87). **[Déclaré]** = dit par Victor, pas vu. **[À décider]** = choix de Victor.

## 1. Le risque

La règle 5.2.2 d'Apple vise les apps qui affichent ou utilisent un service tiers (ici Instagram) sans autorisation. Zieuton ouvre la page officielle de Meta (`accountscenter.instagram.com`) dans une vue web intégrée (WKWebView), avec un bandeau qui lit l'écran **sur le téléphone** pour guider. C'est le risque de refus n°1 depuis le 4 novembre (audit, risque R1). Le refus n'est pas certain : la note pour l'examinateur explique que l'utilisateur touche tout lui-même, que rien n'est envoyé et que le mot de passe n'est jamais lu.

## 2. Ce qui existe déjà et peut servir de plan B

**[Vérifié] Chemin « Passer par l'app Instagram » (P6, PR #138).**
- Bouton sur l'écran du plan (« Passer par l'app Instagram ») et sur l'écran « Zieuton en haut, Instagram en bas » (« Ça coince chez Instagram ? Passe par son app »).
- Il ouvre `https://www.instagram.com/`, qui lance l'app Instagram si elle est installée (sinon Safari).
- Zieuton montre chaque étape en captures (les mêmes que le guide), avec les conseils (code par SMS, vérification, Safari ouvert par erreur).
- Zieuton **ne lit rien** dans ce cas. L'utilisateur fait la demande, attend, télécharge le fichier dans Instagram, puis le donne à Zieuton par **Partager → Zieuton** ou par « Choisir le .zip ».

**[Vérifié] L'import d'un fichier ne dépend pas de la vue intégrée** : `window.zyeutoFile` (Partager → Zieuton) et le choix de fichier marchent sans elle. Les fichiers d'exemple de la note Apple passent par là.

**[Vérifié] Ce que le plan B perd** par rapport au parcours principal :
- le bandeau qui montre où toucher et le cercle sur le bouton ;
- la preuve automatique que la demande est partie (nouvelle ligne « En attente ») : l'utilisateur dit lui-même « C'est demandé » ;
- la vérification en arrière-plan et la notification « fichier prêt » liée à la page d'Instagram ;
- la récupération automatique du fichier après « Télécharger ».

## 3. Les options si Apple refuse

| Option | Ce que ça change | Code | Build | Avis |
| --- | --- | --- | --- | --- |
| **A. Répondre sans rien changer** | Réponse écrite dans App Store Connect : pas d'API, pas d'automatisation, rien n'est envoyé, l'utilisateur touche tout, page officielle avec l'adresse visible | Aucun | Non | À tenter en premier si le refus est flou ou demande des précisions |
| **B. Passer par l'app Instagram seulement** | Le bouton « Ouvrir Instagram » mène au chemin P6 ; la vue intégrée n'est plus proposée | Petit (page) + retrait ou masquage de la vue dans la coque | Oui (la coque doit ne plus pouvoir l'ouvrir pour que ce soit crédible devant Apple) | Plan B principal recommandé : déjà construit et testé dans P6 |
| **C. Safari intégré (SFSafariViewController)** | Instagram s'ouvre dans la feuille Safari d'Apple ; Zieuton ne peut plus rien lire | Moyen (coque) | Oui | Plus proche de l'expérience actuelle, mais sans bandeau ; à garder en réserve |
| **D. Masquer la vue intégrée par un réglage distant** | Basculer par le canal de mise à jour sans build | Petit | Non | **Déconseillé** : Apple pourrait y voir un comportement changé après la revue (2.3.1, 2.5.2). Ne pas faire sans accord écrit de Victor |

## 4. Recommandation

1. **[À décider] Ne pas préparer de code avant la soumission.** Le parcours principal est validé sur iPhone ; le plan B existe déjà côté écran (P6). Préparer B maintenant demanderait un build de plus.
2. **Rendre la note Apple honnête et complète** (fait dans cette PR) : elle décrit aussi le chemin par l'app Instagram, ce que le bandeau lit et ne lit pas, et le compte verrouillé.
3. **En cas de refus 5.2.2** : d'abord l'option A (réponse écrite, même jour). Si Apple maintient le refus : option B, une PR page + coque, un build, nouvelle soumission. Estimation **[Déduit]** : 1 jour de code et de tests, puis le délai de revue d'Apple.
4. **Garder le texte de réponse prêt** (section 5), pour ne pas perdre de temps le jour du refus.

## 5. Brouillon de réponse à Apple (option A, à relire par Victor)

```
Thank you for your review. Zieuton does not use any Instagram API and does not access Instagram on the user's behalf. It opens Meta's official, public page accountscenter.instagram.com, with the address visible, so that the user can request their own data export, which is a right Meta offers to every user. The user types their credentials into Meta's own form and taps every button, including "Download". Zieuton never reads, stores or transmits the password, typed values or any Instagram content; nothing leaves the device. The guide banner only reads, on the device, visible titles and button labels to show the next step. Users who prefer can also use "Passer par l'app Instagram", which opens the official Instagram app and only shows screenshots. We are happy to adjust the flow if a specific element raises a concern.
```

## 6. Ce qu'il faudra tester si l'option B est faite

Le plan de validation du build (voir `VALIDATION-BUILD-16.md`, section 3.7) devient le parcours principal : demande faite dans l'app Instagram, attente, téléchargement, Partager → Zieuton, import réussi ; message clair si l'app Instagram n'est pas installée ; aucune trace de la vue intégrée dans les écrans.
