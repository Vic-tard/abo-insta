# Validation iPhone du build 21 (FOU-126 : export, preuve, notifications)

Build 21 = #146 + #147 + #148 + #150 (et la page du même jour). À faire sur l'iPhone de Victor, canal test, **avec le build 21 installé depuis TestFlight**. Une ligne qui échoue = une capture ou une vidéo, et rien d'autre à corriger « en théorie » avant.

Préparation conseillée : avoir déjà un export prêt dans Instagram (comme le 18 nov.), notifications autorisées pour Zieuton.

Statut : ✅ vu, ❌ échec (joindre capture), ➖ situation pas rencontrée.

| N° | Domaine | Action | Résultat attendu | Statut |
| --- | --- | --- | --- | --- |
| V1 | Demande | « J'ai compris, on y va », suivre le bandeau jusqu'à « Commencer l'exportation » | Le bandeau guide écran par écran, cercle seulement sur un bouton sûr | |
| V2 | Confirmation | Juste après « Commencer l'exportation » | Bandeau « C'est demandé », bouton « Revenir dans Zieuton ». Notification « C'est demandé ✓ » une seule fois. La carte « Demandée le » du jour est dans « En attente » | |
| V3 | Liste | Faire défiler, changer d'onglet, toucher une carte | Jamais « Oups, pas le bon bouton ! », jamais « Touche Créer une exportation » | |
| V4 | Sortie | « Revenir dans Zieuton » | Écran « Instagram prépare ta liste ». Rien à refaire | |
| V5 | Sortie sans preuve | Toucher « Commencer » puis fermer Instagram tout de suite | Écran « Demande à vérifier », jamais « Zieuton en haut, Instagram en bas ». Pas de « C'est demandé » | |
| V6 | Retour | Depuis « Demande à vérifier », toucher « Vérifier dans Instagram » | « Un instant : une demande est déjà là », puis « Demande du jour en cours ». Retour : attente normale | |
| V7 | Attente | Rouvrir Instagram depuis l'attente tant que la carte est « En attente » | « Pas encore prêt : en attente ». Aucun cercle | |
| V8 | Ancien export prêt | Avec un export plus ancien prêt dans la liste, pendant l'attente | Jamais « prêt », jamais « Touche Télécharger » vers l'ancien | |
| V9 | Nouveau fichier | La carte quitte « En attente », une carte « Expire le » (jour + 4) arrive | « C'est prêt ! Touche Télécharger », consigne « Sur la ligne « Expire le JJ/MM » » avec la date lue sur la carte (sinon consigne neutre, sans date) | |
| V10 | Cercle | V9 avec un ancien export encore dans la liste, puis faire défiler pour ne voir que l'ancien | **Aucun** cercle (il y a deux « Télécharger » dans la liste). La consigne dit quelle date chercher | |
| V11 | Cercle | V9 sans aucun autre export dans la liste | Cercle sur l'unique « Télécharger » | |
| V12 | Téléchargement | Toucher soi-même « Télécharger » sur la ligne indiquée | Téléchargement puis import comme au build 15 | |
| V13 | Import | Après le téléchargement | Bilan affiché, plus aucun rappel ni « prêt » ensuite | |
| V14 | Notifications | App en arrière-plan pendant l'attente | Rappel à 30 min, puis le lendemain si toujours en attente. « Ton fichier est prêt 🎉 » une seule fois quand Zieuton l'a vu (app ouverte). Jamais de notification « expire » | |
| V15 | Reprise | Fermer Zieuton de force pendant l'attente, rouvrir | Toujours l'attente, sans nouvelle demande proposée, « C'est demandé » pas renvoyé | |
| V16 | Reprise | Fermer de force pendant « Demande à vérifier », rouvrir | Toujours « Demande à vérifier » | |
| V17 | Réseau | Mode avion pendant l'attente, puis retour du réseau | « Instagram ne répond pas » puis reprise, jamais « prêt » sans la liste | |
| V18 | Deux demandes | Refaire une 2e demande identique le même jour | Jamais « prêt » automatique pour ce suivi (on ne sait pas laquelle est la sienne) : « Vérifie la date » | ➖ si pas testé |
| V19 | Deux comptes | Demande en attente sur un autre compte Instagram | Elle ne bloque pas le compte suivi, et son fichier n'est jamais annoncé comme le sien | ➖ si pas testé |

## Ce qui ne peut pas être vérifié avant l'iPhone

- Le vrai code d'Instagram : les pages de test sont reconstituées d'après les captures et la vidéo (textes et boutons vus).
- Le réveil d'iOS en arrière-plan : iOS décide seul, rien n'est garanti. Zieuton ne promet aucune surveillance continue.
- La compilation Xcode et les tests Swift : seulement sur le Mac (le quota Mac de GitHub est épuisé jusqu'au 1er déc.).
