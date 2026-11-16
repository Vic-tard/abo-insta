# Audit de Zieuton du 16 novembre 2026

> Ticket FOU-123. Diagnostic seulement : aucun code, aucune configuration, aucun fil n'a été modifié, renommé, résolu ou supprimé.
> Ce document est un **instantané daté** : il ne sera pas tenu à jour. Les documents vivants sont listés dans [`ZIEUTON_MASTER_CONTEXT.md`](ZIEUTON_MASTER_CONTEXT.md).

## 1. Sources réellement consultées

| Source | Accès | Ce qui a été lu |
| --- | --- | --- |
| Dépôt GitHub `Vic-tard/abo-insta` | Oui | `docs/`, `CLAUDE.md`, `README.md`, structure, tailles de fichiers, numéros de version, `channel.json`, historique Git depuis le 4 nov. (le clone n'a pas l'historique plus ancien), PR ouvertes (aucune) |
| Linear (équipe FOU) | Oui | Les tickets FOU-1 à FOU-122 (titres, statuts, priorités, parents) |
| Mémoire du projet Claude | Oui | Index + 52 fiches (la principale source pour les dates et les décisions) |
| Fils du projet Claude | Partiel | **Titres et états des 78 fils** ; contenu détaillé lu seulement pour le fil export. Les 77 autres sont résumés via la mémoire du projet |
| Dossier de fichiers du projet (`abo-insta/`) | Liste seulement | Noms des dossiers ; maquettes, vidéos et captures non ouvertes |
| Docs Claude (artefacts claude.ai cités) | Non relus | Liens repris de la mémoire, contenu non revérifié |
| Conversations Claude hors de ce projet | **Non** | Inaccessibles depuis ce fil |
| Réponses du questionnaire testeurs (Google Forms) | **Non** | Dans le Drive de Victor |
| App Store Connect, TestFlight, Cloudflare, Mac de Victor | **Non** | État connu seulement par la mémoire |

## 2. Ce que je sais avec certitude

- Le produit, ses promesses, son architecture, ses prix et ses règles de travail (dépôt + Linear + décisions écrites).
- L'état du code de `main` : page `BUILD 2026-11-16-0338`, coque `CURRENT_PROJECT_VERSION 10`, `ZYEUTO_APP.version 9`, canal stable `2026-11-10-1618`.
- Priorité : l'export (FOU-121), P1 en codage, plan validé par Victor et ChatGPT.
- Dernier build envoyé sur TestFlight : 1.0 (7), le 15 nov.
- Entreprise immatriculée, fiche App Store et achats prêts.

## 3. Ce que je déduis raisonnablement

- La soumission « vers le 20 nov. » ne tiendra pas si P1 à P6 changent la coque : il faudra un nouveau build, un test, puis la soumission.
- Les écrans d'arrivée du 15–16 nov. ne sont vus que par les iPhones en canal test (celui de Victor), pas par les autres testeurs.
- La note examinateur Apple décrit un chemin de démo qui passait par l'écran prénom, supprimé le 16 nov.

## 4. Ce que je ne sais pas

- Les retours écrits des testeurs (questionnaire) et le nombre de testeurs actifs.
- Si les correctifs de coque fusionnés depuis le build 1.0 (7) ont été vus sur un iPhone (aucun build depuis).
- La réponse au Small Business Program.
- Si la clé de signature `PAGE_SIGNING_KEY` existe ailleurs que dans les secrets GitHub, et si le jeton Cloudflare vu sur une capture a été renouvelé.
- L'état des comptes TikTok / Instagram de Zieuton ; un éventuel dépôt de marque INPI.
- Le contenu exact des 13 bugs C1 à C13 du diagnostic (doc non relu ici).

## 5. Informations contradictoires

| Sujet | Version A | Version B | À trancher par |
| --- | --- | --- | --- |
| Statut de FOU-121 | Linear : **Done** | Fil export : P1 en cours de codage | Victor (rouvrir le ticket ?) |
| Emplacement du projet Xcode sur le Mac | « Téléchargements → abo-insta-main/ios » (index de la mémoire) | « Bureau/Zieuton/Zieuton-principal » (fiche du 3 nov.) | Victor |
| Taille du code | `CLAUDE.md` : 7 100 lignes ; FOU-42 : 2 200 lignes | Réel : 8 593 et 3 129 lignes | Corriger la doc (prochaine PR doc) |
| Hébergement | `CLAUDE.md`, `README.md`, `SPEC.md` : GitHub Pages | Réel : zieuton.com principal, GitHub en secours | Corriger la doc |
| Légal dans `SPEC.md` §6 | « SIRET en attente, PR #35 » | Entreprise immatriculée, textes à jour (FOU-68) | Corriger la spec |
| Gras dans les textes | « AUCUN gras » (4 nov.) | Gras demandé sur la bienvenue (16 nov.) | Victor, au cas par cas |
| Qui code | 5 nov. : les fils ne touchent plus au code | 16 nov. : Claude écrit tout le code (COLLABORATION.md) | Tranché : la règle du 16 nov. s'applique |
| Numéro du « build 6 » | Build 6 | Envoyé sous le numéro 1.0 (7) | Rien à faire, à savoir |
| Zieuteur 3D | FOU-119 « In Progress » | Gelé depuis le 16 nov. | Victor (passer en Backlog ?) |

## 6. Risques classés par gravité

| ID | Gravité | Risque | Action corrective proposée |
| --- | --- | --- | --- |
| R1 | **Critique** | Note examinateur Apple périmée : si le testeur Apple ne trouve pas la démo, refus probable | Vérifier le chemin réel sur iPhone, puis corriger `note-revue-apple.md` dans une PR doc (BUG-08) |
| R2 | **Critique** | Calendrier : P1 à P6 + build + test + revue Apple (souvent 1 à 3 jours, plus en cas de refus) avant le 3 déc. | Fixer avec Victor un « minimum avant soumission » et une date de soumission réaliste |
| R3 | **Haute** | Canal stable bloqué au 10 nov. : les testeurs ne voient pas les nouveaux écrans ; un build fait aujourd'hui embarque la page du jour mais le canal normal ne prend pas de page plus récente que `stable` **[Déduit, à vérifier dans `MISES-A-JOUR.md`]** | Après le test de Victor, PR « canal valider » ; ajouter cette étape à chaque fin de sujet |
| R4 | **Haute** | Refus Apple 5.2.2 (vue Instagram intégrée), plan B non préparé (FOU-33) | Décider avant la soumission si on prépare le plan B |
| R5 | **Haute** | Coque modifiée 4 fois depuis le dernier build, jamais vue sur iPhone (#124, #126, #130, P1 à venir) | Test complet du build final, liste écrite des points à vérifier |
| R6 | **Haute** | Achats testés une seule fois (build 3) | Refaire achat, restauration, compte 2 sur le build final (revérif FOU-36) |
| R7 | **Haute** | Secrets : clé de signature seulement dans GitHub (si perdue, plus de mises à jour de page sans nouveau build) ; jeton Cloudflare exposé sur une capture | Victor confirme une copie de la clé dans son gestionnaire de mots de passe et renouvelle (« Roll ») le jeton Cloudflare |
| R8 | **Haute** | Compte d'un testeur verrouillé : risque d'image si cela arrive à des clients | P1 (arrêt propre) + P6 (chemin par l'app Instagram) ; message clair dans l'aide |
| R9 | Moyenne | Bandeau guide non testé automatiquement sur de vraies pages ; Instagram change souvent (FOU-46) | Pages reconstituées de P1 ; surveiller après la sortie |
| R10 | Moyenne | Dette technique : deux fichiers géants, chaque PR touche les mêmes fichiers (conflits, régressions) | Découpage après la sortie (FOU-41, FOU-42), comme décidé |
| R11 | Moyenne | Documentation existante en partie périmée (`CLAUDE.md`, `README.md`, `SPEC.md`) | PR doc séparée, après accord de Victor |
| R12 | Moyenne | Linear incohérent (FOU-121, FOU-119) | Victor corrige les statuts ou autorise Claude à le faire |
| R13 | Moyenne | Fonctions sans besoin utilisateur prouvé (village, jeux avancés, 3D) pendant que l'export bloquait | Déjà gelées ; mesurer l'usage plus tard sans analytics (avis des testeurs) |
| R14 | Moyenne | Administratif : ACRE avant le 18 déc. ; médiateur de la consommation pas encore choisi | Garder FOU-83 et FOU-82 visibles dans la roadmap |
| R15 | Basse | Fichiers non utilisés à la racine du dépôt (`ic-after.png`, `ic-offer.png`, `pl1.png`, `pl2.png`, aucune référence trouvée) | Ne rien supprimer sans accord ; à confirmer par Victor |
| R16 | Basse | Infos clés seulement dans la mémoire du projet Claude, invisibles pour ChatGPT | C'est le rôle de `ZIEUTON_HANDOFF.md` et des documents `docs/ZIEUTON_*` |

## 7. Plan de rangement des fils (proposition, rien n'est fait)

### Ce qui est possible

- Je peux **renommer** un fil (seulement le mien directement ; pour les autres, c'est le coordinateur du projet qui le peut). Je ne peux **pas** créer de dossiers ou de catégories dans un projet Claude, ni renommer le projet. La catégorie se lit donc dans un **préfixe du titre** : `00 ·` à `06 ·`.
- Les fils **résolus** sont déjà masqués de ta vue : les renommer ne changerait rien pour toi. Je propose de ne renommer que les **13 fils encore ouverts** et de garder les autres comme archive, classés ci-dessous.
- Rien ne sera renommé, résolu ou supprimé avant ton accord écrit.

### Catégories

`00` Pilotage général · `01` Développement technique · `02` UX / UI · `03` Bugs et corrections · `04` Nouvelles fonctionnalités · `05` Stratégie et business · `06` Tests utilisateurs

### Fils ouverts (13) : proposition

| Titre actuel | Cat. | Titre proposé | Action proposée |
| --- | --- | --- | --- |
| Réorganiser et documenter tout le projet | 00 | 00 · Réorganiser et documenter le projet | Renommer ; résoudre quand la PR doc est fusionnée |
| Rendre l'export Instagram simple et fiable | 03 | 03 · Rendre l'export Instagram simple et fiable | **Ne pas toucher pendant P1** ; renommer ensuite |
| Fabriquer le build 6 dans Xcode | 01 | 01 · Fabriquer le build final dans Xcode | Renommer ; c'est là que se fera le prochain build |
| Soumettre Zieuton à l'App Store | 00 | 00 · Soumettre Zieuton à l'App Store | Renommer, garder ouvert |
| Finaliser les mentions légales de Zieuton | 05 | 05 · Démarches légales (ACRE, médiateur) | Renommer : c'est là qu'arrive le courrier URSSAF |
| Créer le zieuteur en 3D | 05 | 05 · Créer le zieuteur en 3D (gelé) | Renommer, garder en pause |
| Rendre le parcours d'export plus clair | 02 | – | Terminé (FOU-118) : résoudre ; doublon partiel du fil export |
| Tester une vidéo de com Zieuton | 05 | – | Terminé (FOU-112) : résoudre |
| Choisir l'outil de vidéos IA pour la com | 05 | – | Terminé (FOU-72/85) : résoudre |
| Faire le récap de l'avancement de Zieuton | 00 | – | Obsolète (remplacé par ces documents) : résoudre |
| Choisir le prochain sujet dans Linear | 00 | – | Obsolète (10 nov.) : résoudre |
| Fermer les PR mortes et nettoyer les branches | 01 | – | Terminé (FOU-45/120) : résoudre |
| Déménager Zieuton hors de GitHub | 01 | – | Terminé (FOU-87 à 92) : résoudre |

### Fils résolus (65) : classement pour mémoire

Les fils marqués ★ contiennent des décisions importantes, toutes reprises dans [`ZIEUTON_DECISIONS.md`](ZIEUTON_DECISIONS.md). Les fils marqués ⧉ sont redondants avec un autre.

- **00 Pilotage** : Vérifier les tickets Done de Linear · Mettre Linear à jour sur le blocage GitHub · Débloquer Linear après le retour de GitHub · Faire le ménage Linear et GitHub · Perfectionner le build 6 · Mettre la partie com en backlog ★ · Écrire les règles de collaboration avec ChatGPT ★ · Sauvegarder tout le projet Zieuton · Créer un tableau de bord de liens Zieuton · Perfect the app for users
- **01 Technique** : Rendre l'infrastructure de Zieuton carrée ★ · Ajouter le filet de tests automatiques · Ajouter la spec et le CLAUDE.md au dépôt · Sécuriser les mises à jour de la page ★ · Signer les mises à jour de la page ★ · Vérifier les numéros de version en CI · Supprimer le code mort Drive / Gmail · Protéger l'historique et les gros comptes · Rendre les erreurs visibles et préparer la note Apple · Intégrer la page web dans l'app iPhone ★ · Créer l'app iPhone Zyeuto ★ · Vérifier la coque avant Apple · Make tracker app keep imports · Build Instagram unfollow tracker ★ · Speed up weekly Instagram export
- **02 UX / UI** : Rendre l'accueil premium · Refondre les réglages, sobres et clairs · Refondre le visuel de Zyeuto · Peaufiner les visuels de chaque écran · Améliorer les graphiques à dérouler · Ajouter l'écran Faisons connaissance (écran retiré le 16 nov.) · Créer l'écran doré Zieuton Plus · Rendre l'app fun et animée · Ajouter les pages jeux et graphiques en swipe · Vérifier chaque écran pour la V3 parfaite · Rendre l'arrivée des nouveaux 100 % autonome ★
- **03 Bugs et corrections (guide d'export)** : Améliorer le suivi du guide d'export ★ · Mettre à jour les données en un bouton · Ajouter les notifications d'export Instagram ★ · Automatiser complètement les exports ★ (refusé)
- **04 Nouvelles fonctionnalités** : Imaginer le jeu Le village du zieuteur · Imaginer de nouveaux mini-jeux Zyeuto · Ajouter un mode démo à Zieuton · Bloquer le partage de Zieuton Plus entre comptes ★
- **05 Stratégie et business** : Définir la monétisation de Zyeuto ★ · Plan launch and monetization ⧉ · Créer les achats Zieuton Plus ★ · Choisir le nouveau nom Zieuton ★ · Renommer l'app en Zieuton partout · Analyser Reports + et se démarquer · Find top free unfollow tracker competitors ⧉ · Check legal risks of selling the app ★ · Créer la micro-entreprise puis les textes légaux ★ · Mettre à jour les textes légaux · Mettre l'e-mail de contact public · S'inscrire au Small Business Program · Préparer la fiche App Store de Zieuton ⧉ · Remplir la fiche App Store de Zieuton · Finir la fiche App Store pour le build 6 · Préparer l'app pour la soumission Apple · Préparer la com de lancement · Avancer sur la com de Zieuton ⧉ · Écrire les scripts de vidéos virales
- **06 Tests utilisateurs** : Faire tester Zyeuto via TestFlight ★ · Faire tester Zieuton par des amis

**Fils à créer** (seulement quand le sujet démarre, un à la fois) : `06 · Retours des potes sur le build final` (FOU-113, FOU-37) ; `00 · Point hebdo et mise à jour des docs` (optionnel).

## 8. Procédure de maintenance (au quotidien)

1. **Un fil = un objectif = un ticket Linear.** Le titre commence par sa catégorie (`00`…`06`). Si une demande touche plusieurs catégories, Claude le dit et précise quels documents mettre à jour.
2. **Fin de sujet** : Claude poste un bilan (travail fait, résultat, fichiers, tests, problèmes restants, décisions, prochaine action) et met à jour les documents concernés **dans la même PR** que le code quand c'est possible :
   - nouvelle décision → `ZIEUTON_DECISIONS.md`
   - bug trouvé ou corrigé → `ZIEUTON_BUG_TRACKER.md`
   - PR fusionnée → `ZIEUTON_CHANGELOG.md`
   - priorité qui bouge → `ZIEUTON_ROADMAP.md`
   - retour testeur → `ZIEUTON_UX_RESEARCH.md`
   - tout changement important → `ZIEUTON_HANDOFF.md` (pour ChatGPT)
3. **Avant une proposition importante**, Claude relit `DECISIONS` et `SPEC` et signale toute contradiction.
4. **Fil trop long** : Claude écrit un résumé de transmission (décisions, contraintes, fichiers, problèmes ouverts, prochaines étapes) puis demande au coordinateur un nouveau fil.
5. **Chaque semaine** (ou à chaque build) : relecture rapide de la roadmap et de Linear ; un nouvel audit daté seulement si besoin.
6. Claude ne dit jamais qu'un document est à jour s'il ne l'a pas modifié dans une PR.

## 9. Checklist manuelle pour Victor

- [ ] Relire la PR de documentation et dire « fusionne » ou demander des retouches (ChatGPT peut la relire avant).
- [ ] Dire si tu valides le plan de rangement (section 7). Ensuite, je renomme ce fil et le coordinateur renomme ou résout les autres ; tu n'as rien à faire à la main.
- [ ] Si tu veux le nom « ZIEUTON — DÉVELOPPEMENT & STRATÉGIE » pour le projet : ouvre le projet dans Claude → réglages du projet → nom (je ne peux pas le changer moi-même ; si l'option n'existe pas chez toi, garde « ZIEUTON »).
- [ ] Linear : rouvrir FOU-121 (il est « Done » alors que P1 est en cours) et passer FOU-119 en Backlog, ou m'autoriser à le faire.
- [ ] Dire où est vraiment le projet Xcode sur ton Mac (Téléchargements ou Bureau/ZIEUTON).
- [ ] Vérifier que la clé de signature des mises à jour est sauvegardée dans ton app Mots de passe ; renouveler le jeton Cloudflare (bouton « Roll ») si ce n'est pas fait.
- [ ] Donner une date de soumission réaliste (ou demander mon avis chiffré).
- [ ] Pour ChatGPT : lui donner le lien de `docs/ZIEUTON_HANDOFF.md` sur GitHub, ou le coller dans sa conversation.
- [ ] Exporter les réponses du questionnaire testeurs (Google Forms → Réponses → feuille de calcul) et me les envoyer pour compléter `ZIEUTON_UX_RESEARCH.md`.
