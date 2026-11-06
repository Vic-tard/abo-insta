// Tests des règles de sécurité des mises à jour de la page (FOU-28).
// Compilé avec le bloc PAGE-GUARD de WebViewController.swift par scripts/test-page-guard.sh.
import Foundation

var failures = 0
func check(_ ok: Bool, _ name: String, line: Int = #line) {
    if ok { print("ok - \(name)") } else { failures += 1; print("ÉCHEC (ligne \(line)) - \(name)") }
}

let bundled = PageGuard.Page(source: .bundled, build: "2026-11-01-1000")
let lastGood = PageGuard.Page(source: .lastGood, build: "2026-11-03-1000")
let downloaded = PageGuard.Page(source: .downloaded, build: "2026-11-05-1000")
let all = [bundled, lastGood, downloaded]
let noBad: Set<String> = []

// 1. Comportement d'avant : la plus récente gagne.
check(PageGuard.choose(all, bad: noBad, channel: "stable", config: nil) == downloaded,
      "sans channel.json, la page téléchargée la plus récente est affichée")
check(PageGuard.choose(all, bad: noBad, channel: "stable", config: .init(stable: nil, emergency: false)) == downloaded,
      "channel.json sans version stable : pas de limite")

// 2. Page cassée : retour à la dernière bonne, puis à celle rangée dans l'app.
check(PageGuard.choose(all, bad: [downloaded.build], channel: "stable", config: nil) == lastGood,
      "page téléchargée mauvaise → dernière page qui a démarré")
check(PageGuard.choose(all, bad: [downloaded.build, lastGood.build], channel: "stable", config: nil) == bundled,
      "téléchargée et dernière bonne mauvaises → page rangée dans l'app")
check(PageGuard.choose(all, bad: [bundled.build, lastGood.build, downloaded.build], channel: "stable", config: nil) == bundled,
      "la page rangée dans l'app reste toujours possible")
check(PageGuard.choose([bundled], bad: noBad, channel: "test", config: nil) == bundled,
      "téléphone neuf : la page rangée dans l'app")
check(PageGuard.choose([bundled, PageGuard.Page(source: .downloaded, build: bundled.build)],
                       bad: noBad, channel: "stable", config: nil)?.source == .bundled,
      "à version égale, on préfère la page rangée dans l'app")

// 3. Mauvaise version : jamais retéléchargée.
check(!PageGuard.shouldKeep(downloaded: "2026-11-05-1000", current: bundled.build, bad: ["2026-11-05-1000"],
                            channel: "stable", config: nil),
      "une version notée mauvaise n'est pas retéléchargée")
check(PageGuard.shouldKeep(downloaded: "2026-11-06-1000", current: bundled.build, bad: ["2026-11-05-1000"],
                           channel: "stable", config: nil),
      "la version suivante (corrigée) est bien téléchargée")
check(!PageGuard.shouldKeep(downloaded: "2026-11-02-1000", current: lastGood.build, bad: noBad,
                            channel: "stable", config: nil),
      "une version plus ancienne n'est pas téléchargée")

// 4. Deux plantages de suite.
check(!PageGuard.tooManyFailedStarts(0) && !PageGuard.tooManyFailedStarts(1), "un seul démarrage raté : on réessaie")
check(PageGuard.tooManyFailedStarts(2), "deux démarrages ratés de suite : page mauvaise")
check(PageGuard.startTimeout >= 5 && PageGuard.startTimeout <= 15, "délai de démarrage de quelques secondes")

// 5. Canaux.
let pinned = PageGuard.Channel(stable: lastGood.build, emergency: false)
check(PageGuard.choose(all, bad: noBad, channel: "stable", config: pinned) == lastGood,
      "canal normal : pas au-delà de la version stable")
check(PageGuard.choose(all, bad: noBad, channel: "test", config: pinned) == downloaded,
      "canal test : la dernière version en ligne")
check(!PageGuard.shouldKeep(downloaded: downloaded.build, current: lastGood.build, bad: noBad, channel: "stable", config: pinned),
      "canal normal : une version pas encore validée n'est pas téléchargée")
check(PageGuard.shouldKeep(downloaded: downloaded.build, current: lastGood.build, bad: noBad, channel: "test", config: pinned),
      "canal test : une version pas encore validée est téléchargée")
check(PageGuard.shouldKeep(downloaded: lastGood.build, current: bundled.build, bad: noBad, channel: "stable", config: pinned),
      "canal normal : la version stable elle-même est téléchargée")
check(PageGuard.choose(all, bad: noBad, channel: "stable",
                       config: .init(stable: "2026-11-02-0900", emergency: false)) == bundled,
      "version stable redescendue : retour à une page autorisée")
check(PageGuard.choose([bundled], bad: noBad, channel: "stable",
                       config: .init(stable: "2026-10-01-0000", emergency: false)) == bundled,
      "la page rangée dans l'app passe même si elle est plus récente que la version stable")

// 6. Interrupteur d'urgence.
let emergency = PageGuard.Channel(stable: downloaded.build, emergency: true)
check(PageGuard.choose(all, bad: noBad, channel: "stable", config: emergency) == bundled, "urgence : canal normal → page rangée dans l'app")
check(PageGuard.choose(all, bad: noBad, channel: "test", config: emergency) == bundled, "urgence : canal test → page rangée dans l'app")
check(!PageGuard.shouldKeep(downloaded: "2026-12-01-1000", current: bundled.build, bad: noBad, channel: "test", config: emergency),
      "urgence : rien n'est téléchargé")

// 7. Lecture de channel.json.
func parse(_ text: String) -> PageGuard.Channel? { PageGuard.parseChannel(Data(text.utf8)) }
check(parse(#"{"stable":"2026-11-06-1300","urgence":false}"#) == .init(stable: "2026-11-06-1300", emergency: false), "channel.json normal")
check(parse(#"{"stable":"2026-11-06-1300","urgence":true}"#)?.emergency == true, "urgence activée")
check(parse(#"{"stable":"2026-11-06-1300"}"#)?.emergency == false, "urgence absente = éteinte")
check(parse(#"{"stable":null,"urgence":false}"#) == .init(stable: nil, emergency: false), "stable vide = pas de limite")
check(parse(#"{"stable":"6 novembre","urgence":false}"#) == nil, "version mal écrite → fichier ignoré")
check(parse(#"{"stable":"2026-11-06-1300","urgence":"true"}"#) == nil, "urgence en texte → fichier ignoré")
check(parse(#"{"stable":"2026-11-06-1300","urgence":1}"#) == nil, "urgence en nombre → fichier ignoré")
check(parse("<html>404</html>") == nil, "page d'erreur → fichier ignoré")
check(parse("[]") == nil, "pas un objet → fichier ignoré")
if let url = URL(string: "file://" + FileManager.default.currentDirectoryPath + "/channel.json"),
   let data = try? Data(contentsOf: url) {
    check(PageGuard.parseChannel(data) != nil, "le channel.json du dépôt est lisible par l'app")
}

// 8. Liste des mauvaises versions.
let many = (0..<30).map { String(format: "2026-11-01-%04d", $0) }
check(PageGuard.addBad("x", to: many).count == 20, "on garde les 20 dernières mauvaises versions")
check(PageGuard.addBad("a", to: ["a", "b"]) == ["b", "a"], "pas de doublon")
check(PageGuard.isBuild("2026-11-06-1300") && !PageGuard.isBuild("2026-11-06"), "format AAAA-MM-JJ-HHMM")

print(failures == 0 ? "\nTout est vert." : "\n\(failures) test(s) en échec.")
exit(failures == 0 ? 0 : 1)
