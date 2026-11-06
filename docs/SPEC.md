# Zieuton : spécification

Version du 6 novembre 2026. Ce document dit ce que fait Zieuton et ce qu'il ne fera pas. Toute nouvelle fonction doit s'y rattacher ; sinon, on met d'abord la spec à jour.

## 1. En une phrase

Zieuton montre à une personne qui s'est désabonnée de son compte Instagram (et qui y est arrivé), en comparant les exports officiels de ses données Instagram, sans jamais se connecter à son compte ni envoyer ses données sur un serveur.

## 2. Pour qui

- **Cœur de cible** : utilisateurs Instagram francophones de 16 à 35 ans, curieux de savoir qui les suit ou ne les suit plus.
- **Secondaire** : petits créateurs et micro-influenceurs qui veulent suivre leurs départs.
- **Appareil** : iPhone uniquement (iOS 17 ou plus). Pas d'Android, pas de site public pour l'instant.

## 3. Promesses non négociables

1. **Export officiel seulement.** Les données viennent du fichier que l'utilisateur demande lui-même à Instagram (Centre de comptes → Exporter tes informations). Jamais de scraping, de mot de passe Instagram, de bot ou d'API non officielle.
2. **Tout reste sur le téléphone.** Pas de serveur Zieuton, pas de compte Zieuton. Seule copie hors du téléphone : la sauvegarde automatique dans l'iCloud de l'utilisateur.
3. **L'utilisateur fait les gestes importants lui-même.** Zieuton guide, mais c'est l'utilisateur qui touche « Télécharger » dans Instagram.
4. **Pas de pub, pas de revente de données.**

## 4. Fonctions (périmètre de la version 1.0)

### 4.1 Premier export guidé
- Écran « Demande ta liste à Instagram » : ouvre le Centre de comptes dans l'app.
- Bandeau guide en bas de l'écran Instagram : il reconnaît l'étape et dit quoi toucher (garder seulement « Followers et suivi(e)s », période « Depuis le début », format JSON, « Une fois »).
- Écran d'attente (2 à 10 min) avec notification quand l'export est probablement prêt.
- Récupération du fichier (.zip) puis import automatique.

### 4.2 Import et comparaison
- Lit `followers_1.json` (obligatoire) et `following.json` (facultatif), seuls ou dans le .zip.
- Refuse : export partiel (moins de la moitié des abonnés du dernier import), export d'un autre compte, export plus ancien que le dernier import, format HTML, fichier abîmé.
- Même export importé deux fois : reconnu, rien n'est ajouté.
- Résultat : départs, arrivées, « pas en retour » (tu les suis, pas eux), fans (ils te suivent, pas toi).

### 4.3 Historique et écrans
- Accueil : prénom, photo, 4 cases (départs, arrivées, pas en retour, fans) + Mes abonnés.
- Listes groupées par date, recherche.
- Graphiques (courbe, barres, parts) et page Mes records.
- Mode démo avec de fausses données.

### 4.4 Jeux
- Niveau de Zieutage (30 niveaux, 7 rangs), zieuteur à habiller, roue du jour, pronostics, mini-jeux, anniversaires d'abonnement, trophées.
- Les jeux ne doivent jamais bloquer ni ralentir l'import.

### 4.5 Multi-comptes
- 3 comptes Instagram maximum par téléphone, prénom obligatoire.
- Le compte 1 a la version gratuite. Les comptes 2 et 3 doivent prendre leur propre Plus avant leur premier export.

### 4.6 Zieuton Plus (achats intégrés Apple, StoreKit 2)
- Gratuit : 2 premiers imports, puis 1 mise à jour par mois.
- Plus compte 1 : 2,99 €/mois, 14,99 €/an, 29,99 € à vie.
- Plus comptes 2 et 3 : 1,99 €/mois, 9,99 €/an, 19,99 € à vie.
- Plus débloque : imports illimités, certains trophées (séries, 25 et 50 imports).
- « Restaurer mes achats » sur un nouvel appareil (le compte restauré redevient compte 1).
- L'or est réservé à Plus dans le visuel.

### 4.7 Sauvegarde
- Sauvegarde iCloud automatique de tout l'historique, reprise proposée sur un nouvel iPhone.
- Fichier `.zieuton` scellé à garder soi-même, vérifié à la restauration.

### 4.8 Réglages, aide, confidentialité
- Réglages façon iPhone (engrenage), page Aide, « Nous écrire » (victorfourneret@icloud.com), page Confidentialité qui dit tout ce que le guide regarde et ne regarde jamais.

## 5. Hors périmètre (on ne le fait pas en 1.0)

- Statistiques de posts, likes, vues, stories.
- Voir qui regarde ton profil (impossible légalement).
- Suivre le compte de quelqu'un d'autre.
- Serveur, compte Zieuton, connexion Google ou Apple.
- Android, site web public, version anglaise (prévus après la sortie).
- Rappels Agenda ou Siri (retirés le 3 nov.).

## 6. Contraintes

- **Sortie visée** : 3 décembre 2026, soumission à Apple vers le 20 novembre, sortie manuelle.
- **Apple** : règles 5.2.2 (service tiers), 2.5.2 (code téléchargé), 3.1.1 (achats). La note au testeur doit expliquer la vue Instagram et la page embarquée.
- **Légal** : micro-entreprise (SIRET en attente), textes légaux (PR #35), RGPD (aucune donnée collectée).
- **Performance** : un compte à 200 000 abonnés doit s'importer en moins de 5 secondes sur un iPhone récent.

## 7. Définition de « terminé » pour une fonction

1. Elle respecte les promesses du point 3.
2. Les tests passent (`npm test`) et les vérifications GitHub sont vertes.
3. Elle marche en clair et en sombre, sur petit et grand iPhone.
4. Victor l'a vue sur son iPhone (ou en capture) et a dit oui.
5. Le ticket Linear est fermé par la PR.
