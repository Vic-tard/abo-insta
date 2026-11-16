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
check(!LoginHelp.isRealLoadFailure(domain: NSURLErrorDomain, code: NSURLErrorCancelled), "navigation annulée : pas une panne")
check(!LoginHelp.isRealLoadFailure(domain: "WebKitErrorDomain", code: 102), "page devenue téléchargement : pas une panne")
check(LoginHelp.isRealLoadFailure(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet), "pas d'Internet : vraie panne")
check(LoginHelp.isRealLoadFailure(domain: NSURLErrorDomain, code: NSURLErrorTimedOut), "délai dépassé : vraie panne")
let t0 = Date(timeIntervalSince1970: 1_000_000)
check(!LoginHelp.downloadStuck(since: t0, now: t0.addingTimeInterval(30)), "téléchargement de 30 s : normal")
check(LoginHelp.downloadStuck(since: t0, now: t0.addingTimeInterval(91)), "téléchargement de plus de 90 s : bloqué")

print(failures == 0 ? "\nTout est vert." : "\n\(failures) test(s) en échec.")
exit(failures == 0 ? 0 : 1)
