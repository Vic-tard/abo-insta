// Tests de la preuve de demande d'export (FOU-121) : une demande n'est confirmée que par une ligne « En attente » de plus.
// Compilé avec le bloc EXPORT-PROOF de WebViewController.swift par scripts/test-export-proof.sh.
import Foundation

var failures = 0
func check(_ ok: Bool, _ name: String, line: Int = #line) {
    if ok { print("ok - \(name)") } else { failures += 1; print("ÉCHEC (ligne \(line)) - \(name)") }
}

// 1. Parcours normal : aucune demande avant, une ligne après.
var p = ExportProof()
p.saw(0)
check(!p.alreadyPending, "liste vide au départ : pas de demande en cours")
check(!p.confirms(1), "pas encore au résumé : rien n'est confirmé, même avec une ligne")
p.freeze()
check(!p.confirms(0), "résumé atteint, retour sur l'accueil sans nouvelle ligne : pas confirmé")
check(p.confirms(1), "une ligne « En attente » de plus : confirmé")
check(!p.confirms(nil), "liste pas lue : jamais confirmé")

// 2. Retour en arrière depuis le résumé final (bug C1) : la liste ne change pas, rien n'est confirmé.
var back = ExportProof()
back.saw(0); back.freeze()
check(!back.confirms(0), "retour en arrière depuis le résumé : pas de fausse réussite")

// 3. Une ancienne demande déjà en cours.
var old = ExportProof()
old.saw(1)
check(old.alreadyPending, "une ligne « En attente » avant de commencer : demande déjà en cours")
old.freeze()
check(!old.alreadyPending, "une fois au résumé, on ne parle plus de demande déjà en cours")
check(!old.confirms(1), "l'ancienne ligne seule ne confirme pas la nouvelle demande")
check(old.confirms(2), "l'ancienne + une nouvelle : confirmé")

// 4. Liste qui s'affiche en plusieurs fois : on garde le plus grand nombre vu.
var slow = ExportProof()
slow.saw(0); slow.saw(1); slow.saw(0)
slow.freeze()
check(!slow.confirms(1), "liste lente : l'ancienne ligne, vue un instant, reste la référence")

// 5. La référence est figée au résumé : la nouvelle ligne ne devient jamais la référence.
var frozen = ExportProof()
frozen.saw(0); frozen.freeze(); frozen.saw(1)
check(frozen.before == 0, "après le résumé, une nouvelle lecture ne change pas la référence")
check(frozen.confirms(1), "et la nouvelle ligne confirme bien la demande")

// 6. Liste jamais vue (on est arrivé directement sur le résumé) : impossible de confirmer, on proposera de vérifier.
var never = ExportProof()
never.freeze()
check(!never.frozen, "sans liste de départ, rien n'est figé")
check(!never.confirms(3), "sans liste de départ : jamais confirmé")

// 7. Recommencer efface tout.
var again = ExportProof()
again.saw(2); again.freeze(); again.reset()
check(again.before == nil && !again.frozen, "reset : tout est effacé")

// 8. Demande partie avec un mauvais réglage.
check(ExportProof.problem("summary:period")?.title == "avec « Année dernière »", "« Année dernière » signalé")
check(ExportProof.problem("summary:format") != nil, "HTML signalé")
check(ExportProof.problem("summary:info") != nil, "toutes les informations signalé")
check(ExportProof.problem("summary:start") == nil, "bons réglages : rien à signaler")
check(ExportProof.problem("") == nil, "résumé jamais lu : rien à signaler (pas d'invention)")

print(failures == 0 ? "\nTout est vert." : "\n\(failures) test(s) en échec.")
exit(failures == 0 ? 0 : 1)
