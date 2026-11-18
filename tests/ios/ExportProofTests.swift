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
check(LeaveHint.tip.contains("revenir dans Zieuton") && LeaveHint.tip.count <= 75, "18 nov. : message court, qui dit comment revenir (le bouton est juste dessous)")
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
/// Relecture ChatGPT (18 nov.) : « prêt » doit être revu au moins 2 s plus tard. Lit deux fois la même liste (à `at`, puis 2,5 s après)
/// et rend le verdict de la seconde lecture.
func settle(_ r: inout ReadyProof, _ pending: [String], _ ready: [String], at: Date = now) -> ReadyProof.Verdict {
    r.read(pending: pending, ready: ready, now: at, calendar: cal)
    r.read(pending: pending, ready: ready, now: at.addingTimeInterval(2.5), calendar: cal)
    return rv(r, pending, ready, at: at.addingTimeInterval(2.5))
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
check(rv(r1, [], [pretJour, pretAncien]) != .ready, "la ligne du jour devient prête, pas encore relue : jamais « prêt » tout de suite")
r1.read(pending: [], ready: [pretJour, pretAncien], now: s(10), calendar: cal)
r1.read(pending: [], ready: [pretJour, pretAncien], now: s(11), calendar: cal)
check(rv(r1, [], [pretJour, pretAncien], at: s(11)) != .ready, "relue 1 s plus tard seulement : pas encore « prêt »")
check(settle(&r1, [], [pretJour, pretAncien], at: s(20)) == .ready, "la ligne du jour devient prête, revue 2 s plus tard : prêt")
check(rv(r1, [], [pretAncien]) == .unknown, "plus rien d'en attente ni de prêt du jour : inconnu, pas prêt")
// Ancien export prêt du même jour.
var r2 = ReadyProof(day: now)
for t in [0.0, 2.5] { r2.read(pending: [enAttente], ready: [pretJour], now: s(t), calendar: cal) }
check(r2.baseline == 1, "un export du même jour déjà prêt : il est dans la référence")
check(rv(r2, [enAttente], [pretJour]) == .pending, "même jour, pas de ligne de plus : pas prêt")
check(settle(&r2, [], [pretJour, pretJour], at: s(10)) == .ready, "une ligne prête de plus le même jour, revue : prêt")
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
check(settle(&r7, [], ["instagram · moi demandée le 15 novembre 2026 télécharger", pretAncien], at: s(10)) == .ready, "sa ligne devient prête, revue : prêt")
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

// 26. FOU-126 : multicompte. Seul le compte de la demande peut dire que l'attente est finie.
check(!NoticePlan.endsWait(requestAcct: "a1", sender: "a2"), "un autre compte n'annule pas les rappels de la demande")
check(!NoticePlan.endsWait(requestAcct: "a1", sender: nil), "message sans compte : la demande d'un compte connu continue")
check(!NoticePlan.endsWait(requestAcct: "a1", sender: ""), "compte vide : la demande d'un compte connu continue")
check(NoticePlan.endsWait(requestAcct: "a1", sender: "a1"), "le compte de la demande arrête l'attente")
check(NoticePlan.endsWait(requestAcct: nil, sender: "a2"), "demande sans compte connu (page ancienne) : l'attente s'arrête comme avant")
check(NoticePlan.endsWait(requestAcct: "", sender: nil), "demande sans compte, message sans compte : l'attente s'arrête comme avant")

// 27. Tests iPhone du 17 nov. : textes tels que le lecteur les envoie pour la vraie liste (cartes « Demandée le 17/11/2026 »).
let n17 = cal.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 17, minute: 32))!
let carteAttente = "en attente · demandée le 17/11/2026 · vifrnt (instagram) followers et suivi(e)s exporter vers appareil · une fois · json demandée le 17/11/2026 annuler"
// Vidéo du 18 nov. : une carte prête ne dit pas « Demandée le » mais « Expire le … · Moins de 1 Mo » (fichier gardé 4 jours).
// Prêt le 16/11 : expire le 20/11. Prêt le 17/11 : expire le 21/11.
let carteAncienne = "expire le 20/11/2026 · moins de 1 mo · vifrnt (instagram) followers et suivi(e)s exporter vers appareil · une fois · json expire le 20/11/2026 · moins de 1 mo télécharger annuler"
let carteJourPrete = "expire le 21/11/2026 · moins de 1 mo · vifrnt (instagram) followers et suivi(e)s exporter vers appareil · une fois · json expire le 21/11/2026 · moins de 1 mo télécharger annuler"
check(ExportProof.isDated(carteAttente, day: n17, now: n17, calendar: cal), "17 nov. : « Demandée le 17/11/2026 » est bien du jour")
check(!ExportProof.isDated(carteAncienne, day: n17, now: n17, calendar: cal), "17 nov. : l'ancien export (expire le 20/11) n'est pas daté du jour")
var p17 = ExportProof()
p17.saw([], now: n17, calendar: cal)
p17.freeze()
check(p17.verdict([carteAttente], tapped: true, now: n17, calendar: cal) == .confirmed, "17 nov. : la nouvelle carte « En attente » datée du jour confirme la demande")
var r17 = ReadyProof(day: n17)
for t in [0.0, 1.0, 2.5] { r17.read(pending: [carteAttente], ready: [carteAncienne], now: n17.addingTimeInterval(t), calendar: cal) }
check(r17.baseline == 0, "17 nov. : référence = 0 (l'ancien export expire le 20/11 : prêt avant le 17/11)")
check(r17.verdict(pending: [carteAttente], ready: [carteAncienne], login: false, offline: false, now: n17.addingTimeInterval(60), calendar: cal) == .pending,
      "17 nov. : ancien export prêt + nouvelle demande en attente : « pas encore prêt », jamais « prêt »")
check(settle(&r17, [], [carteAncienne, carteJourPrete], at: n17.addingTimeInterval(300)) == .ready,
      "17 nov. : la carte du 17/11 a maintenant « Télécharger » : prêt")
check(ReadyProof.latestDay(of: [carteAttente], now: n17, calendar: cal).map { cal.isDate($0, inSameDayAs: n17) } == true,
      "17 nov. : le jour d'une demande vue en retard est lu sur sa carte")

// 28. Tests iPhone du 17 nov. (17 h 34) : pour récupérer le fichier, le bandeau suit la preuve « prêt », jamais un bouton seul.
check(GetBanner.of(waiting: true, proven: false, verdict: nil) == .looking, "liste pas encore lue : « je cherche ta demande », pas « Touche Télécharger »")
check(GetBanner.of(waiting: true, proven: false, verdict: .pending) == .notYet, "ancien export prêt + demande en attente : « pas encore prêt »")
check(GetBanner.of(waiting: true, proven: false, verdict: .toCheck) == .checkDate, "pas de preuve : l'utilisateur vérifie la date")
check(GetBanner.of(waiting: true, proven: false, verdict: .unknown) == .checkDate, "liste illisible : vérifier la date, jamais « prêt »")
check(GetBanner.of(waiting: true, proven: false, verdict: .ready) == .ready, "la ligne de la demande a « Télécharger » : prêt")
check(GetBanner.of(waiting: false, proven: true, verdict: nil) == .ready, "fichier déjà prouvé prêt : prêt")
check(GetBanner.of(waiting: false, proven: false, verdict: nil) == .unproven, "aucune demande prouvée : consigne générale, sans cercle")
check(GetBanner.dayText(n17, calendar: cal) == "17/11", "date courte « 17/11 »")

// 29. Tests iPhone du 17 nov. (17 h 35) : une demande « déjà en cours » datée d'aujourd'hui n'est pas présentée comme ancienne.
var p29 = ExportProof()
p29.saw([carteAttente], now: n17, calendar: cal)
check(p29.alreadyPending && p29.pendingToday, "carte « En attente » du 17/11 vue avant toute touche : demande du jour")
var p29b = ExportProof()
p29b.saw(["en attente · demandée le 15/11/2026 · vifrnt (instagram) annuler"], now: n17, calendar: cal)
check(p29b.alreadyPending && !p29b.pendingToday, "carte du 15/11 : vraie demande déjà en cours")
check(NoticeText.of("zy-asked", existing: true, today: true, hour: nil)?.title == "Une demande d'aujourd'hui est en cours ✓", "notification A : demande du jour, sans « déjà en cours »")
check(NoticeText.of("zy-asked", existing: true, today: true, hour: nil)?.subtitle == nil, "demande du jour vue en retard : pas d'heure inventée")
check(!LeaveHint.title(existing: true, today: true).contains("déjà en cours"), "bandeau : demande du jour, sans « déjà en cours »")
check(LeaveHint.title(existing: true).contains("déjà en cours"), "bandeau : une demande d'un autre jour reste « déjà en cours »")

// 30. Relecture ChatGPT (18 nov.) : deux exports du même jour, dont un ancien déjà prêt.
// Une date d'aujourd'hui ne prouve pas que la demande est la sienne : jamais « prêt » à cause de l'ancien fichier.
let n30 = n17.addingTimeInterval(4 * 3600)                                   // 17/11, 21 h 32
let carteAttenteSoir = carteAttente                                           // la demande du soir, « En attente »
var p30 = ExportProof()
p30.saw([carteAttenteSoir], now: n30, calendar: cal)
check(p30.alreadyPending && p30.pendingToday, "une demande d'aujourd'hui en cours, même avec un export prêt du matin")
check(!LeaveHint.title(existing: true, today: true).contains("Ta demande"), "bandeau : « une demande d'aujourd'hui », jamais « ta demande »")
check(NoticeText.of("zy-asked", existing: true, today: true, hour: nil)?.title.contains("Ta demande") == false, "notification A : jamais « ta demande » sur une simple date")
// Cas A : Zieuton a vu la demande du soir (prouvée). Le fichier prêt du matin entre dans la référence.
var r30 = ReadyProof(day: n30)
r30.read(pending: [carteAttenteSoir], ready: [carteJourPrete], now: n30, calendar: cal)
r30.read(pending: [carteAttenteSoir], ready: [carteJourPrete], now: n30.addingTimeInterval(3), calendar: cal)
check(r30.baseline == 1, "le fichier prêt du matin est compté dans la référence")
check(r30.verdict(pending: [carteAttenteSoir], ready: [carteJourPrete], login: false, offline: false, now: n30.addingTimeInterval(60), calendar: cal) == .pending,
      "demande du soir en attente + fichier du matin prêt : « pas encore », jamais « prêt »")
check(r30.verdict(pending: [], ready: [carteJourPrete], login: false, offline: false, now: n30.addingTimeInterval(600), calendar: cal) == .toCheck,
      "ligne du soir disparue, seul le fichier du matin reste : « vérifie la date », jamais « prêt »")
check(settle(&r30, [], [carteJourPrete, carteJourPrete], at: n30.addingTimeInterval(900)) == .ready,
      "un deuxième fichier prêt du même jour : c'est le nouveau, « prêt »")
// L'ancien fichier du matin expire ou est supprimé, puis le nouveau est prêt : il n'y en a qu'un, pas « plus qu'avant ».
check(r30.verdict(pending: [], ready: [carteJourPrete], login: false, offline: false, now: n30.addingTimeInterval(1200), calendar: cal) != .ready,
      "un seul fichier prêt du jour (sans savoir lequel) : jamais « prêt » automatique")
// Cas B : la demande « en cours » vue en retard. Le jour vient de sa ligne ; le fichier du matin reste dans la référence.
var r30b = ReadyProof(day: nil)
r30b.read(pending: [carteAttenteSoir], ready: [carteJourPrete], now: n30, calendar: cal)
r30b.read(pending: [carteAttenteSoir], ready: [carteJourPrete], now: n30.addingTimeInterval(3), calendar: cal)
check(r30b.baseline == 1, "demande vue en retard : le fichier du matin est aussi dans la référence")
check(r30b.verdict(pending: [carteAttenteSoir], ready: [carteJourPrete], login: false, offline: false, now: n30.addingTimeInterval(60), calendar: cal) == .pending,
      "demande vue en retard + fichier du matin prêt : jamais « prêt »")
check(GetBanner.of(waiting: true, proven: false, verdict: .pending) == .notYet && GetBanner.of(waiting: true, proven: false, verdict: .toCheck) == .checkDate,
      "bandeau : « pas encore » ou « vérifie la date », jamais « Touche Télécharger »")
// Le fichier prêt n'est jamais lu avant que la demande soit vue « En attente » : pas de référence, donc pas de « prêt ».
var r30c = ReadyProof(day: n30)
r30c.read(pending: [], ready: [carteJourPrete], now: n30, calendar: cal)
r30c.read(pending: [], ready: [carteJourPrete], now: n30.addingTimeInterval(3), calendar: cal)
check(r30c.baseline == nil, "sans ligne « En attente » du jour, aucune référence")
check(r30c.verdict(pending: [], ready: [carteJourPrete, carteJourPrete], login: false, offline: false, now: n30.addingTimeInterval(60), calendar: cal) == .toCheck,
      "sans référence, même deux fichiers du jour : « vérifie la date », jamais « prêt »")

// 31. Vidéo iPhone du 18 nov. (14 h 30) : textes tels que le lecteur les envoie pour la vraie liste.
// Trois fichiers prêts (« Expire le 22/11 », « 21/11 », « 21/11 ») et une demande « En attente » du 18/11.
let n18 = cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 14, minute: 30))!
func pret(_ exp: String) -> String { "expire le \(exp) · moins de 1 mo · vifrnt (instagram) followers et suivi(e)s exporter vers appareil · une fois · json expire le \(exp) · moins de 1 mo télécharger annuler" }
let attente18 = "en attente · demandée le 18/11/2026 · vifrnt (instagram) followers et suivi(e)s exporter vers appareil · une fois · json demandée le 18/11/2026 annuler"
let prets18 = [pret("22/11/2026"), pret("21/11/2026"), pret("21/11/2026")]
check(ReadyProof.expiry(pret("22/11/2026"), calendar: cal).map { cal.component(.day, from: $0) } == 22, "18 nov. : « Expire le 22/11/2026 » est lu")
check(ReadyProof.expiry(attente18, calendar: cal) == nil, "18 nov. : une demande en attente n'a pas de date d'expiration")
check(ReadyProof.readyFor(pret("22/11/2026"), day: n18, now: n18, calendar: cal), "18 nov. : expire le 22/11 = devenu prêt le 18/11 ou après : peut être le fichier du jour")
check(!ReadyProof.readyFor(pret("21/11/2026"), day: n18, now: n18, calendar: cal), "18 nov. : expire le 21/11 = prêt avant le 18/11 : ancien export, jamais le fichier du jour")
check(!ReadyProof.readyFor(pret("18/11/2026"), day: n18, now: n18, calendar: cal), "un fichier qui expire le jour même n'est jamais celui de la demande du jour")
// Demande vue en retard (cas de la vidéo) : le fichier du matin (expire le 22/11) entre dans la référence.
var r31 = ReadyProof(day: nil)
for t in [0.0, 2.5] { r31.read(pending: [attente18], ready: prets18, now: n18.addingTimeInterval(t), calendar: cal) }
check(r31.day.map { cal.isDate($0, inSameDayAs: n18) } == true, "18 nov. : jour lu sur la carte « Demandée le 18/11/2026 »")
check(r31.baseline == 1, "18 nov. : référence = 1 (le fichier du matin, expire le 22/11) ; les deux du 21/11 ne comptent pas")
check(r31.verdict(pending: [attente18], ready: prets18, login: false, offline: false, now: n18.addingTimeInterval(60), calendar: cal) == .pending,
      "18 nov. : demande en attente + trois fichiers prêts : « pas encore prêt », jamais « prêt »")
check(settle(&r31, [], [pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(600)) == .ready,
      "18 nov. : la demande quitte « En attente » et un 2e fichier « expire le 22/11 » arrive : prêt")
check(r31.verdict(pending: [], ready: prets18, login: false, offline: false, now: n18.addingTimeInterval(600), calendar: cal) == .toCheck,
      "18 nov. : la demande disparaît sans nouveau fichier : « vérifie », jamais « prêt »")
check(r31.verdict(pending: [attente18], ready: [pret("22/11/2026")] + prets18, login: false, offline: false, now: n18.addingTimeInterval(600), calendar: cal) == .pending,
      "un nouveau fichier arrive mais la demande est encore « En attente » : ce n'est pas le sien, « pas encore prêt »")
check(ReadyProof(day: nil).verdict(pending: [], ready: prets18, login: false, offline: false, now: n18, calendar: cal) == .toCheck,
      "jour inconnu + fichiers « Expire le » : « vérifie la date », jamais « prêt »")
// La demande en attente du 18/11, vue avant toute touche : demande d'aujourd'hui en cours, pas « Touche Créer une exportation ».
var p31 = ExportProof()
p31.saw([attente18], now: n18, calendar: cal)
check(p31.alreadyPending && p31.pendingToday, "18 nov. : la carte du 18/11 vue en revenant : demande d'aujourd'hui déjà en cours")
check(ExportProof.listIsCalm(screen: "home", rowsShown: false) && ExportProof.listIsCalm(screen: "", rowsShown: true),
      "18 nov. : sur la liste des exports, jamais « Oups, pas le bon bouton »")
check(!ExportProof.listIsCalm(screen: "summary:info", rowsShown: false), "ailleurs dans le parcours, l'alerte reste")
check(LeaveHint.showsButton(guarding: false, ready: false, badSettings: false, pageProblem: false, downloading: false, unsure: true),
      "18 nov. : preuve incertaine, liste visible : « Revenir dans Zieuton » est proposé")

// 32. Relecture ChatGPT (18 nov., 14 h 09) : identifier le fichier prêt sans se tromper.
// Si la correspondance n'est pas sûre : « à vérifier », sans notification « prêt » ni cercle sur Télécharger.
func base18(_ ready: [String] = prets18) -> ReadyProof {
    var r = ReadyProof(day: n18)
    for t in [0.0, 2.5] { r.read(pending: [attente18], ready: ready, now: n18.addingTimeInterval(t), calendar: cal) }
    return r
}
check(base18().baseline == 1 && base18().signature != nil, "référence fixée avec l'empreinte de la carte (compte, catégorie, format)")
check(ReadyProof.signature(of: attente18) == ReadyProof.signature(of: pret("22/11/2026")),
      "la carte « En attente » et la carte prête du même export ont la même empreinte (dates, statut, boutons, taille ignorés)")
check(ReadyProof.signature(of: "en attente · demandée le 18/11/2026 annuler") == nil, "carte sans compte ni catégorie : pas d'empreinte")
// a. Un autre export devient prêt AVANT le nôtre.
var r32a = base18()
check(settle(&r32a, [attente18], [pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(300)) == .pending,
      "a. un autre fichier arrive, notre demande est encore « En attente » : pas encore prêt")
check(settle(&r32a, [], [pret("22/11/2026"), pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(900)) == .toCheck,
      "a. puis la nôtre aussi : deux fichiers nouveaux, on ne sait pas lequel : à vérifier, jamais « prêt »")
// b. La carte « En attente » manque un instant dans la lecture.
var r32b = base18()
r32b.read(pending: [], ready: [pret("22/11/2026")] + prets18, now: n18.addingTimeInterval(300), calendar: cal)
r32b.read(pending: [attente18], ready: [pret("22/11/2026")] + prets18, now: n18.addingTimeInterval(300.7), calendar: cal)
r32b.read(pending: [], ready: [pret("22/11/2026")] + prets18, now: n18.addingTimeInterval(302.5), calendar: cal)
check(rv(r32b, [], [pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(302.5)) != .ready,
      "b. carte « En attente » absente d'une lecture puis revenue : jamais « prêt »")
check(rv(r32b, [attente18], [pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(303)) == .pending, "b. tant qu'elle revient : pas encore prêt")
// c. Un ancien fichier expire ou est supprimé.
var r32c = base18()
check(settle(&r32c, [], [pret("22/11/2026"), pret("21/11/2026")], at: n18.addingTimeInterval(900)) == .toCheck,
      "c. le fichier du matin supprimé, le nôtre prêt : autant qu'avant, à vérifier, jamais « prêt »")
var r32c2 = base18()
check(settle(&r32c2, [], [pret("22/11/2026"), pret("22/11/2026")], at: n18.addingTimeInterval(900)) == .ready,
      "c. les fichiers du 21/11 expirent (anciens, hors référence) et le nôtre arrive : prêt")
// d. Un autre compte ou une autre catégorie.
let autreCompte = pret("22/11/2026").replacingOccurrences(of: "vifrnt", with: "autrecompte")
let autreCategorie = pret("22/11/2026").replacingOccurrences(of: "followers et suivi(e)s", with: "publications")
check(base18([autreCompte] + prets18).baseline == 1, "d. le fichier prêt d'un autre compte n'entre pas dans la référence")
var r32d = base18()
check(settle(&r32d, [], [autreCompte] + prets18, at: n18.addingTimeInterval(900)) == .toCheck,
      "d. seul un fichier d'un autre compte arrive : il ne compte pas, à vérifier, jamais « prêt »")
var r32d2 = base18()
check(settle(&r32d2, [], [autreCategorie] + prets18, at: n18.addingTimeInterval(900)) == .toCheck,
      "d. seul un fichier d'une autre catégorie arrive : à vérifier, jamais « prêt »")
var r32d3 = base18()
check(settle(&r32d3, [], [autreCompte, pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(900)) == .ready,
      "d. un fichier d'un autre compte + le nôtre : seul le nôtre compte, prêt")
// e. Deux demandes « En attente » le même jour : on ne sait pas laquelle suivre, aucune référence.
var r32e = ReadyProof(day: n18)
let attente18b = attente18.replacingOccurrences(of: "vifrnt", with: "autrecompte")
for t in [0.0, 2.5] { r32e.read(pending: [attente18, attente18b], ready: prets18, now: n18.addingTimeInterval(t), calendar: cal) }
check(r32e.baseline == nil, "e. deux cartes « En attente » du jour : pas de référence")
check(settle(&r32e, [], [pret("22/11/2026"), pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(900)) == .toCheck,
      "e. puis des fichiers prêts : à vérifier, jamais « prêt »")
// f. Relecture ChatGPT (15 h 33) : référence enregistrée par le build 17 (sans empreinte). Elle n'est pas gardée (migration prudente).
var r32f = ReadyProof(day: n18, baseline: 1)
check(r32f.baseline == nil && r32f.signature == nil, "f. ancienne référence sans empreinte : oubliée")
check(settle(&r32f, [], [pret("22/11/2026"), pret("22/11/2026")], at: n18.addingTimeInterval(900)) == .toCheck,
      "f. la demande a déjà quitté « En attente » : on ne peut plus refaire la référence, à vérifier, jamais « prêt »")
var r32f2 = ReadyProof(day: n18, baseline: 1)
for t in [0.0, 2.5] { r32f2.read(pending: [attente18], ready: prets18, now: n18.addingTimeInterval(t), calendar: cal) }
check(r32f2.baseline == 1 && r32f2.signature != nil, "f. la carte « En attente » est encore là : référence refaite, avec empreinte")
check(settle(&r32f2, [], [pret("22/11/2026")] + prets18, at: n18.addingTimeInterval(900)) == .ready, "f. puis « prêt » comme d'habitude")
check(ReadyProof(day: n18, baseline: 0, signature: nil).verdict(pending: [], ready: [pret("22/11/2026")], login: false, offline: false, now: n18, calendar: cal) != .ready,
      "f. jamais « prêt » sans empreinte connue")
// g. Sans « prêt », le bandeau ne cible jamais Télécharger.
for v in [ReadyProof.Verdict.toCheck, .unknown, .pending] {
    check(GetBanner.of(waiting: true, proven: false, verdict: v) != .ready, "g. verdict \(v.rawValue) : jamais « Touche Télécharger »")
}

// 33. Relecture ChatGPT (18 nov., 14 h 09) : plus de boucle. Instagram fermé sans preuve mais avec un signe de demande :
// la page passe sur « Demande à vérifier ». Sans aucun signe, rien n'est noté.
check(LeaveHint.leftUnsure(requesting: true, finished: false, tapped: true, toCheck: false, todayShown: false, pendingSeen: false),
      "« Commencer » touché, pas de preuve : demande à vérifier")
check(LeaveHint.leftUnsure(requesting: true, finished: false, tapped: false, toCheck: true, todayShown: false, pendingSeen: false),
      "ligne à vérifier : demande à vérifier")
check(LeaveHint.leftUnsure(requesting: true, finished: false, tapped: false, toCheck: false, todayShown: false, pendingSeen: true),
      "demande « En attente » vue avant d'être reconnue (vidéo du 18 nov.) : demande à vérifier")
check(!LeaveHint.leftUnsure(requesting: true, finished: true, tapped: true, toCheck: false, todayShown: false, pendingSeen: false),
      "demande prouvée : rien de plus (la page a déjà reçu « requested »)")
check(!LeaveHint.leftUnsure(requesting: true, finished: false, tapped: false, toCheck: false, todayShown: false, pendingSeen: false),
      "Instagram fermé sans aucun signe de demande : rien n'est noté")
check(!LeaveHint.leftUnsure(requesting: false, finished: false, tapped: true, toCheck: true, todayShown: true, pendingSeen: true),
      "ouvert pour récupérer le fichier : jamais « à vérifier »")

// 34. Relecture ChatGPT (18 nov., 15 h 33) : l'empreinte garde les identifiants exacts (chiffres, « . », « _ »).
func carte(_ compte: String, _ statut: String) -> String { "\(statut) · \(compte) (instagram) followers et suivi(e)s exporter vers appareil · une fois · json \(statut) annuler" }
check(ReadyProof.signature(of: carte("compte1", "demandée le 18/11/2026")) != ReadyProof.signature(of: carte("compte2", "demandée le 18/11/2026")),
      "compte1 et compte2 : empreintes différentes")
check(ReadyProof.signature(of: carte("vic.frnt", "demandée le 18/11/2026")) != ReadyProof.signature(of: carte("vic_frnt", "demandée le 18/11/2026")),
      "vic.frnt et vic_frnt : empreintes différentes")
check(ReadyProof.signature(of: carte("compte1", "demandée le 18/11/2026")) == ReadyProof.signature(of: carte("compte1", "expire le 22/11/2026 · moins de 1 mo télécharger")),
      "même compte : la carte en attente et la carte prête ont la même empreinte")
check(ReadyProof.signature(of: carte("compte1", "x"))?.contains("compte1") == true, "le pseudo est gardé tel quel, chiffres compris")
var r34 = ReadyProof(day: n18)
let attente34 = carte("compte1", "en attente · demandée le 18/11/2026")
for t in [0.0, 2.5] { r34.read(pending: [attente34], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r34.baseline == 0, "compte1 suivi")
check(settle(&r34, [], [carte("compte2", "expire le 22/11/2026 · moins de 1 mo télécharger")], at: n18.addingTimeInterval(900)) == .unknown,
      "seul le fichier de compte2 arrive : il ne compte pas, jamais « prêt » pour compte1")
check(settle(&r34, [], [carte("compte2", "expire le 22/11/2026 · moins de 1 mo télécharger"), carte("compte1", "expire le 22/11/2026 · moins de 1 mo télécharger")],
             at: n18.addingTimeInterval(1200)) == .ready, "puis celui de compte1 : prêt")

// 35. Deux exports identiques (même compte, même catégorie, même format), demandés le même jour : impossible de les distinguer.
var r35 = ReadyProof(day: n18)
for t in [0.0, 2.5] { r35.read(pending: [attente18, attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r35.baseline == nil, "deux demandes identiques en attente : aucune référence")
check(settle(&r35, [attente18], [pret("22/11/2026")], at: n18.addingTimeInterval(300)) == .pending, "l'une est prête, l'autre en attente : pas encore prêt")
check(settle(&r35, [], [pret("22/11/2026"), pret("22/11/2026")], at: n18.addingTimeInterval(900)) == .toCheck,
      "les deux sont prêtes : on ne sait pas laquelle est la sienne, à vérifier, jamais « prêt »")
// Demande suivie seule, puis une 2e identique le même jour (par exemple refaite dans l'app Instagram).
var r35b = ReadyProof(day: n18)
for t in [0.0, 2.5] { r35b.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r35b.baseline == 0, "la première demande est suivie")
check(settle(&r35b, [attente18, attente18], [], at: n18.addingTimeInterval(120)) == .pending, "une 2e demande identique arrive : pas encore prêt")
check(settle(&r35b, [attente18], [pret("22/11/2026")], at: n18.addingTimeInterval(300)) == .pending,
      "un fichier prêt, une demande encore en attente : peut-être pas le sien, pas encore prêt")
check(settle(&r35b, [], [pret("22/11/2026"), pret("22/11/2026")], at: n18.addingTimeInterval(900)) == .toCheck,
      "deux fichiers identiques prêts : à vérifier, jamais « prêt »")

// 36. Relecture ChatGPT (18 nov., 15 h 44) : le scénario exact du faux « prêt ».
// 1. demande suivie seule (référence 0) ; 2-3. une 2e demande identique du même jour, les deux « En attente » ;
// 4. l'une devient prête ; 5. l'autre est annulée ou disparaît ; 6. une carte prête, zéro en attente.
var r36 = ReadyProof(day: n18)
for t in [0.0, 2.5] { r36.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r36.baseline == 0 && !r36.ambiguous, "36.1 demande suivie seule : référence 0, pas d'ambiguïté")
for t in [60.0, 62.5] { r36.read(pending: [attente18, attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r36.ambiguous, "36.3 deux cartes « En attente » indiscernables : ambiguïté notée")
check(settle(&r36, [attente18], [pret("22/11/2026")], at: n18.addingTimeInterval(300)) == .pending, "36.4 l'une prête, l'autre en attente : pas encore prêt")
check(settle(&r36, [], [pret("22/11/2026")], at: n18.addingTimeInterval(600)) == .toCheck,
      "36.6 l'autre annulée : une carte prête, zéro en attente, relue 2 s plus tard : à vérifier, jamais « prêt »")
check(settle(&r36, [], [pret("22/11/2026")], at: n18.addingTimeInterval(3600)) == .toCheck, "36.6 et toujours pas « prêt » une heure plus tard")
check(r36.ambiguous, "l'ambiguïté ne s'efface jamais toute seule")
// Fermeture puis réouverture de l'app : la coque recrée le suivi avec ce qu'elle a gardé (jour, référence, empreinte, ambiguïté).
var r36b = ReadyProof(day: r36.day, baseline: r36.baseline, signature: r36.signature, ambiguous: r36.ambiguous)
check(r36b.ambiguous && r36b.baseline == 0, "réouverture : ambiguïté et référence retrouvées")
check(settle(&r36b, [], [pret("22/11/2026")], at: n18.addingTimeInterval(7200)) == .toCheck, "réouverture : toujours jamais « prêt »")
// Sans l'ambiguïté (régression) : la même liste finale donnerait bien « prêt ».
var r36c = ReadyProof(day: n18)
for t in [0.0, 2.5] { r36c.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(settle(&r36c, [], [pret("22/11/2026")], at: n18.addingTimeInterval(600)) == .ready, "une seule demande vue : « prêt » reste possible")
// Deux cartes « En attente » de comptes différents ne sont pas ambiguës (empreintes différentes).
var r36d = ReadyProof(day: n18)
for t in [0.0, 2.5] { r36d.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
r36d.read(pending: [attente18, attente18.replacingOccurrences(of: "vifrnt", with: "compte2")], ready: [], now: n18.addingTimeInterval(60), calendar: cal)
check(!r36d.ambiguous, "une demande d'un autre compte n'est pas une ambiguïté")
check(settle(&r36d, [], [pret("22/11/2026")], at: n18.addingTimeInterval(600)) == .ready, "et le fichier du bon compte reste « prêt »")
// Ambiguïté vue avant même la référence (deux demandes identiques dès la première lecture).
var r36e = ReadyProof(day: n18)
r36e.read(pending: [attente18, attente18], ready: [], now: n18, calendar: cal)
check(r36e.ambiguous, "deux demandes identiques dès le début : ambiguïté notée")
for t in [60.0, 62.5] { r36e.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r36e.baseline == 0, "une seule reste : la référence se fixe")
check(settle(&r36e, [], [pret("22/11/2026")], at: n18.addingTimeInterval(600)) == .toCheck, "mais jamais « prêt » : on ne sait pas laquelle était la sienne")

// 37. Relecture ChatGPT (18 nov., 15 h 55) : une demande en attente d'un AUTRE compte ne bloque pas le compte suivi.
let attenteB = attente18.replacingOccurrences(of: "vifrnt", with: "compteb")
var r37 = ReadyProof(day: n18)
for t in [0.0, 2.5] { r37.read(pending: [attente18, attenteB], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r37.baseline == nil, "deux comptes en attente dès le début : on ne sait pas lequel suivre, pas de référence (prudent)")
var r37b = ReadyProof(day: n18)
for t in [0.0, 2.5] { r37b.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(r37b.baseline == 0, "37. le compte A est suivi")
check(settle(&r37b, [attente18, attenteB], [], at: n18.addingTimeInterval(60)) == .pending, "A et B en attente : A pas encore prêt")
check(settle(&r37b, [attenteB], [pret("22/11/2026")], at: n18.addingTimeInterval(600)) == .ready,
      "le fichier de A est prêt, B reste en attente : A est prêt (B ne le bloque plus)")
check(!r37b.ambiguous, "deux comptes différents : pas d'ambiguïté")
var r37c = ReadyProof(day: n18)
for t in [0.0, 2.5] { r37c.read(pending: [attente18], ready: [], now: n18.addingTimeInterval(t), calendar: cal) }
check(settle(&r37c, [attenteB], [pret("22/11/2026").replacingOccurrences(of: "vifrnt", with: "compteb")], at: n18.addingTimeInterval(600)) == .unknown,
      "seul le fichier de B arrive : jamais « prêt » pour A")
check(settle(&r37c, ["en attente · demandée le 18/11/2026 annuler"], [pret("22/11/2026")], at: n18.addingTimeInterval(900)) == .pending,
      "une carte en attente du jour sans empreinte lisible : prudence, on la compte, pas encore prêt")
// Plusieurs « Télécharger » : le bandeau donne la date « Expire le » de la bonne ligne, seulement si elle a été lue.
let d22 = cal.date(from: DateComponents(year: 2026, month: 11, day: 22))!
check(GetBanner.readyTip(expiry: d22, day: n18, calendar: cal) == "Sur la ligne « Expire le 22/11 » (ta demande du 18/11).", "date lue : « Expire le 22/11 »")
check(GetBanner.readyTip(expiry: d22, day: n18, calendar: cal).count <= 75 && GetBanner.readyTip(expiry: nil, day: n18, calendar: cal).count <= 75, "consigne courte")
check(!GetBanner.readyTip(expiry: nil, day: n18, calendar: cal).contains("Expire"), "date pas lue : consigne neutre, aucune date inventée")

// 38. Relecture ChatGPT (18 nov., 16 h 10) : demande le 18/11, fichier préparé plus tard, qui expire le 23/11.
// La date du bandeau est celle écrite sur la carte, jamais « jour de la demande + 4 ».
var r38 = ReadyProof(day: n18)
for t in [0.0, 2.5] { r38.read(pending: [attente18], ready: [pret("21/11/2026")], now: n18.addingTimeInterval(t), calendar: cal) }
check(r38.baseline == 0, "38. référence 0 (l'ancien export du 21/11 ne compte pas)")
let liste38 = [pret("23/11/2026"), pret("21/11/2026")]
let n19 = n18.addingTimeInterval(86400)
check(settle(&r38, [], liste38, at: n19) == .ready, "38. le fichier qui expire le 23/11 est bien celui de la demande du 18/11 : prêt")
let e38 = r38.identifiedExpiry(ready: liste38, now: n19, calendar: cal)
check(e38.map { GetBanner.dayText($0, calendar: cal) } == "23/11", "38. date lue sur la carte : 23/11")
check(GetBanner.readyTip(expiry: e38, day: r38.day, calendar: cal) == "Sur la ligne « Expire le 23/11 » (ta demande du 18/11).",
      "38. bandeau : « Expire le 23/11 », jamais « 22/11 » calculé")
// Un fichier du même jour déjà prêt (expire le 22/11) + le nouveau (expire le 23/11) : on ne sait pas lequel est nouveau.
var r38b = ReadyProof(day: n18)
for t in [0.0, 2.5] { r38b.read(pending: [attente18], ready: [pret("22/11/2026")], now: n18.addingTimeInterval(t), calendar: cal) }
let liste38b = [pret("23/11/2026"), pret("22/11/2026")]
check(settle(&r38b, [], liste38b, at: n19) == .ready, "38. un fichier de plus que la référence : prêt")
check(r38b.identifiedExpiry(ready: liste38b, now: n19, calendar: cal) == nil, "38. deux dates possibles (22/11 et 23/11) : aucune date affichée")
// Même date sur les deux : quelle que soit la ligne nouvelle, sa date est sûre.
var r38c = ReadyProof(day: n18)
for t in [0.0, 2.5] { r38c.read(pending: [attente18], ready: [pret("22/11/2026")], now: n18.addingTimeInterval(t), calendar: cal) }
check(r38c.identifiedExpiry(ready: [pret("22/11/2026"), pret("22/11/2026")], now: n18.addingTimeInterval(600), calendar: cal)
        .map { GetBanner.dayText($0, calendar: cal) } == "22/11", "38. deux fichiers du même jour à la même date : date sûre")
// Ambiguïté, empreinte inconnue ou ancien format sans « Expire le » : aucune date.
check(r36.identifiedExpiry(ready: [pret("22/11/2026")], now: n18.addingTimeInterval(600), calendar: cal) == nil, "38. demandes indiscernables : aucune date")
check(ReadyProof(day: n18, baseline: 0).identifiedExpiry(ready: [pret("22/11/2026")], now: n18, calendar: cal) == nil, "38. sans empreinte : aucune date")
check(r1.identifiedExpiry(ready: [pretJour, pretAncien], now: s(30), calendar: cal) == nil, "38. carte sans « Expire le » : aucune date")
print(failures == 0 ? "\nTout est vert." : "\n\(failures) test(s) en échec.")
exit(failures == 0 ? 0 : 1)
