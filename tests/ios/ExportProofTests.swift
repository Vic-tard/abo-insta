// Tests de la preuve de demande d'export (FOU-121).
// Une demande n'est confirmée que si la touche « Commencer l'exportation » a été vue ET qu'une ligne « En attente »
// de plus, datée d'aujourd'hui, est apparue. Sinon : « à vérifier » (jamais une réussite ni un échec inventés).
// Compilé avec le bloc EXPORT-PROOF de WebViewController.swift par scripts/test-export-proof.sh.
import Foundation

var failures = 0
func check(_ ok: Bool, _ name: String, line: Int = #line) {
    if ok { print("ok - \(name)") } else { failures += 1; print("ÉCHEC (ligne \(line)) - \(name)") }
}

var cal = Calendar(identifier: .gregorian)
cal.timeZone = TimeZone(identifier: "Europe/Paris")!
let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 14, minute: 47))!
let today = "instagram · moi demandée le 16 novembre 2026 en attente"
let old = "instagram · moi demandée le 2 novembre 2026 en attente"
func verdict(_ p: ExportProof, _ rows: [String]?, tapped: Bool = true) -> ExportProof.Verdict {
    p.verdict(rows, tapped: tapped, now: now, calendar: cal)
}

// 1. Parcours normal : aucune demande avant, touche vue, une ligne datée d'aujourd'hui après.
var p = ExportProof()
p.saw([], now: now, calendar: cal)
check(!p.alreadyPending, "liste vide au départ : pas de demande en cours")
check(verdict(p, [today]) == .none, "pas encore au résumé : rien n'est confirmé, même avec une ligne")
p.freeze()
check(verdict(p, []) == .none, "résumé atteint, retour sur l'accueil sans nouvelle ligne : rien (pas d'échec non plus)")
check(verdict(p, [today]) == .confirmed, "touche vue + une ligne d'aujourd'hui de plus : confirmé")
check(verdict(p, nil) == .none, "liste pas lue : rien")

// 2. Retour en arrière depuis le résumé final (bug C1) : la liste ne change pas.
var back = ExportProof()
back.saw([], now: now, calendar: cal); back.freeze()
check(verdict(back, [], tapped: false) == .none, "retour en arrière depuis le résumé : pas de fausse réussite")

// 3. Relecture ChatGPT, point 1 : une ANCIENNE ligne « En attente » qui s'affiche en retard,
//    après le résumé (la liste n'avait pas fini de charger au départ).
var late = ExportProof()
late.saw([], now: now, calendar: cal)      // la liste semblait vide…
late.freeze()
check(verdict(late, [old]) == .toCheck, "ancienne ligne (2 novembre) arrivée en retard, touche vue : à vérifier, pas confirmé")
check(verdict(late, [old], tapped: false) == .toCheck, "ancienne ligne arrivée en retard, sans touche : à vérifier")
check(verdict(late, [old, today]) == .confirmed, "puis la vraie nouvelle ligne arrive : confirmé")

// 4. Relecture ChatGPT, point 2 : une nouvelle ligne d'aujourd'hui mais la touche « Commencer » n'a pas été vue.
var noTap = ExportProof()
noTap.saw([], now: now, calendar: cal); noTap.freeze()
check(verdict(noTap, [today], tapped: false) == .toCheck, "ligne d'aujourd'hui sans touche vue : à vérifier")

// 5. Une ancienne demande déjà en cours, vue dès le départ.
var pending = ExportProof()
pending.saw([old], now: now, calendar: cal)
check(pending.alreadyPending, "une ligne « En attente » avant de commencer : demande déjà en cours")
pending.freeze()
check(!pending.alreadyPending, "une fois au résumé, on ne parle plus de demande déjà en cours")
check(verdict(pending, [old]) == .none, "l'ancienne ligne seule ne confirme rien")
check(verdict(pending, [today, old]) == .confirmed, "l'ancienne + une nouvelle d'aujourd'hui : confirmé")

// 6. Une demande d'aujourd'hui déjà en cours au départ : il en faut une deuxième d'aujourd'hui.
var twice = ExportProof()
twice.saw([today], now: now, calendar: cal); twice.freeze()
check(verdict(twice, [today, old]) == .toCheck, "une ligne de plus mais pas une ligne d'aujourd'hui de plus : à vérifier")
check(verdict(twice, [today, today]) == .confirmed, "deux lignes d'aujourd'hui : confirmé")

// 7. Liste qui s'affiche en plusieurs fois avant le résumé : on garde le plus grand nombre vu.
var slow = ExportProof()
slow.saw([], now: now, calendar: cal); slow.saw([old], now: now, calendar: cal); slow.saw([], now: now, calendar: cal)
slow.freeze()
check(verdict(slow, [old]) == .none, "liste lente : l'ancienne ligne, vue un instant, reste la référence")

// 8. La référence est figée au résumé.
var frozen = ExportProof()
frozen.saw([], now: now, calendar: cal); frozen.freeze(); frozen.saw([today], now: now, calendar: cal)
check(frozen.before == 0, "après le résumé, une nouvelle lecture ne change pas la référence")
check(verdict(frozen, [today]) == .confirmed, "et la nouvelle ligne confirme bien la demande")

// 9. Liste jamais vue (arrivé directement sur le résumé) : impossible de conclure.
var never = ExportProof()
never.freeze()
check(!never.frozen, "sans liste de départ, rien n'est figé")
check(verdict(never, [today, today]) == .none, "sans liste de départ : rien (on proposera de vérifier)")

// 10. Recommencer efface tout.
var again = ExportProof()
again.saw([today, old], now: now, calendar: cal); again.freeze(); again.reset()
check(again.before == nil && again.recentBefore == 0 && !again.frozen, "reset : tout est effacé")

// 11. Reconnaître une date d'aujourd'hui.
func recent(_ s: String) -> Bool { ExportProof.isRecent(s, now: now, calendar: cal) }
check(recent("demandée le 16 novembre 2026"), "« 16 novembre 2026 »")
check(recent("demandée le 16 nov. · en attente"), "« 16 nov. »")
check(recent("requested nov 16, 2026 pending"), "« nov 16, 2026 »")
check(recent("requested november 16th"), "« november 16th »")
check(recent("demandée à l'instant"), "« à l'instant »")
check(recent("demandée aujourd'hui"), "« aujourd'hui »")
check(recent("il y a 3 min"), "« il y a 3 min »")
check(recent("2m ago"), "« 2m ago »")
check(recent("16/11/2026"), "« 16/11/2026 »")
check(!recent("demandée le 2 novembre 2026"), "« 2 novembre » : ancienne")
check(!recent("demandée le 16 novembre 2025"), "« 16 novembre 2025 » : autre année, ancienne")
check(!recent("demandée le 6 novembre"), "« 6 novembre » n'est pas « 16 novembre »")
check(!recent("demandée le 116 novembre"), "pas de faux « 16 » au milieu d'un nombre")
check(!recent("demandée le 16 octobre"), "« 16 octobre » : ancienne")
check(!recent("il y a 2 h"), "« il y a 2 h » : trop vieux pour être la nouvelle demande")
check(!recent("il y a 45 min"), "« il y a 45 min » : trop vieux")
check(!recent("en attente"), "aucune date : pas récente (on demandera de vérifier)")

// 12. Relecture ChatGPT n° 2 : en « à vérifier », toucher le bandeau demande une confirmation, jamais une validation directe.
check(ExportProof.bannerTap(requesting: true, finished: false, toCheck: true) == .askConfirm, "« à vérifier » + touche du bandeau : fenêtre de confirmation")
check(ExportProof.bannerTap(requesting: true, finished: false, toCheck: false) == .other, "pas en « à vérifier » : pas de confirmation")
check(ExportProof.bannerTap(requesting: true, finished: true, toCheck: true) == .other, "déjà confirmée : plus rien à confirmer")
check(ExportProof.bannerTap(requesting: false, finished: false, toCheck: true) == .other, "hors demande (récupération du fichier) : rien")

// 13. Relecture ChatGPT n° 2 : retoucher « Créer une exportation » après une demande non confirmée avertit du doublon.
check(ExportProof.duplicateRisk(tappedStart: true, toCheck: false, finished: false), "« Commencer » touché, pas encore confirmé : avertissement")
check(ExportProof.duplicateRisk(tappedStart: false, toCheck: true, finished: false), "ligne « à vérifier » : avertissement")
check(!ExportProof.duplicateRisk(tappedStart: false, toCheck: false, finished: false), "aucune demande en vue : pas d'avertissement (premier parcours)")
check(!ExportProof.duplicateRisk(tappedStart: true, toCheck: false, finished: true), "demande confirmée : le parcours est fini, rien à avertir ici")

// 14. Demande partie avec un mauvais réglage.
check(ExportProof.problem("summary:period")?.title == "avec « Année dernière »", "« Année dernière » signalé")
check(ExportProof.problem("summary:format") != nil, "HTML signalé")
check(ExportProof.problem("summary:info") != nil, "toutes les informations signalé")
check(ExportProof.problem("summary:start") == nil, "bons réglages : rien à signaler")
check(ExportProof.problem("") == nil, "résumé jamais lu : rien à signaler (pas d'invention)")

// 15. FOU-121 P2 : connexion. Un refus = une apparition du message, conseil « Mot de passe oublié ? » au 2e refus.
var help = LoginHelp()
check(!help.manyBadPasswords, "aucun refus : pas de conseil")
help.saw(badPassword: true); help.saw(badPassword: true); help.saw(badPassword: true)
check(help.badPasswords == 1 && !help.manyBadPasswords, "message affiché longtemps = un seul refus")
help.saw(badPassword: false)
check(help.badPasswords == 1, "message parti : pas de refus en plus")
help.saw(badPassword: true)
check(help.manyBadPasswords, "2e refus : conseil « Mot de passe oublié ? »")
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorCancelled) == .none, "navigation annulée : pas une panne")
check(LoginHelp.loadFailure(domain: "WebKitErrorDomain", code: 102) == .none, "page devenue téléchargement : pas une panne")
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet) == .network, "pas d'Internet : panne réseau")
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorTimedOut) == .network, "délai dépassé : panne réseau")
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost) == .network, "connexion perdue : panne réseau")
// Relecture ChatGPT n° 3 : une autre erreur n'est jamais présentée comme un problème de Wi-Fi.
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted) == .other, "certificat refusé : message neutre, pas « Wi-Fi »")
check(LoginHelp.loadFailure(domain: NSURLErrorDomain, code: NSURLErrorBadURL) == .other, "adresse invalide : message neutre")
check(LoginHelp.loadFailure(domain: "WebKitErrorDomain", code: 101) == .other, "autre erreur WebKit : message neutre")
let t0 = Date(timeIntervalSince1970: 1_000_000)
check(!LoginHelp.downloadStuck(since: t0, now: t0.addingTimeInterval(30)), "téléchargement de 30 s : normal")
check(LoginHelp.downloadStuck(since: t0, now: t0.addingTimeInterval(91)), "téléchargement de plus de 90 s : bloqué")

// 16. FOU-121 P4 : bandeau v2. Couleur selon la situation, 4 grandes phases, alerte qui ne part pas au bout d'un délai.
check(BannerTone.of(verb: "Touche", isWarning: false) == .consigne, "consigne : rose poudré")
check(BannerTone.of(verb: "", isWarning: true) == .fix, "mauvais bouton : réglage à corriger")
check(BannerTone.of(verb: "Demande enregistrée, mais", isWarning: false) == .fix, "demande avec un mauvais réglage : à corriger")
check(BannerTone.of(verb: "Petit souci :", isWarning: false) == .souci, "mot de passe, code, identifiant : petit souci (pas de rouge)")
check(BannerTone.of(verb: "Oups :", isWarning: false) == .souci, "réseau, page fermée : petit souci")
check(BannerTone.of(verb: "Je ne reconnais pas encore", isWarning: false) == .pause, "écran inconnu : pause neutre")
check(BannerTone.of(verb: "Parfait ! Maintenant,", isWarning: false) == .success, "bonne case cochée : réussite lilas")
check(BannerTone.of(verb: "C'est prêt ! Touche", isWarning: false) == .success, "fichier vu prêt : réussite")
check(BannerPhases.current(login: true, code: false, finalStep: false, requested: false, file: false) == 0, "mot de passe : phase Connexion")
check(BannerPhases.current(login: false, code: true, finalStep: false, requested: false, file: false) == 0, "code de sécurité : phase Connexion")
check(BannerPhases.current(login: false, code: false, finalStep: false, requested: false, file: false) == 1, "cases et période : phase Réglages")
check(BannerPhases.current(login: false, code: false, finalStep: true, requested: false, file: false) == 2, "« Commencer l'exportation » : phase Demande")
check(BannerPhases.current(login: false, code: false, finalStep: true, requested: true, file: false) == 2, "demande touchée, pas encore vue : toujours Demande")
check(BannerPhases.current(login: false, code: false, finalStep: true, requested: true, file: true) == 3, "guet du fichier : phase Fichier")
check(BannerPhases.current(login: true, code: false, finalStep: false, requested: false, file: true) == 0, "reconnexion pendant la récupération : Connexion d'abord")
check(!BannerPhases.warningCleared(leftStepScreen: false, backOnStepScreen: true), "mauvais choix sur le même écran : l'alerte reste")
check(!BannerPhases.warningCleared(leftStepScreen: true, backOnStepScreen: false), "toujours sur le mauvais écran : l'alerte reste")
check(BannerPhases.warningCleared(leftStepScreen: true, backOnStepScreen: true), "revenu sur le bon écran : l'alerte part")

// 17. Relecture ChatGPT de P4 : pas d'alerte perdue sur un écran inconnu, pas de vibration en boucle.
check(!BannerPhases.clearsWarning(.lostChanged), "écran pas reconnu (chargement) : l'alerte de mauvais choix reste")
check(BannerPhases.clearsWarning(.codeChanged), "code de sécurité d'Instagram : autre étape, l'ancienne alerte part")
check(BannerPhases.shouldWarnWrongProfile(onScreen: true, alreadyWarned: false), "arrivée sur le compte Facebook/Threads : une alerte")
check(!BannerPhases.shouldWarnWrongProfile(onScreen: true, alreadyWarned: true), "toujours sur cet écran : pas de nouvelle vibration")
check(!BannerPhases.shouldWarnWrongProfile(onScreen: false, alreadyWarned: false), "autre écran : pas d'alerte")
var warned = false, shakes = 0
for onScreen in [true, true, true, true, true, true] {   // 6 passages de watch() (3 s) sur le même écran
    if BannerPhases.shouldWarnWrongProfile(onScreen: onScreen, alreadyWarned: warned) { warned = true; shakes += 1 }
}
check(shakes == 1, "rester 3 s sur l'écran du mauvais compte : une seule secousse")

// 18. FOU-121 P5 (R2) : les cases sorties de la page en défilant restent comptées.
var cases = PickMemory()
cases.saw([("Followers et suivi(e)s", true), ("Contacts synchronisés", false)])
check(cases.checked == 1 && cases.followers && cases.extra == nil, "en haut de la liste : seulement Followers cochée")
cases.saw([("Messages", true), ("Commentaires", false)])   // plus bas : Followers n'est plus dans la page
check(cases.checked == 2 && cases.followers, "case cochée plus bas : comptée, et Followers reste retenue")
check(cases.extra == "Messages", "la case en trop est nommée")
cases.saw([("Messages", false)])                            // décochée par l'utilisateur
check(cases.checked == 1 && cases.extra == nil, "case décochée : plus en trop")
var vide = PickMemory()
vide.saw([("Contacts synchronisés", false)])
check(!vide.followers && vide.checked == 0, "Followers jamais vue cochée : pas de « Bonne case cochée »")
check(PickMemory.isFollowers("Followers and following"), "nom anglais reconnu")
// 19. FOU-121 P5 : un bon choix confirmé (✓) passe au lilas.
check(BannerTone.of(verb: "✓ Bonne case cochée ! Maintenant,", isWarning: false) == .success, "✓ Bonne case cochée : lilas")
check(BannerTone.of(verb: "✓ Bon choix ! Maintenant,", isWarning: false) == .success, "✓ Bon choix : lilas")
check(ExportProof.problem("summary:info")?.title == "avec trop d'informations", "résumé avec plus que les abonnés : signalé après la demande")

// 20. Relecture ChatGPT de P5 : la mémoire des cases ne s'efface pas toute seule, « ✓ Tout est bien réglé » seulement sur preuve.
check(!PickMemory.resets(onScreen: "pick"), "retour sur la page des cases : on garde la mémoire")
check(!PickMemory.resets(onScreen: "summary:info"), "passage par le résumé : on garde la mémoire")
check(!PickMemory.resets(onScreen: ""), "écran pas reconnu (chargement) : on garde la mémoire")
check(PickMemory.resets(onScreen: "home"), "accueil de l'export (nouvelle demande) : la mémoire repart de zéro")
var longue = PickMemory()
longue.saw([("Messages", true)])                    // cochée plus bas, vue il y a longtemps
longue.saw([("Followers et suivi(e)s", true)])      // la page revient après un long chargement : seulement le haut
check(longue.checked == 2, "case cochée vue avant un long chargement : toujours comptée (pas de faux « Bonne case cochée »)")
check(PickMemory.settingsVerified(summaryInfo: "followers", followersAlone: false), "résumé « Followers et suivi(e)s » : ✓")
check(PickMemory.settingsVerified(summaryInfo: "one", followersAlone: true), "« 1 élément » + Followers vue seule cochée : ✓")
check(!PickMemory.settingsVerified(summaryInfo: "one", followersAlone: false), "« 1 élément » sans preuve que c'est Followers : pas de ✓")
check(!PickMemory.settingsVerified(summaryInfo: "", followersAlone: true), "résumé illisible : pas de ✓")

// 21. FOU-124 : après une demande vérifiée, on dit comment revenir dans Zieuton, jamais avant.
check(LeaveHint.showsButton(guarding: true, ready: false, badSettings: false, pageProblem: false, downloading: false),
      "demande vérifiée, fichier pas prêt : bouton « Revenir dans Zieuton »")
check(!LeaveHint.showsButton(guarding: false, ready: false, badSettings: false, pageProblem: false, downloading: false),
      "demande pas encore vérifiée (pas de guet) : pas de bouton")
check(!LeaveHint.showsButton(guarding: true, ready: true, badSettings: false, pageProblem: false, downloading: false),
      "fichier prêt : on montre « Télécharger », pas le bouton de sortie")
check(!LeaveHint.showsButton(guarding: true, ready: false, badSettings: true, pageProblem: false, downloading: false),
      "demande partie avec un mauvais réglage : pas de « plus rien à faire »")
check(!LeaveHint.showsButton(guarding: true, ready: false, badSettings: false, pageProblem: true, downloading: false),
      "page en panne : pas de bouton de sortie")
check(!LeaveHint.showsButton(guarding: true, ready: false, badSettings: false, pageProblem: false, downloading: true),
      "téléchargement en cours : on ne propose pas de fermer")
check(LeaveHint.verb(existing: false).hasPrefix("✓") && LeaveHint.verb(existing: true).hasPrefix("✓"), "message de sortie en lilas (réussite vérifiée)")
check(BannerTone.of(verb: LeaveHint.verb(existing: false), isWarning: false) == .success, "couleur : réussite")
check(LeaveHint.target.contains("‹ Zieuton") && LeaveHint.target.contains("en haut à gauche"), "le message dit où toucher")
check(!LeaveHint.tip.contains("toutes les") && !LeaveHint.tip.contains("en continu"), "pas de promesse de surveillance continue")

// 22. FOU-126 : une ligne est-elle datée du jour de la demande ?
let jour = now                                                    // 16 novembre 2026
let lendemain = cal.date(byAdding: .day, value: 1, to: now)!
check(ExportProof.isDated("demandée le 16 novembre 2026 télécharger", day: jour, now: now, calendar: cal), "date écrite du jour : oui")
check(!ExportProof.isDated("demandée le 2 novembre 2026 télécharger", day: jour, now: now, calendar: cal), "autre date : non")
check(!ExportProof.isDated("demandée le 16 novembre 2025 télécharger", day: jour, now: now, calendar: cal), "même jour, autre année : non")
check(ExportProof.isDated("requested nov 16, 2026 download", day: jour, now: now, calendar: cal), "date anglaise : oui")
check(ExportProof.isDated("demandée aujourd'hui", day: jour, now: now, calendar: cal), "« aujourd'hui » lu le jour même : oui")
check(!ExportProof.isDated("demandée aujourd'hui", day: jour, now: lendemain, calendar: cal), "« aujourd'hui » lu le lendemain : ce n'est plus le jour de la demande")
check(ExportProof.isDated("demandée hier", day: jour, now: lendemain, calendar: cal), "« hier » lu le lendemain : oui")
check(ExportProof.isDated("demandée le 16 novembre 2026", day: jour, now: lendemain, calendar: cal), "date écrite lue le lendemain : oui")
check(ExportProof.isRecent("à l'instant", now: now, calendar: cal) && !ExportProof.isRecent("hier", now: now, calendar: cal), "isRecent inchangé")

// 23. FOU-126 : preuve « prêt » (ReadyProof). On suit la ligne de la demande, jamais un simple nombre de « Télécharger ».
let enAttente = "instagram · moi demandée le 16 novembre 2026 en attente"
let pretAncien = "instagram · moi demandée le 2 novembre 2026 télécharger"
let pretJour = "instagram · moi demandée le 16 novembre 2026 télécharger"
func s(_ t: TimeInterval) -> Date { now.addingTimeInterval(t) }
func rv(_ r: ReadyProof, _ pending: [String]?, _ ready: [String]?, login: Bool = false, offline: Bool = false, at: Date = now) -> ReadyProof.Verdict {
    r.verdict(pending: pending, ready: ready, login: login, offline: offline, now: at, calendar: cal)
}
// Ancien export prêt d'une autre date + nouvelle demande.
var r1 = ReadyProof(day: now)
r1.read(pending: [enAttente], ready: [pretAncien], now: s(0), calendar: cal)
check(r1.baseline == nil, "une seule lecture : référence pas encore vérifiée")
r1.read(pending: [enAttente], ready: [pretAncien], now: s(1), calendar: cal)
check(r1.baseline == nil, "deux lectures à 1 s : pas encore")
r1.read(pending: [enAttente], ready: [pretAncien], now: s(2.5), calendar: cal)
check(r1.baseline == 0, "deux lectures identiques à 2 s d'écart : référence = 0 ligne prête du jour (vérifiée)")
check(rv(r1, [enAttente], [pretAncien]) == .pending, "ancien export d'une autre date prêt : pas prêt, en préparation")
check(rv(r1, [], [pretJour, pretAncien]) == .ready, "la ligne du jour devient prête : prêt")
check(rv(r1, [], [pretAncien]) == .unknown, "plus rien d'en attente ni de prêt du jour : inconnu, pas prêt")
// Ancien export prêt du même jour.
var r2 = ReadyProof(day: now)
for t in [0.0, 2.5] { r2.read(pending: [enAttente], ready: [pretJour], now: s(t), calendar: cal) }
check(r2.baseline == 1, "un export du même jour déjà prêt : il est dans la référence")
check(rv(r2, [enAttente], [pretJour]) == .pending, "même jour, pas de ligne de plus : pas prêt")
check(rv(r2, [], [pretJour, pretJour]) == .ready, "une ligne prête de plus le même jour : prêt")
check(rv(r2, [], []) == .unknown, "l'ancien du même jour expire, le nouveau pas encore là : pas de faux prêt")
check(rv(r2, [], [pretJour]) == .toCheck, "l'ancien expire et une ligne du jour reste : à vérifier, jamais prêt")
// Référence absente ou pas vérifiée.
let r3 = ReadyProof(day: now)
check(rv(r3, [], [pretJour]) == .toCheck, "référence absente : au mieux à vérifier")
check(rv(r3, [], [pretJour, pretJour, pretJour]) != .ready, "référence absente : jamais prêt, même avec plusieurs lignes")
var r4 = ReadyProof(day: now)
r4.read(pending: [enAttente], ready: [], now: s(0), calendar: cal)
check(r4.baseline == nil && rv(r4, [], [pretJour]) == .toCheck, "référence à 0 lue une seule fois (pas vérifiée) : jamais prêt")
var r5 = ReadyProof(day: now)
r5.read(pending: [], ready: [], now: s(0), calendar: cal)
r5.read(pending: [], ready: [], now: s(3), calendar: cal)
check(r5.baseline == nil, "liste vide (pas chargée, ou demande disparue) : pas de référence")
var r6 = ReadyProof(day: now)
r6.read(pending: [enAttente], ready: [], now: s(0), calendar: cal)
r6.read(pending: [enAttente], ready: [pretJour], now: s(2.5), calendar: cal)
check(r6.baseline == nil, "deux lectures différentes : pas de référence")
// Ce qui n'est jamais « prêt ».
check(rv(r1, nil, nil, login: true) == .login, "écran de connexion : reconnexion nécessaire")
check(rv(r1, nil, nil) == .unknown, "liste illisible : inconnu")
check(rv(r1, [], [pretJour], offline: true) == .offline, "pas de réseau : hors ligne, même si une vieille lecture disait prêt")
check(rv(r1, [], []) == .unknown, "liste vide : inconnu")
// Demande déjà en cours (heure inconnue) : le jour vient de sa ligne « En attente ».
var r7 = ReadyProof(day: nil)
let attenteHier = "instagram · moi demandée le 15 novembre 2026 en attente"
check(rv(r7, [], [pretJour]) == .toCheck, "jour inconnu + une ligne prête récente : à vérifier")
check(rv(r7, [], [pretAncien]) == .unknown, "jour inconnu + seulement un vieil export : inconnu")
for t in [0.0, 2.5] { r7.read(pending: [attenteHier], ready: [pretAncien], now: s(t), calendar: cal) }
check(r7.day.map { cal.isDate($0, inSameDayAs: cal.date(byAdding: .day, value: -1, to: now)!) } == true, "demande déjà en cours d'hier : jour lu sur sa ligne")
check(r7.baseline == 0, "puis référence vérifiée comme d'habitude")
check(rv(r7, [], ["instagram · moi demandée le 15 novembre 2026 télécharger", pretAncien]) == .ready, "sa ligne devient prête : prêt")
check(ReadyProof.rank(.ready) > ReadyProof.rank(.pending) && ReadyProof.rank(.pending) > ReadyProof.rank(.unknown), "pendant une vérification, « prêt » l'emporte, puis « en préparation »")

// 24. FOU-126 : quelles notifications (NoticePlan).
let demande = now
func ids(_ p: NoticePlan) -> [String] { p.post.map { $0.id } }
let ok = NoticePlan.sync(requestedAt: demande, now: s(2), auth: .authorized, ready: false, askedShown: false, readyShown: false)
check(ids(ok) == ["zy-asked", "zy-reminder", "zy-reminder-24h"], "preuve + autorisé : A, B1, B2")
check(abs((ok.post.first(where: { $0.id == "zy-reminder" })?.after ?? 0) - (30 * 60 - 2)) < 0.01, "B1 à 30 min de la demande")
check(abs((ok.post.first(where: { $0.id == "zy-reminder-24h" })?.after ?? 0) - (24 * 3600 - 2)) < 0.01, "B2 à 24 h de la demande")
check(ok.cancel.contains("zy-last-day") && ok.cancel.contains("zy-likely"), "les anciennes « expire bientôt » et « sûrement prêt » sont retirées")
let deja = NoticePlan.sync(requestedAt: demande, now: s(60), auth: .authorized, ready: false, askedShown: true, readyShown: false)
check(ids(deja) == ["zy-reminder", "zy-reminder-24h"], "retour dans l'app : A pas renvoyée, rappels reprogrammés à la même heure")
let pret = NoticePlan.sync(requestedAt: demande, now: s(600), auth: .authorized, ready: true, askedShown: true, readyShown: false)
check(ids(pret) == ["zy-ready"], "prêt : C")
check(pret.cancel.contains("zy-reminder") && pret.cancel.contains("zy-reminder-24h"), "prêt : B1 et B2 annulés")
check(NoticePlan.sync(requestedAt: demande, now: s(700), auth: .authorized, ready: true, askedShown: true, readyShown: true).post.isEmpty, "C jamais envoyée deux fois")
let fin = NoticePlan.end()
check(fin.post.isEmpty && Set(fin.cancel).isSuperset(of: ["zy-asked", "zy-ready", "zy-reminder", "zy-reminder-24h", "zy-last-day"]), "import, téléchargement ou demande refaite : tout est annulé")
let refuse = NoticePlan.sync(requestedAt: demande, now: s(2), auth: .denied, ready: false, askedShown: false, readyShown: false)
check(refuse.post.isEmpty, "notifications refusées : rien de programmé")
check(NoticePlan.sync(requestedAt: demande, now: s(2), auth: .notDetermined, ready: false, askedShown: false, readyShown: false).post.isEmpty,
      "« Plus tard » : rien tant que l'autorisation n'est pas donnée")
let tard = NoticePlan.sync(requestedAt: demande, now: s(45 * 60), auth: .authorized, ready: false, askedShown: false, readyShown: false)
check(ids(tard) == ["zy-asked", "zy-reminder-24h"], "autorisation donnée 45 min après : A une fois, B1 dépassé sauté, B2 gardé")
let tardPret = NoticePlan.sync(requestedAt: demande, now: s(45 * 60), auth: .authorized, ready: true, askedShown: false, readyShown: false)
check(ids(tardPret) == ["zy-ready"], "autorisation donnée après le fichier vu prêt : C tout de suite, pas de « C'est demandé » inutile")
check(!NoticePlan.showsInForeground("zy-reminder") && !NoticePlan.showsInForeground("zy-reminder-24h"), "app ouverte : B1 et B2 pas affichées")
check(NoticePlan.showsInForeground("zy-asked") && NoticePlan.showsInForeground("zy-ready"), "app ouverte : A et C affichées")
check(!NoticePlan.all.contains { $0.contains("expire") }, "aucune notification « expire »")

// 25. FOU-126 : les textes décidés.
check(NoticeText.of("zy-asked", existing: false, hour: "14:32") == NoticeText.Text(title: "C'est demandé ✓",
      body: "Instagram prépare ton fichier. Tu pourras vérifier son état dans Zieuton.", subtitle: "Demandé à 14:32"), "texte A")
check(NoticeText.of("zy-asked", existing: true, hour: nil)?.title == "Une demande est déjà en cours ✓", "texte A, demande déjà en cours")
check(NoticeText.of("zy-asked", existing: true, hour: nil)?.subtitle == nil, "demande déjà en cours : pas d'heure inventée")
check(NoticeText.of("zy-reminder", existing: false, hour: "14:32")?.title == "Des nouvelles de ton export ? 👀", "texte B1")
check(NoticeText.of("zy-reminder-24h", existing: false, hour: nil)?.body == "Ouvre Zieuton pour vérifier où en est Instagram.", "texte B2")
check(NoticeText.of("zy-ready", existing: false, hour: nil)?.title == "Ton fichier est prêt 🎉", "texte C")
for id in NoticePlan.all {
    guard let t = NoticeText.of(id, existing: false, hour: "14:32") else { continue }
    let all = (t.title + " " + t.body + " " + (t.subtitle ?? "")).lowercased()
    for banned in ["dès que je le vois", "je guette", "expire", "sûrement prêt", "plus long que d'habitude", "zieuton fermé"] {
        check(!all.contains(banned), "« \(banned) » absent de \(id)")
    }
}

print(failures == 0 ? "\nTout est vert." : "\n\(failures) test(s) en échec.")
exit(failures == 0 ? 0 : 1)
