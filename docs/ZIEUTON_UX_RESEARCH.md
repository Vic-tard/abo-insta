# Zieuton : expérience utilisateur et tests

> Dernière mise à jour : 16 novembre 2026 (FOU-123). Sources : mémoire du projet, Linear, PR. Les réponses brutes du questionnaire Google Forms des testeurs **n'ont pas été lues** (elles sont dans le Drive de Victor) : section 2 incomplète.

## 1. Parcours principal (état de `main`, 16 nov.)

1. **Bienvenue** : apparition progressive, « Zéro mot de passe », bouton « C'est parti ! » (PR #128).
2. **Plan avant Instagram** : « On va chercher tes abonnés chez Instagram », 3 étapes, petit lien « J'ai une sauvegarde » (PR #129). L'ancien écran « Faisons connaissance » est supprimé.
3. **Écran « Zieuton en haut, Instagram en bas »** : explique que le mot de passe n'est jamais vu et quoi faire des cookies (PR #130).
4. **Instagram dans l'app** (Centre de comptes) avec le **bandeau guide** natif : connexion, « C'était moi » si alerte d'appareil, réglages (Followers et suivi(e)s, Depuis le début, JSON, Une fois), demande.
5. **Attente** (2 à 10 min, parfois 71 s) : écran « Ta liste est en route », notifications.
6. **Téléchargement** : l'utilisateur touche « Télécharger », import automatique.
7. **Accueil** : départs, arrivées, pas en retour, fans ; puis jeux et graphiques.
8. **Mises à jour suivantes** : carte « Mettre à jour » avec un gros bouton.

**[Confirmé]** Ces écrans 1 à 3 sont fusionnés mais seulement en **canal test** (stable = 10 nov.) : les testeurs en canal normal voient encore l'ancienne arrivée.

## 2. Tests utilisateurs

| Date | Qui | Version | Ce qui a été observé | Source |
| --- | --- | --- | --- | --- |
| 1er nov. | Victor (Safari) | Site | Premier export réel réussi : demande 16h11, prêt 16h19, 1 136 abonnés importés | Mémoire `abo-insta-parcours-guide` |
| 2 nov. | Victor | App Xcode | Import par Fichiers → Partager réussi ; mail « prêt » 71 s après la demande | Mémoire |
| 4 nov. | Victor (2 vidéos) | Build 1.0 (1)/(2) | Bandeau en retard d'une étape, résumé non reconnu, « C'est parti » trop tôt ; 2e vidéo en se trompant exprès | PR #75, #77 |
| 6 nov. | Victor | Build 1.0 (3) | Achats : prix, à vie, restauration, compte 2 OK | FOU-36 |
| 5–15 nov. | Amis (TestFlight « TEST ZIEUTON POTES ») | Builds 1.0 (2) à (7) | Difficulté à se connecter à Instagram ; alerte « appareil non reconnu près de [ville fausse] » inquiétante ; réglages d'export mal compris ; demande partie en « Année dernière » ; bandeau qui se trompe ; un compte verrouillé | Mémoire `abo-insta-parcours-export-clair`, `abo-insta-export-simple` |
| 15 nov. | Victor | Build 1.0 (7) | Code de sécurité raté mais l'app dit « je guette ton fichier » | FOU-115 |
| 16 nov. | ChatGPT (analyse d'une vidéo de Victor) | Build 1.0 (7) | A déclenché le diagnostic de l'export | Fil export |

**[Confirmé, 15 nov.]** Le lien du questionnaire diffusé est le lien d'**édition** du formulaire : les testeurs ne peuvent sans doute pas répondre (BUG-22).

**[Inconnu]** Nombre de testeurs inscrits, nombre d'imports réussis, réponses du questionnaire (FOU-113 à faire).

## 3. Problèmes d'ergonomie récurrents

1. **Connexion à Instagram dans l'app** : stress (mot de passe, code, alerte de sécurité). Revient depuis le 4 nov.
2. **Réglages de l'export** : la période « Depuis le début » et le format JSON ne sont pas les choix par défaut d'Instagram ; erreurs fréquentes.
3. **Bandeau guide qui se trompe** : chaque erreur détruit la confiance. Victor exige une lecture « parfaite », sinon c'est pire que rien.
4. **Attente du fichier** : l'utilisateur ne sait pas quand revenir ; notifications peu fiables app fermée.
5. **Textes trop longs** dans le bandeau (coupés après 2 lignes).

## 4. Recommandations UX en vigueur (validées)

- Une étape n'avance que sur une preuve visible à l'écran (D-10, D-11).
- Erreur courante = « petit souci » rose et corail ; rouge seulement pour le compte verrouillé.
- 4 phases visibles (Connexion, Réglages, Demande, Fichier) au lieu de « étape X sur Y ».
- Jamais refaire une demande à la place de l'utilisateur ; après 20 s sans preuve, proposer « Vérifier l'état de ma demande ».
- Compte verrouillé : arrêt, texte neutre, renvoi vers l'app Instagram officielle.
- Bandeau à vérifier sur petit iPhone, clavier ouvert, pendant les chargements ; consignes réductibles, alertes critiques toujours visibles.
- Préférences de Victor : nommer les boutons exactement comme à l'écran ; sobre mais ludique ; pas d'emoji « cheap » dans les listes. **Le gras** : refusé au début (« aucun gras »), puis demandé par Victor sur la bienvenue (16 nov.) → à demander au cas par cas.

## 5. Améliorations déjà réalisées

Arrivée autonome (PR #33), carte « Mettre à jour » épurée (#39), gros bouton « Télécharger mon export » (#91), écrans d'attente (#93–95), notifications détaillées (#34, #69, #116), plan en 4 étapes + « C'était moi » + flèche corail (#126), page potes (#125), bienvenue et plan allégés (#128–130).

## 6. À tester de nouveau

- [ ] Parcours complet sur le build final, par **quelqu'un qui n'a jamais vu l'app** (FOU-37), filmé.
- [ ] Alerte « appareil non reconnu » : la fenêtre « C'était moi » rassure-t-elle ?
- [ ] Demande en « Année dernière » : détectée et expliquée ?
- [ ] Petit iPhone (SE / mini), clavier ouvert, mode sombre.
- [ ] Notifications app fermée.
- [ ] Achats et restauration sur le build final.
- [ ] Chemin de la démo tel que décrit à l'examinateur Apple.
