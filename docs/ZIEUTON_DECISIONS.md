# Zieuton : journal des décisions

> Dernière mise à jour : 23 novembre 2026 (base FOU-123). Reconstitué depuis la mémoire du projet Claude, Linear et Git. Les dates sont celles notées au moment de la décision (heure de Paris quand précisée).
> État : **Active** / **Remplacée** (par une décision plus récente, citée) / **Abandonnée**.
> Pour ajouter une décision : nouvelle ligne en haut de sa section, avec date, source (fil, ticket ou PR) et état. Ne jamais effacer une ancienne décision : la passer en « Remplacée ».

## 1. Produit et vision

| ID | Date | Sujet | Décision | Justification | Conséquences | État | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| D-01 | 26 oct. | Source des données | Export officiel Instagram seulement, jamais de connexion automatisée ni de mot de passe | Zéro risque de restriction du compte | Pas d'API, pas de scraping ; export manuel par l'utilisateur | Active | Fil « Build Instagram unfollow tracker » ; SPEC §3 |
| D-02 | 28 oct. | Cible commerciale | App « très clean », sans trace de Claude, à vendre largement (influenceurs) | Projet commercial | Nom, icône, légal à refaire | Active | Mémoire `abo-insta-projet` |
| D-03 | 1er nov. | Automatiser complètement les exports | Non : l'utilisateur touche lui-même les boutons | Promesse + règles Apple | Bandeau guide plutôt qu'automatisation | Active | Fil « Automatiser complètement les exports » ; SPEC §3.3 |
| D-04 | 4 nov. | Clic automatique sur « Télécharger » | Retiré (il avait été ajouté le 3 nov., PR #70) | Risque de refus Apple 5.2.2 | L'utilisateur touche « Télécharger » | Active (remplace la décision du 3 nov.) | PR #83 ; FOU-18 |
| D-05 | 4 nov. | Site web dans Safari | Fermé : écran « Bientôt sur l'App Store » | Le site gratuit contournait Plus | Le site ne sert plus qu'aux mises à jour | Active | PR #83 ; FOU-19 |
| D-06 | 3 nov. | Google Drive / Gmail | Retirés partout (code mort supprimé le 6 nov.) | Audit Google payant, simplicité | Import par Fichiers / Partager | Active | FOU-43, PR #101 |
| D-07 | 2 nov. | Compte Zieuton / serveur | Non ; sauvegarde dans l'iCloud de l'utilisateur à la place | Argument « rien ne quitte ton téléphone », RGPD | Sauvegarde iCloud auto (PR #83) | Active | Mémoire `abo-insta-a-faire-plus-tard` |
| D-08 | 3 nov. | Rappels Agenda / Siri | Retirés | Peu utiles dans l'app | – | Active | SPEC §5 |
| D-09 | 16 nov. 2h34 | Priorité | **L'export d'abord**, tout le reste gelé (com, 3D, village) | « C'est ce que je veux vendre » ; amis en difficulté | FOU-121 Urgent | Active | Mémoire ; fil export |
| D-10 | 16 nov. 4h15 | Méthode export | Diagnostic avant tout code ; une étape n'avance que sur un **signal positif**, jamais sur un délai | Fiabilité | Plan P1 à P6 | Active | Doc diagnostic |
| D-11 | 16 nov. 12h49 | Plan export | P1 à P6 validés avec ChatGPT : erreurs douces, rouge réservé aux cas graves, 4 phases, demande confirmée par une nouvelle ligne, jamais de nouvelle demande auto, compte verrouillé = arrêt + renvoi vers l'app Instagram ; « C'est bon » seulement après vérification fiable ; une PR à la fois ; aucun build ni fusion sans accord | Retours potes + audit ChatGPT | P1 en codage | Active | Fil « Rendre l'export Instagram simple et fiable » |
| D-12 | 6 nov. puis 16 nov. | Écran « Faisons connaissance » | Créé le 6 nov. (FOU-69), **supprimé le 16 nov.** (PR #129) | Alléger l'arrivée | Le prénom n'est plus demandé à l'arrivée **[Déduit]** | Remplacée | PR #105, #129 |
| D-13 | 15 nov. 21h18 | Pointeur sur le bouton Instagram | Flèche corail sur un calque natif (pas le zieuteur pointeur) ; cercle seulement si écran reconnu et un seul bouton | Zieuteur jugé moche ; lecture « parfaite » exigée | – | Active | PR #126 (FOU-118) |
| D-14 | 15 nov. | « Nos serveurs sont là-bas » | Refusé | Zieuton n'a aucun serveur | – | Active | Fil « Rendre le parcours d'export plus clair » |
| D-15 | 10 nov. | Règle de dessin | Chaque zieuteur est toujours derrière un mur | Identité de marque | FOU-102 | Active | Mémoire `zieuton-regle-mur` |

## 2. Prix et monétisation

| ID | Date | Décision | État | Source |
| --- | --- | --- | --- | --- |
| D-20 | 1er nov. | Plus = achat unique 5,99 €, pas d'abonnement | Remplacée par D-21 | Business model (doc) |
| D-21 | 2 nov. 15h15 | Gratuit = 2 premiers imports puis 1 mise à jour / 30 jours ; Plus 1,99 €/mois, 9,99 €/an, 19,99 € à vie | Remplacée par D-22 (prix) | PR #22 |
| D-22 | 4 nov. | **Compte 1 : 2,99 €/mois, 14,99 €/an, 29,99 € à vie**, sans essai gratuit (Victor a délégué) | Active | PR #82 |
| D-23 | 3–4 nov. | Multi-comptes : 3 max ; chaque compte ajouté paie son propre Plus (1,99 / 9,99 / 19,99 €), même si le compte 1 est gratuit ; la version gratuite va au premier compte qui importe | Active (une règle « compte 1 en Plus d'abord » a été ajoutée puis retirée) | PR #36, #37, #74, #82 |
| D-24 | 2 nov. | Pas de pub, aucune donnée vendue | Active | SPEC §3.4 |

## 3. Technique et infrastructure

| ID | Date | Décision | Justification | État | Source |
| --- | --- | --- | --- | --- | --- |
| D-30 | 1er nov. | App iPhone = coque Swift + page web (WKWebView) | Rapide, une seule base | Active | Fil « Créer l'app iPhone Zyeuto » |
| D-31 | 4 nov. | Page rangée dans l'app, mise à jour depuis le site | Règles Apple 4.2 / 2.5.2, hors ligne | Active | PR #76/#83 |
| D-32 | 5 nov. | Filet de sécurité (CI, tests, mises à jour sûres, journal d'erreurs) **avant** la sortie ; découpage du code **après** | Pas de refonte risquée avant Apple | Active | Bilan d'architecture ; FOU-26 à 44 |
| D-33 | 5 nov. | Les fils Claude ne touchent plus le code, ils écrivent des prompts pour Claude Code | Garder la main | **Remplacée** : depuis le 6 nov., les fils codent eux-mêmes en PR ; confirmé par D-37 | Mémoire `zieuton-mode-cerveau` |
| D-34 | 6 nov. | Orca installé seulement après le découpage du code | Conflits sinon | Active | FOU-53 |
| D-35 | 9–10 nov. | Domaine zieuton.com (Cloudflare) + Cloudflare Pages en principal, GitHub en secours, même après le retour de GitHub | Suspension GitHub du 7 nov. | Active | PR #110, #111 ; FOU-87 à 92 |
| D-36 | 10 nov. | Un seul build Xcode quand Victor est satisfait, pas de builds intermédiaires | Chaque build coûte du temps à Victor | Active | Mémoire `zieuton-build-unique` |
| D-37 | 16 nov. | Claude seul écrit le code ; ChatGPT audite (bug confirmé / risque / recommandation), sans pousser ni changer Linear ; Victor tranche | Double regard | Active | `docs/COLLABORATION.md`, FOU-122 |
| D-41 | 16 nov. 13h10 | Sources de référence : Linear pour les tâches, GitHub pour le code et les versions, `docs/` pour les décisions et le contexte ; `ZIEUTON_HANDOFF.md` mis à jour à chaque étape importante | Mêmes infos pour Claude et ChatGPT | Active | Message de Victor dans le fil « 00 · Réorganiser et documenter le projet » |
| D-42 | 16 nov. 13h10 | Fils rangés par préfixe 00 à 06 ; 13 fils ouverts traités | Retrouver l'historique | Active | Même source ; audit §7 |
| D-43 | 16 nov. 13h17 | Trois fils de travail visibles seulement : 00 Tableau de bord, 01 Export Instagram, 02 Lancement App Store ; les autres sont résolus après vérification que Linear ou la doc gardent leur suivi | Simplicité au quotidien | Active (remplace la partie « titres de fils » de D-42) | Message de Victor, fil 00 |
| D-38 | 6 nov. | Chaque instruction de Victor a son ticket Linear, fermé à la fin | Traçabilité | Active | Mémoire |
| D-39 | 16 nov. 2h50 | Victor écrit ses idées écran par écran ; Claude exécute sans réinventer | Garder la vision de Victor | Active | Mémoire `abo-insta-export-simple` |
| D-40 | 6 nov. | Canal test / stable ; tout changement de page passe d'abord en test | Ne jamais bloquer un client | Active | PR #98 ; `MISES-A-JOUR.md` |

## 4. Nom, marque, légal

| ID | Date | Décision | État | Source |
| --- | --- | --- | --- | --- |
| D-50 | 29 oct. | Ne pas utiliser « Insta » ni le logo Instagram | Active | Analyse juridique (doc) |
| D-51 | 31 oct. | Nom « Zyeuto » | Remplacée par D-52 | PR #1 (fermée) |
| D-52 | 2 nov. | Nom « Zieuton » ; identifiants techniques `fr.zyeuto.*` gardés | Active | PR #28 |
| D-53 | 3 nov. | Micro-entreprise à l'adresse personnelle (publique au registre), accepté par Victor | Active | Mémoire `abo-insta-micro-entreprise` |
| D-54 | 10 nov. | Com entière en Backlog | Active | FOU-99 |
| D-55 | 16 nov. 19h11 | Soumission à Apple vers le 25 nov., sortie le 3 déc. | **Remplacée** par D-56 | Message de Victor, fil 00 |
| D-56 | 22 nov. | Tout le planning est décalé de 10 jours : build validé le 2 déc., soumission le 5 déc., **sortie le 15 déc. 2026** | Active | Message de Victor, fil 00 ; projet Linear |
| D-57 | 17 nov. | Pas de build 16 ; un seul build candidat. Candidat actuel : 1.0 (23) | Active | Fils 00 et 01 ; CHANGELOG |
| D-58 | 23 nov. | Linear (audit Victor + ChatGPT) : FOU-130 est le seul ticket de soumission (FOU-51 doublon) ; « Done » sur FOU-131 et FOU-129 = code fusionné et promotion du 22 nov., les tests réels restent dans FOU-105 | Active | Linear |

## 5. Décisions abandonnées

- Paquets de jetons pour les imports (2 nov.) : écartés.
- Comptes en plus à 0,99 € (PR #32) : remplacés le 3 nov.
- Produits `plus4` (4e compte) : retirés.
- Prompt générique React / Supabase / Apify (5 nov.) : écarté (scraping et serveur interdits).
- Dépôt privé GitHub Pro (FOU-47) : annulé.
- Jeux refusés : « Vrai ou faux abonné », « Pseudo mélangé ».

## 6. Décisions encore à prendre

1. PR #160 (fusionnée le 22 nov., canal test) : passage en canal stable après les tests sur iPhone (Victor).
2. Préparer ou non le plan B (FOU-33) **avant** la soumission du 5 déc.
3. Com minimale pour la sortie du 15 déc. (FOU-56, 59, 60, en Backlog).
4. Lien public du questionnaire testeurs (BUG-22).
5. Vérifier et confirmer la résiliation du renouvellement Higgsfield (FOU-116).

Décisions tranchées depuis le 16 nov. (ancienne liste) : date de soumission (D-56) ; canal stable promu le 22 nov. ; démo accessible dès la bienvenue (PR #141) ; statuts Linear rangés le 22 et le 23 nov.
