# Sécurité du suivi de l'export (FOU-126, 21 nov. 2026)

Proposition validée par Victor et ChatGPT : https://claude.ai/artifact/TYkEqP95hSZReDry1DR4MG

Origine : vidéos du 21 nov. (13 h 50 et 14 h 22). La démo faisait envoyer `exportState pending:false`, et la coque effaçait le suivi d'une vraie demande (#153). Plus généralement, la coque faisait confiance à ce seul signal, sans raison.

## PR A (page seule, marche avec le build 21)

- `pending:false` seulement quand une attente vue dans la session se termine, jamais au démarrage ni en démo.
- « Rappel activé » devient « Notifications autorisées » : l'autorisation iOS ne prouve pas qu'un rappel est programmé.

## PR B (coque, build 22, `ZYEUTO_APP.version` 11)

| Pont | Sens | Rôle |
| --- | --- | --- |
| `exportState` | page → coque | Ignoré par la coque 11 (journal seulement). La page 11 ne l'envoie plus. |
| `exportEnded { reason, acct, requestedAt, importedAt? }` | page → coque | Fin du suivi. Acceptée seulement si `WatchSync.endAccepted` : raison `imported` ou `cleared`, compte de la demande, même demande (± 2 min entre l'heure notée par la page et par la coque). Pour `imported`, `importedAt` est la date de l'export lui-même, strictement après la demande, jamais dans le futur. |
| `exportResume { acct, requestedAt, existing, today, proven }` | page → coque | Reprise si la coque ne suit rien (`WatchSync.resumeAccepted`) : demande prouvée, moins de 4 jours, jamais terminée (`endedFor`). |
| `watch` → `window.zyeutoWatchInfo({ waiting, ready, reminders, acct, requestedAt, resumed })` | aller-retour | Ce que la coque suit vraiment. `reminders` = rappels enregistrés chez iOS. |

Une demande gardée par la page n'est pas une preuve Instagram. La reprise :
- n'envoie jamais « C'est demandé » et ne montre jamais l'écran A ;
- part sans référence : `ReadyProof` la refait seulement si la carte « En attente » est encore là (2 lectures à 2 s) ;
- sinon jamais « prêt » automatique. Si un vrai « Télécharger » est lu, le bandeau dit « Un fichier est disponible chez Instagram 👀 » (texte validé).

Bandeau `available` : remplace « vérifie la date » et « sans demande suivie » seulement quand un fichier téléchargeable est lu. Pas quand la ligne de la demande est encore « En attente » : un ancien export prêt ne doit pas faire croire que c'est disponible.

Textes de la page (coque 11) : « Rappel programmé » seulement si la coque suit cette demande (compte, heure) et a au moins un rappel enregistré ; sinon « Notifications autorisées ».

## Relecture ChatGPT du 21 nov. (corrigée)

**Point 1. Disparition d'état et effacement volontaire.** Avant, la page envoyait `cleared` dès que `prefs.requestedAt` changeait. Une perte de réglages aurait donc terminé le suivi. Maintenant, `cleared` part seulement de deux boutons confirmés : « Refaire quand même » (`confirmRedo`) et « Oui, tout effacer ». La page 11 ne déduit plus aucune fin d'un changement d'état. L'erreur d'import (« Refaire » dans la feuille) n'envoie rien : la nouvelle demande remplace l'ancienne côté coque (`requested()`).

**Point 2. Un ancien export importé.** Avant, `importedAt` valait `lastImportAt`, c'est-à-dire l'heure de l'import. Tout import après la demande terminait le suivi, même celui d'un vieux fichier, et la coque acceptait même 2 minutes avant la demande. Maintenant :
- `readExport` dit si la date vient des fichiers du .zip d'Instagram (`dated`) ;
- `commit()` envoie `imported` seulement si l'export est daté par le .zip et que la date n'a pas été changée à la main ;
- l'export doit être daté strictement après la demande et pas dans le futur, et importé dans le compte de la demande, qui ne doit pas être « à vérifier » ;
- la coque revérifie tout cela sans aucune tolérance avant la demande.

Limite connue : les dates d'un .zip sont lues en heure locale. Si Instagram les écrit en UTC, un bon export peut paraître une heure plus tôt. Le suivi est alors gardé : c'est l'erreur prudente. Il se termine quand même au fichier vu prêt, à « Refaire quand même » ou « Tout effacer », à une nouvelle demande, ou après 4 jours.

Pages plus anciennes : elles n'envoient jamais `exportEnded`. Le build 22 garde donc le suivi jusqu'à l'une de ces fins.

## 2e relecture ChatGPT du 21 nov. (corrigée)

**Téléchargement natif.** Avant, `MetaViewController.downloadDidFinish()` appelait `ExportWatcher.downloaded()`, donc `clear()`, avant même que la page lise le fichier. Un ancien .zip téléchargé effaçait ainsi le suivi d'une nouvelle demande. Maintenant, le téléchargement ne touche plus au suivi : `downloaded()` est supprimé. La fin vient seulement de la page, une fois le fichier analysé (`exportEnded imported`, voir ci-dessus).

**État de la page après l'import d'un ancien export.** Avant, `commit()` mettait `lastImportAt` à l'heure de l'import, et `reqPending()` le comparait à la demande. Un ancien export importé aujourd'hui faisait donc disparaître l'attente. Maintenant, `commit()` juge le fichier par rapport à la demande en attente (`importVerdict`) :
- `proves` : le .zip est daté après la demande. La demande est terminée et `exportEnded` est envoyé.
- `old` : le .zip est daté avant la demande. La demande reste en attente (`prefs.requestKept`), quelle que soit la coque, et même sur le site.
- `unsure` : .json seul ou date changée à la main. Avec la coque 11, la demande reste en attente, pour rester d'accord avec le suivi natif. Avec une coque plus ancienne ou sur le site, rien ne change par rapport à avant.

`requestKept` n'est valable que pour la même heure de demande. Une nouvelle demande, « Refaire » ou « Tout effacer » le rendent caduc. Il est gardé dans les réglages, donc il survit à la fermeture de l'app.

À décider plus tard (pas dans cette PR) : après l'import d'un fichier à date incertaine, la demande reste en attente jusqu'au fichier vu prêt, à « Refaire » ou à 4-5 jours. Un bouton « C'était bien mon export » pourrait la clore à la main.

## Tests sur iPhone (build 22)

| N° | Quoi faire | Attendu |
| --- | --- | --- |
| S1 | Nouvelle demande, notifications autorisées | B, « Rappel programmé » |
| S2 | Démo ouverte puis quittée 3 fois, puis « Vérifier mon export » | Bandeau « Pas encore prêt » tant que c'est en attente |
| S3 | Fermer Zieuton de force, rouvrir | B, « Rappel programmé » toujours là |
| S4 | Compte 2 affiché pendant une demande du compte 1 | Rien n'est annulé ; retour sur le compte 1 : B |
| S5 | Fichier prêt avec deux anciens exports | « C'est prêt ! Touche Télécharger » sur la bonne ligne |
| S6 | Demande perdue (installer le build 22 pendant une attente déjà perdue) | Suivi repris sans « C'est demandé » ; fichier déjà prêt : « Un fichier est disponible chez Instagram 👀 », jamais « prêt » |
| S7 | Import réel du .zip demandé (par Fichiers ou Partager) | Rappels retirés, plus de suivi |
| S7b | Pendant une demande, toucher « Télécharger » sur un ancien export dans Zieuton, puis l'importer | Carte « Ton export se prépare » toujours là, rappels gardés ; idem après fermeture et réouverture |
| S8 | « Refaire la demande » | Rappels de l'ancienne demande retirés, jamais repris |

## Vidéo build 22 (21 nov., 15 h 28) : « Un fichier est disponible » absent

Constat : fenêtre « Téléchargements disponibles » avec la carte « Expire le 25/11/2026 » et un vrai « Télécharger », mais le bandeau disait « Vérifie la date de ton export ».

Diagnostic :
1. Le bandeau ne se redessinait que lorsque le verdict de la preuve changeait. Le premier état reçu (avant la liste) donne « inconnu ».
2. Si la date de la carte n'est pas dans son propre bloc chez Instagram, le lecteur voit bien « Télécharger » mais sans date (« télécharger annuler ») : le verdict reste « inconnu ». Le « fichier vu » changeait, pas le verdict : aucun redessin.
   Avec une carte dont la date est lue, le verdict serait passé à « à vérifier » et le bandeau aurait changé : la vidéo désigne donc ce cas-là (ou une liste lue dans un sous-cadre, que ce correctif ne couvre pas).

Correctif (coque, build 23) : le bandeau se redessine aussi quand le « fichier vu » apparaît ou disparaît (`GetBanner.fileChanged`). La preuve « prêt » (ReadyProof) n'est pas touchée : un « Télécharger » sans date ne compte jamais.

Test iPhone (build 23) : rouvrir Instagram depuis « Vérifier mon export » quand la carte prête est là : le bandeau doit dire « Un fichier est disponible chez Instagram 👀 », jamais « C'est prêt ».
