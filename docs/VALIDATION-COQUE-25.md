# Coque 25 : suivi des exports (FOU-126, FOU-131)

Version à installer : **build 25** (CURRENT_PROJECT_VERSION 25, ZYEUTO_APP 12), page BUILD 2026-11-25-1455 (canal test).

## Ce qui change

1. **« Vérifions ta demande » est suivie.** Dès que Zieuton enregistre une demande, même « à vérifier », la coque la garde pour le bon compte, programme les rappels et vérifie chez Instagram. Si Instagram la confirme ensuite (ligne « En attente » du jour lue deux fois), le suivi continue avec la même heure de demande, donc les mêmes échéances. La page passe alors sur « Ton export se prépare » avec « Instagram a bien ta demande ✓ ».
2. **Rappels locaux à 15 min, 1 h, 4 h et 24 h** après la demande.
   - Demande à vérifier : « Vérifie ta demande Instagram » · « Ouvre Zieuton pour voir si elle est bien partie. »
   - Demande confirmée : « Où en est ton export ? » · « Touche pour vérifier chez Instagram. »
   - Bon fichier détecté : « Ton export est prêt 🎉 » · « Touche pour le récupérer. »
   - Un rappel n'est noté comme programmé qu'après la réponse « OK » d'iOS ; en cas d'erreur, il est reprogrammé au prochain passage. Pas de doublon : la coque relit la liste d'iOS avant d'ajouter. Les rappels restants sont retirés dès que le bon fichier est détecté, que la demande est terminée ou abandonnée.
3. **Toucher une notification** (même app fermée, démarrage à froid) ouvre la demande dans Zieuton, affiche « Vérification en cours… » et regarde chez Instagram dans une page cachée. Instagram ne s'ouvre jamais seul.
   - Fichier prêt : « Récupérer mon export ».
   - Encore en préparation : « ✓ Vérifié à HH:MM : pas encore prêt, Instagram le prépare. »
   - Lecture impossible : la raison et l'action utile (« Se reconnecter à Instagram », « Réessayer »).
4. **À chaque réouverture**, même sans notifications, Zieuton vérifie seul (déjà le cas, inchangé : vérification toutes les 30 s app ouverte).

Limite connue (sans serveur) : app fermée, iPhone ne peut pas savoir que le fichier est prêt. Seuls les rappels programmés à l'avance arrivent ; c'est le toucher qui lance la vérification.

## Tests automatiques (faits ici)

- `npm test` : 69/69 (dont textes, échéances, anti-doublon, suivi « à vérifier », toucher).
- `npm run test:lecteur` : 217/217, dont `tests/page/coque25-suivi.test.mjs` (11 tests : vérification en cours, raisons d'échec, « Récupérer mon export », démo, « Vérifions ta demande » suivie, confirmation, ancienne coque 11 inchangée, petit iPhone clair et sombre).
- `npm run check:page`, `check-syntax`, `sync-core --check` : OK.
- **Non lancés ici** : compilation Swift et `npm run test:ios` (pas de Mac ; CI Mac bloquée jusqu'au 1er déc.). La compilation se fera dans Xcode au build.

## À vérifier sur l'iPhone de Victor (build 25)

| # | Étapes | Attendu |
|---|---|---|
| C1 | Demander un export ; revenir sur « Vérifions ta demande » | Ligne « Rappel programmé » (plus « Pas encore de rappel ») |
| C2 | Fermer Zieuton (balayer), verrouiller, attendre 15 min | Rappel « Vérifie ta demande Instagram » (ou « Où en est ton export ? » si confirmée) sur l'écran verrouillé |
| C3 | Toucher ce rappel | Zieuton s'ouvre sur la demande, « Vérification en cours… » puis « ✓ Vérifié à HH:MM… » ou « Récupérer mon export » |
| C4 | Toucher « Vérifier dans Instagram » depuis « Vérifions ta demande » quand la ligne « En attente » du jour existe | Passe sur « Ton export se prépare », toast « Instagram a bien ta demande ✓ » |
| C5 | Quand le fichier est prêt, ouvrir Zieuton | Notification « Ton export est prêt 🎉 », bouton « Récupérer mon export » ; Réglages iOS → plus de rappels 1 h / 4 h / 24 h à venir |
| C6 | Notifications désactivées, rouvrir Zieuton | Vérification seule, état affiché |
| C7 | Déconnecté d'Instagram, toucher un rappel | « Instagram te demande de te reconnecter… » + bouton « Se reconnecter à Instagram » |
