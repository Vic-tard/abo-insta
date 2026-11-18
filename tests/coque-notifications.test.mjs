// FOU-126 : la coque lue comme du texte (pas besoin de Mac). Les notifications ne promettent jamais de surveiller,
// ne parlent jamais d'expiration, et gardent les textes décidés avec Victor. Le comportement est testé sur Mac
// (tests/ios/ExportProofTests.swift, npm run test:ios) puis sur iPhone avec le build 17.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const read = (f) => readFileSync(new URL(f, root), "utf8");
const web = read("ios/Zieuton/WebViewController.swift");
const app = read("ios/Zieuton/AppDelegate.swift");

// Les textes visibles : chaînes Swift hors commentaires (le script d'Instagram, en chaîne brute, est retiré).
function visibleStrings(src) {
  // Les mots ignorés par l'empreinte d'une carte (ReadyProof.noise) servent à comparer, ils ne sont jamais affichés.
  const noReader = src.replace(/static let readerJS = #"""[\s\S]*?"""#/, "").replace(/static let noise: Set<String> = \[[\s\S]*?\n\s*\]/, "");
  const lines = noReader.split("\n").filter((l) => !/^\s*\/\//.test(l)).map((l) => l.replace(/\s\/\/ .*$/, ""));
  // Les motifs de recherche (« (?:expire le|…)\\s+… », lecture de la date d'expiration écrite par Instagram) ne sont pas des textes.
  return (lines.join("\n").match(/"(?:[^"\\\n]|\\.)*"/g) || []).filter((t) => !t.startsWith('"(?:'));
}

test("aucune promesse de surveillance ni d'expiration dans les textes de la coque", () => {
  const banned = [/dès que je le vois/i, /je guette/i, /expire/i, /sûrement prêt/i, /plus long que d'habitude/i, /zieuton fermé/i];
  // Seule exception (relecture ChatGPT, 15 h 55) : la consigne « Sur la ligne « Expire le JJ/MM » » recopie la date écrite sur la carte
  // prête d'Instagram pour la reconnaître ; ce n'est pas une alerte d'expiration.
  const strings = [...visibleStrings(web), ...visibleStrings(app)].filter((s) => !s.startsWith('"Sur la ligne « Expire le '));
  for (const s of strings) for (const b of banned) assert.doesNotMatch(s, b, `texte interdit : ${s}`);
});

test("textes A, B et C décidés", () => {
  assert.match(web, /"C'est demandé ✓"/);
  assert.match(web, /"Instagram prépare ton fichier\. Tu pourras vérifier son état dans Zieuton\."/);
  assert.match(web, /"Une demande est déjà en cours ✓"/);
  assert.match(web, /"Des nouvelles de ton export \? 👀"/);
  assert.match(web, /"Ouvre Zieuton pour vérifier où en est Instagram\."/);
  assert.match(web, /"Ton fichier est prêt 🎉"/);
});

test("rappels à 30 min et 24 h, plus de rappel à 3 min ni de « dernier jour »", () => {
  assert.match(web, /\(remind30, 30 \* 60\), \(remind24, 24 \* 3600\)/);
  assert.doesNotMatch(web, /likelyAfter|3 \* 86400|2 \* 86400/);
  // Les anciens identifiants ne servent plus qu'à être retirés.
  const legacyUses = web.match(/"zy-(likely|last-day)"/g) || [];
  assert.equal(legacyUses.length, 2, "zy-likely et zy-last-day : seulement dans la liste à retirer");
});

test("l'autorisation n'est plus demandée au milieu d'Instagram", () => {
  const meta = web.slice(web.indexOf("final class MetaViewController"), web.indexOf("// EXPORT-PROOF:BEGIN"));
  assert.doesNotMatch(meta, /requestAuthorization/);
  const watcher = web.slice(web.indexOf("final class ExportWatcher"), web.indexOf("// MARK: Logo de l'écran d'ouverture"));
  // Deux appels seulement : la page le demande (« Je te préviens ? »), ou page ancienne sans cet écran (repli du build 15).
  assert.equal((watcher.match(/requestAuthorization/g) || []).length, 2);
  assert.match(watcher, /notDetermined, !self\.pageAsksPermission/);
});

test("app ouverte : les rappels ne s'affichent pas, A et C oui", () => {
  assert.match(app, /NoticePlan\.showsInForeground\(id\) \? \[\.banner, \.list, \.sound\] : \[\]/);
  assert.match(web, /static func showsInForeground\(_ id: String\) -> Bool \{ !reminderIds\.contains\(id\) \}/);
});

test("« prêt » vient de la preuve ReadyProof, plus du décompte des « Télécharger »", () => {
  assert.doesNotMatch(web, /[^.]downloadsBefore|guardBefore|downloadsSeen/);
  assert.match(web, /verdict == \.ready \{ guardIsReady\(\) \}/);
  assert.match(web, /if verdict == \.ready \{ self\.markReady\(\) \}/);
});

test("pont page ⇄ coque : version 10, zyeutoNotif, zyeutoWatch, actions notif", () => {
  assert.match(web, /window\.ZYEUTO_APP = \{ version: 10,/);
  assert.match(web, /window\.zyeutoNotif && window\.zyeutoNotif\(/);
  assert.match(web, /window\.zyeutoWatch && window\.zyeutoWatch\(/);
  for (const a of ["ask", "settings", "check"]) assert.match(web, new RegExp(`case "${a}":`));
  assert.match(web, /openNotificationSettingsURLString/);
});

test("multicompte : un message d'un autre compte n'annule pas les rappels (contrôle dans la coque)", () => {
  const branch = web.slice(web.indexOf('case "exportState":'), web.indexOf('case "notif":'));
  assert.match(branch, /ExportWatcher\.shared\.pageEndedWait\(acct: body\["acct"\] as\? String\)/);
  assert.doesNotMatch(branch, /\.clear\(\)/, "exportState ne doit jamais appeler clear() directement");
  assert.match(web, /guard NoticePlan\.endsWait\(requestAcct: store\.string\(forKey: Key\.acct\), sender: acct\) else \{ return \}/);
  assert.match(web, /ExportWatcher\.shared\.requested\(existing: existing, today: today, acct: acct\)/);
  assert.match(web, /let acct = body\["acct"\] as\? String/);
  // La règle elle-même, recopiée ici pour la faire tourner sans Mac (les tests Swift, cas 26, la vérifient aussi).
  const rule = web.match(/static func endsWait\(requestAcct: String\?, sender: String\?\) -> Bool \{\s*let owner = requestAcct \?\? "", from = sender \?\? ""\s*if owner\.isEmpty \{ return true \}\s*return from == owner\s*\}/);
  assert.ok(rule, "règle endsWait inchangée");
  const endsWait = (owner, from) => ((owner ?? "") === "" ? true : (from ?? "") === owner);
  assert.equal(endsWait("a1", "a2"), false);
  assert.equal(endsWait("a1", undefined), false);
  assert.equal(endsWait("a1", "a1"), true);
  assert.equal(endsWait(undefined, "a2"), true);
});

test("17 nov. : pour récupérer le fichier, ni « Touche Télécharger » ni cercle sans preuve « prêt »", () => {
  assert.match(web, /if !requesting \{ return getBanner == \.ready \? \["Télécharger", "Download"\] : \[\] \}/);
  assert.match(web, /if !requesting, !downloading \{ return getStep\(getBanner\) \}/);
  assert.match(web, /if !requesting \{ return getStep\(GetBanner\.of\(waiting: true, proven: false, verdict: getVerdict\)\) \}/);
  // Le seul « Touche Télécharger » sans réserve du mode « récupérer » est celui de la preuve.
  assert.match(web, /case \.ready:\s*return Step\(verb: "C'est prêt ! Touche", target: "Télécharger"/);
});

test("relecture ChatGPT : sans preuve, aucune consigne directe « Touche Télécharger »", () => {
  const block = web.slice(web.indexOf("private func getStep("), web.indexOf("private var currentStep: Step {"));
  const cases = block.split(/case \./).slice(1);
  for (const c of cases) {
    if (c.startsWith("ready:")) continue;
    assert.doesNotMatch(c, /target: "Télécharger"/, "seul le cas « prêt » dit « Touche Télécharger »");
    assert.doesNotMatch(c, /touche-le/i);
  }
  assert.match(block, /case \.unproven:[\s\S]*?verb: "Vérifie la date", target: "de ton export"/);
});

test("relecture ChatGPT (18 nov.) : une date d'aujourd'hui n'est jamais présentée comme « ta demande »", () => {
  const strings = visibleStrings(web);
  for (const s of strings) assert.doesNotMatch(s, /Ta demande d'aujourd'hui|Ta demande est bien enregistrée/, `texte trop affirmatif : ${s}`);
  assert.match(web, /if existing && today \{ return "Demande du jour en cours" \}/);
  assert.match(web, /title: "Une demande d'aujourd'hui est en cours ✓"/);
  // « prêt » exige EXACTEMENT une ligne prête de plus que la référence (qui compte les anciens fichiers du même jour), revue 2 s plus tard.
  assert.match(web, /if let baseline, signature != nil, !ambiguous, r == baseline \+ 1, readyStable \{ return \.ready \}/);
});

test("vidéo du 18 nov. : une demande en attente visible n'encourage jamais une nouvelle demande", () => {
  // Liste lue sans « Créer une exportation » visible : une demande déjà en cours est reconnue quand même.
  assert.match(web, /let homeSettled = \[createSince, listSince\]\.contains/);
  // Le temps de la reconnaître : pas de « Touche Créer une exportation », pas de cercle.
  assert.match(web, /if pendingSeen, requesting, !finished \{\s*return Step\(verb: "Un instant :", target: "une demande est déjà là"/);
  assert.match(web, /if pendingSeen \{ return \[\] \}/);
  // Sur la liste, jamais « Oups, pas le bon bouton ».
  assert.match(web, /if ExportProof\.listIsCalm\(screen: screenKey, rowsShown: .*?\) \{ return \}\s*warn\("Oups, pas le bon bouton !"/);
});

test("vidéo du 18 nov. : ligne d'aujourd'hui sans preuve : texte rassurant, confirmation à la main, jamais « C'est demandé »", () => {
  assert.match(web, /if todayPendingShown, Date\(\)\.timeIntervalSince\(sent\) > 6 \{\s*return Step\(verb: "Demande du jour trouvée :", target: "ne refais rien"/);
  const alert = web.slice(web.indexOf("private func askConfirmRequest()"), web.indexOf("private func warnDuplicate()"));
  assert.match(alert, /self\.manualConfirm = true\s*self\.existingRequest = true\s*self\.existingToday = true/);
  assert.match(web, /if !existingRequest \|\| manualConfirm \{ badSettings = ExportProof\.problem\(lastSummary\) \}/);
  assert.match(web, /unsure: unsureShown\)/);
});

test("vidéo du 18 nov. : une carte prête dit « Expire le », jamais prise pour une demande en attente", () => {
  assert.match(web, /var DATED = \/\^\(demandée le\|demandé le\|requested on\|expire le\|expires on\|expires\)\\b\//);
  assert.match(web, /if \(!ready && EXPIRES\.test\(low\(lines\[i\]\)\)\) continue;/);
  // La demande encore « En attente » n'est jamais prête, même si un autre fichier vient d'arriver.
  assert.match(web, /if p > 0 \{ return \.pending \}[\s\S]{0,700}?if let baseline, signature != nil, !ambiguous, r == baseline \+ 1, readyStable \{ return \.ready \}/);
});

test("18 nov. (Victor) : bandeau court, compris sans tout lire", () => {
  // Chaque consigne des étapes de demande et de récupération tient en une phrase courte.
  const zone = web.slice(web.indexOf("if pendingSeen, requesting, !finished {"), web.indexOf("if !requesting, !downloading { return getStep(getBanner) }"))
    + web.slice(web.indexOf("private func getStep("), web.indexOf("private var currentStep: Step {"));
  const tips = [...zone.matchAll(/tip: "((?:[^"\\]|\\.)*)"/g)].map((m) => m[1]);
  assert.ok(tips.length >= 8);
  for (const t of tips) assert.ok(t.length <= 75, `consigne trop longue (${t.length}) : ${t}`);
  assert.match(web, /static let tip = "Instagram prépare ton fichier\. Tu peux revenir dans Zieuton\."/);
});

test("relecture ChatGPT (18 nov., 14 h 09) : le fichier prêt n'est reconnu que si la correspondance est sûre", () => {
  // Référence fixée seulement avec UNE seule carte « En attente » du jour, qui a une empreinte (compte, catégorie, format).
  assert.match(web, /guard mine\.count == 1, let sig = Self\.signature\(of: mine\[0\]\) else \{/);
  // Un fichier ne compte que s'il a la même empreinte que la demande suivie.
  assert.match(web, /return Self\.signature\(of: row\) == signature/);
  // Relecture ChatGPT (15 h 33) : identifiants exacts (chiffres, « . », « _ » gardés), jamais « prêt » sans empreinte,
  // et une référence sans empreinte (build 17) est oubliée.
  assert.doesNotMatch(web, /CharacterSet\.letters\.inverted/);
  assert.match(web, /subtracting\(CharacterSet\(charactersIn: "\._"\)\)/);
  assert.match(web, /self\.baseline = signature == nil \? nil : baseline/);
  // « prêt » doit être revu au moins 2 s plus tard, sinon il retombe.
  assert.match(web, /if now\.timeIntervalSince\(at\) >= Self\.stableFor \{ readyStable = true \}/);
  assert.match(web, /readySeenAt = nil\s*readyStable = false/);
  // L'empreinte est gardée avec la référence (l'app peut être fermée pendant l'attente).
  assert.match(web, /static let signature = "zy\.export\.signature"/);
  assert.match(web, /if let sig = proof\.signature \{ store\.set\(sig, forKey: Key\.signature\) \}/);
  // Sans « prêt », jamais de notification C : markReady n'est appelé que sur un verdict « prêt ».
  assert.match(web, /if verdict == \.ready \{ self\.markReady\(\) \} else \{ self\.report\(verdict\) \}/);
});

test("relecture ChatGPT (18 nov., 14 h 09) : Instagram fermé sans preuve, la page passe sur « Demande à vérifier »", () => {
  // Seulement à la vraie fermeture d'Instagram (pas quand une fenêtre passe par-dessus).
  assert.match(web, /if isBeingDismissed, LeaveHint\.leftUnsure\(requesting: requesting, finished: finished, tapped: sentAt != nil, toCheck: toCheck,\s*todayShown: todayPendingShown, pendingSeen: pendingSeen\) \{\s*onLeftUnsure\?\(todayPendingShown \|\| proof\.pendingToday\)/);
  assert.match(web, /meta\.onLeftUnsure = \{ \[weak self\] today in\s*self\?\.webView\.evaluateJavaScript\("window\.zyeutoMeta && window\.zyeutoMeta\('unsure', \{ today: \\\(today\) \}\); true"\)/);
  // « à vérifier » ne lance ni le guet ni les notifications : seul « requested » appelle ExportWatcher.requested.
  const unsure = web.slice(web.indexOf("meta.onLeftUnsure ="), web.indexOf("meta.onFile ="));
  assert.doesNotMatch(unsure, /ExportWatcher/);
});

test("relecture ChatGPT (18 nov., 15 h 44) : deux demandes indiscernables, jamais « prêt », même après réouverture", () => {
  assert.match(web, /if let baseline, signature != nil, !ambiguous, r == baseline \+ 1, readyStable \{ return \.ready \}/);
  assert.match(web, /static let ambiguous = "zy\.export\.ambiguous"/);
  assert.match(web, /ambiguous: store\.bool\(forKey: Key\.ambiguous\)/);
  assert.match(web, /if proof\.ambiguous \{ store\.set\(true, forKey: Key\.ambiguous\) \}/);
  assert.match(web, /proof\.ambiguous != before\.ambiguous \{ saveProof\(\) \}/);
  // Effacée avec le reste quand la demande se termine ou est refaite.
  assert.match(web, /static var all: \[String\] \{ \[[^\]]*\bambiguous\b[^\]]*\] \+ legacy \}/);
});

test("relecture ChatGPT (18 nov., 15 h 55) : cercle sur la seule carte possible, autre compte, ligne à vérifier", () => {
  // « Télécharger » n'est entouré que s'il n'y en a qu'un dans toute la liste (testé aussi sur page : tests/lecteur/cercle-telecharger).
  assert.match(web, /if \(inner\(every\)\.length !== 1\) return null;/);
  // Une demande en attente d'un autre compte ne compte pas ; une carte sans empreinte lisible compte toujours.
  assert.match(web, /guard let signature, let sig = Self\.signature\(of: row\) else \{ return true \}\s*return sig == signature/);
  // Le bandeau « prêt » donne la date « Expire le » de la bonne ligne, dans les deux cas (récupération et guet).
  assert.equal((web.match(/tip: GetBanner\.readyTip\(ExportWatcher\.shared\.requestDay\)/g) || []).length, 2);
  assert.doesNotMatch(web, /tip: "Juste en dessous\."/);
});
