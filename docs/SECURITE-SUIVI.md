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
| `exportEnded { reason, acct, requestedAt, importedAt? }` | page → coque | Fin du suivi. Acceptée seulement si `WatchSync.endAccepted` : raison `imported` ou `cleared`, compte de la demande, même demande (± 2 min), import après la demande. |
| `exportResume { acct, requestedAt, existing, today, proven }` | page → coque | Reprise si la coque ne suit rien (`WatchSync.resumeAccepted`) : demande prouvée, moins de 4 jours, jamais terminée (`endedFor`). |
| `watch` → `window.zyeutoWatchInfo({ waiting, ready, reminders, acct, requestedAt, resumed })` | aller-retour | Ce que la coque suit vraiment. `reminders` = rappels enregistrés chez iOS. |

Une demande gardée par la page n'est pas une preuve Instagram. La reprise :
- n'envoie jamais « C'est demandé » et ne montre jamais l'écran A ;
- part sans référence : `ReadyProof` la refait seulement si la carte « En attente » est encore là (2 lectures à 2 s) ;
- sinon jamais « prêt » automatique. Si un vrai « Télécharger » est lu, le bandeau dit « Un fichier est disponible chez Instagram 👀 » (texte validé).

Bandeau `available` : remplace « vérifie la date » et « sans demande suivie » seulement quand un fichier téléchargeable est lu. Pas quand la ligne de la demande est encore « En attente » : un ancien export prêt ne doit pas faire croire que c'est disponible.

Textes de la page (coque 11) : « Rappel programmé » seulement si la coque suit cette demande (compte, heure) et a au moins un rappel enregistré ; sinon « Notifications autorisées ».

## Tests sur iPhone (build 22)

| N° | Quoi faire | Attendu |
| --- | --- | --- |
| S1 | Nouvelle demande, notifications autorisées | B, « Rappel programmé » |
| S2 | Démo ouverte puis quittée 3 fois, puis « Vérifier mon export » | Bandeau « Pas encore prêt » tant que c'est en attente |
| S3 | Fermer Zieuton de force, rouvrir | B, « Rappel programmé » toujours là |
| S4 | Compte 2 affiché pendant une demande du compte 1 | Rien n'est annulé ; retour sur le compte 1 : B |
| S5 | Fichier prêt avec deux anciens exports | « C'est prêt ! Touche Télécharger » sur la bonne ligne |
| S6 | Demande perdue (installer le build 22 pendant une attente déjà perdue) | Suivi repris sans « C'est demandé » ; fichier déjà prêt : « Un fichier est disponible chez Instagram 👀 », jamais « prêt » |
| S7 | Import réel du fichier | Rappels retirés, plus de suivi |
| S8 | « Refaire la demande » | Rappels de l'ancienne demande retirés, jamais repris |
