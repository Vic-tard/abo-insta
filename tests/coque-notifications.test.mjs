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
  const noReader = src.replace(/static let readerJS = #"""[\s\S]*?"""#/, "");
  const lines = noReader.split("\n").filter((l) => !/^\s*\/\//.test(l)).map((l) => l.replace(/\s\/\/ .*$/, ""));
  return lines.join("\n").match(/"(?:[^"\\\n]|\\.)*"/g) || [];
}

test("aucune promesse de surveillance ni d'expiration dans les textes de la coque", () => {
  const banned = [/dès que je le vois/i, /je guette/i, /expire/i, /sûrement prêt/i, /plus long que d'habitude/i, /zieuton fermé/i];
  const strings = [...visibleStrings(web), ...visibleStrings(app)];
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
