// Tests de la lecture de l'export Instagram et de la comparaison des imports (js/zieuton-core.js).
// Lancer : npm test   (ou : node --test tests/)
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { loadCore, plain, fixture, names, followersJson, followingJson, jsonFile, makeZip, DIR } from "./helpers.mjs";

const read = (p) => readFileSync(fixture(p), "utf8");
const JAN = new Date("2026-01-10T12:00:00"), FEB = new Date("2026-02-10T12:00:00"), MAR = new Date("2026-03-10T12:00:00");

// Importe un export comme le fait l'app : lecture des fichiers, puis enregistrement.
async function importFiles(core, files) {
  const ex = await core.readExport(files);
  return core.recordSnapshot(ex.followers, ex.following, ex.date.toISOString(), ex.source);
}
const zipOf = (followers, { following, date, store } = {}) => makeZip([
  { name: DIR + "followers_1.json", text: followersJson(followers) },
  ...(following ? [{ name: DIR + "following.json", text: followingJson(following) }] : []),
], { date, store });

// ---------- Petit compte ----------
test("petit compte : lit followers_1.json (ancien et nouveau format) et following.json", async () => {
  const core = loadCore();
  const ex = await core.readExport([
    jsonFile(read("petit-compte/followers_1.json"), "followers_1.json", JAN),
    jsonFile(read("petit-compte/following.json"), "following.json", JAN),
  ]);
  assert.deepStrictEqual(Object.keys(ex.followers).sort(), [
    "camille.essai", "chloe.demo", "hugo_exemple", "ines_exemple", "jules_demo", "lea.martin_test",
    "lou.test", "manon.fictive", "nathan.fictif", "sacha.essai", "theo_exemple", "zoe.demo",
  ]);
  assert.equal(ex.followers["lea.martin_test"], 1704067200, "date d'abonnement gardée");
  assert.equal(Object.keys(ex.following).length, 6);
  assert.equal(ex.source, "followers_1.json + following.json");

  const r = await core.recordSnapshot(ex.followers, ex.following, ex.date.toISOString(), ex.source);
  assert.equal(r.status, "first");
  assert.equal(r.count, 12);
  assert.equal(core.state.snapshots.length, 1);
  assert.equal(core.state.events.length, 0, "aucun départ ni arrivée au premier import");
  assert.equal(Object.keys(core.state.following).length, 6);
});

test("petit compte : le même export en .zip donne le même résultat (compressé ou non)", async () => {
  for (const store of [false, true]) {
    const core = loadCore();
    const zip = makeZip([
      { name: DIR + "followers_1.json", text: read("petit-compte/followers_1.json") },
      { name: DIR + "following.json", text: read("petit-compte/following.json") },
      { name: "personal_information/personal_information.json", text: "{}" },
    ], { date: JAN, store });
    const ex = await core.readExport([zip]);
    assert.equal(Object.keys(ex.followers).length, 12);
    assert.equal(Object.keys(ex.following).length, 6);
    assert.equal(ex.date.getTime(), JAN.getTime(), "la date de l'export vient du .zip");
  }
});

test("petit compte : 2e import → départs et arrivées", async () => {
  const core = loadCore();
  await importFiles(core, [zipOf(names("ami", 0, 30), { date: JAN })]);
  // Départs : ami000000 et ami000001. Arrivées : 3 nouveaux.
  const r = await importFiles(core, [zipOf([...names("ami", 2, 30), ...names("nouveau", 0, 3)], { date: FEB })]);
  assert.equal(r.status, "ok");
  assert.deepStrictEqual(plain(r.unfollows), ["ami000000", "ami000001"]);
  assert.deepStrictEqual(plain(r.follows), ["nouveau000000", "nouveau000001", "nouveau000002"]);
  const snap = core.state.snapshots[1];
  assert.equal(snap.id, 2);
  assert.equal(snap.unfollows, 2);
  assert.equal(snap.follows, 3);
  assert.equal(core.state.events.filter((e) => e.kind === "unfollow").length, 2);
  assert.equal(core.state.events.filter((e) => e.kind === "follow").length, 3);
  assert.equal(core.state.events[0].since, JAN.toISOString());
});

// ---------- Gros compte ----------
test("50 000 abonnés : lecture du .zip et comparaison justes et rapides", async () => {
  const core = loadCore();
  const t = Date.now();
  await importFiles(core, [zipOf(names("fan", 0, 50000), { following: names("suivi", 0, 800), date: JAN })]);
  // 1 000 départs, 1 500 arrivées.
  const r = await importFiles(core, [zipOf([...names("fan", 1000, 50000), ...names("neuf", 0, 1500)], { date: FEB })]);
  const ms = Date.now() - t;
  assert.equal(r.status, "ok");
  assert.equal(r.count, 50500);
  assert.equal(r.unfollows.length, 1000);
  assert.equal(r.follows.length, 1500);
  assert.equal(Object.keys(core.state.followers).length, 50500);
  assert.ok(ms < 15000, `trop lent : ${ms} ms`);
});

// ---------- Export partiel ----------
test("export partiel : refusé, rien n'est enregistré", async () => {
  const core = loadCore();
  await importFiles(core, [zipOf(names("ami", 0, 100), { date: JAN })]);
  const before = plain(core.state);
  // Un export « programmé » ne contient que les nouveaux abonnés : ici 30 au lieu de 100.
  await assert.rejects(importFiles(core, [zipOf(names("ami", 0, 30), { date: FEB })]), /export partiel/);
  assert.deepStrictEqual(plain(core.state), before);
});

test("export partiel : une vraie baisse modérée (moins de la moitié partie) est acceptée", async () => {
  const core = loadCore();
  await importFiles(core, [zipOf(names("ami", 0, 100), { date: JAN })]);
  const r = await importFiles(core, [zipOf(names("ami", 0, 60), { date: FEB })]);
  assert.equal(r.unfollows.length, 40);
});

// ---------- Autre compte Instagram ----------
test("export d'un autre compte : refusé dans l'app, avec la proposition d'ajouter le compte", async () => {
  const core = loadCore();
  core.lock(true);
  const victor = names("victor_ami", 0, 300);
  await importFiles(core, [zipOf(victor, { date: JAN })]);
  core.remember(victor);
  const before = plain(core.state);
  const err = await importFiles(core, [zipOf(names("matheo_ami", 0, 300), { date: FEB })]).catch((e) => e);
  assert.match(err.message, /autre compte Instagram/);
  assert.deepStrictEqual(plain(err.otherAccount), { add: true });
  assert.deepStrictEqual(plain(core.state), before, "rien n'est enregistré");
});

test("export d'un compte déjà suivi sur le téléphone : refusé, avec « Passer sur ce compte »", async () => {
  const core = loadCore();
  core.lock(true);
  const victor = names("victor_ami", 0, 300), matheo = names("matheo_ami", 0, 300);
  core.addAccount("a2", 2);
  core.remember(matheo, "a2");
  await importFiles(core, [zipOf(victor, { date: JAN })]);
  core.remember(victor);
  const err = await importFiles(core, [zipOf(matheo, { date: FEB })]).catch((e) => e);
  assert.deepStrictEqual(plain(err.otherAccount), { known: "a2" });
});

test("même compte avec du mouvement normal (10 % renouvelé) : accepté", async () => {
  const core = loadCore();
  core.lock(true);
  const jan = names("ami", 0, 1000);
  await importFiles(core, [zipOf(jan, { date: JAN })]);
  core.remember(jan);
  const r = await importFiles(core, [zipOf([...names("ami", 100, 1000), ...names("nouveau", 0, 100)], { date: FEB })]);
  assert.equal(r.status, "ok");
});

test("sur le site (hors app), pas de verrou de compte : l'export d'un autre compte passe", async () => {
  const core = loadCore();
  const a = names("victor_ami", 0, 300);
  await importFiles(core, [zipOf(a, { date: JAN })]);
  core.remember(a);
  const r = await importFiles(core, [zipOf(names("matheo_ami", 0, 300), { date: FEB })]);
  assert.equal(r.status, "ok");
});

test("empreinte de compte : même liste = 1, listes sans rapport = 0", () => {
  const core = loadCore();
  const a = core.acctPrint(names("a", 0, 2000)), b = core.acctPrint(names("b", 0, 2000));
  assert.equal(a.length, 512);
  assert.equal(core.acctLikeness(a, a), 1);
  assert.equal(core.acctLikeness(a, b), 0);
});

// ---------- Ordre des exports ----------
test("exports dans le désordre : un export plus ancien que le dernier import est refusé", async () => {
  const core = loadCore();
  await importFiles(core, [zipOf(names("ami", 0, 50), { date: MAR })]);
  const before = plain(core.state);
  await assert.rejects(importFiles(core, [zipOf(names("ami", 0, 48), { date: FEB })]), /Importe tes exports dans l'ordre/);
  assert.deepStrictEqual(plain(core.state), before);
});

test("exports dans l'ordre (janvier, février, mars) : 3 imports, comparaisons enchaînées", async () => {
  const core = loadCore();
  await importFiles(core, [zipOf(names("ami", 0, 50), { date: JAN })]);
  await importFiles(core, [zipOf(names("ami", 1, 50), { date: FEB })]);
  const r = await importFiles(core, [zipOf(names("ami", 2, 51), { date: MAR })]);
  assert.deepStrictEqual(plain(r.unfollows), ["ami000001"]);
  assert.deepStrictEqual(plain(r.follows), ["ami000050"]);
  assert.deepStrictEqual(plain(core.state.snapshots.map((s) => s.id)), [1, 2, 3]);
});

// ---------- Doublon ----------
test("même export importé deux fois : reconnu, aucun nouvel import ni faux départ", async () => {
  const core = loadCore();
  const list = names("ami", 0, 40);
  await importFiles(core, [zipOf(list, { date: JAN })]);
  const r = await importFiles(core, [zipOf(list, { date: JAN })]);
  assert.equal(r.status, "same");
  assert.equal(core.state.snapshots.length, 1);
  assert.equal(core.state.events.length, 0);
  // Même liste dans un autre ordre, un mois plus tard : toujours « rien de neuf ».
  const r2 = await importFiles(core, [zipOf(list.slice().reverse(), { date: FEB })]);
  assert.equal(r2.status, "same");
  assert.equal(core.state.snapshots.length, 1);
});

// ---------- Fichiers invalides ----------
test("fichier non JSON : message clair", async () => {
  const core = loadCore();
  await assert.rejects(core.readExport([jsonFile(read("pas-du-json.txt"), "pas-du-json.txt")]), /n'est pas un fichier JSON valide/);
  await assert.rejects(core.readExport([jsonFile("{ abonnés: [", "followers_1.json")]), /n'est pas un fichier JSON valide/);
});

test("export au format HTML (seul ou dans un .zip) : demande de refaire en JSON", async () => {
  const core = loadCore();
  const html = read("export-html/followers_1.html");
  await assert.rejects(core.readExport([jsonFile(html, "followers_1.html")]), /format HTML/);
  await assert.rejects(core.readExport([makeZip([{ name: DIR + "followers_1.html", text: html }])]), /format HTML/);
});

test("JSON sans liste d'abonnés, liste vide ou following.json seul : refusés", async () => {
  const core = loadCore();
  await assert.rejects(core.readExport([jsonFile('{"profile": {}}', "autre.json")]), /Aucune liste d'abonnés/);
  await assert.rejects(core.readExport([jsonFile("[]", "followers_1.json")]), /aucun abonné/);
  await assert.rejects(core.readExport([jsonFile(followingJson(["a", "b"]), "following.json")]), /comptes que TU suis/);
});

test(".zip sans liste d'abonnés ou abîmé : refusé", async () => {
  const core = loadCore();
  await assert.rejects(core.readExport([makeZip([{ name: "messages/inbox.json", text: "{}" }])]), /Aucune liste d'abonnés dans ce \.zip/);
  await assert.rejects(core.readExport([new File([Buffer.from("PK\u0003\u0004 pas vraiment un zip")], "casse.zip")]), /n'est pas un \.zip valide/);
});

// ---------- Petites fonctions ----------
test("nettoyage des pseudos", () => {
  const core = loadCore();
  assert.equal(core.cleanName("  @Lou.Test "), "lou.test");
  assert.equal(core.cleanName(""), null);
  assert.equal(core.cleanName(42), null);
  assert.equal(core.nameFromHref("https://www.instagram.com/_u/jules_demo"), "jules_demo");
  assert.equal(core.nameFromHref("pas une url"), null);
  assert.equal(core.listKind([]), "followers");
  assert.equal(core.listKind({ relationships_following: [] }), "following");
  assert.equal(core.listKind({}), null);
});

// ---------- Exports d'exemple pour le testeur Apple (FOU-32) ----------
test("exports d'exemple du testeur Apple : 1er import, puis 4 départs et 3 arrivées", async () => {
  const { GONE, NEW } = await import("../scripts/make-review-exports.mjs");
  const zipFile = (n) => new File([readFileSync(new URL("../exemple/" + n, import.meta.url))], n);
  const core = loadCore();
  core.lock(true); // comme dans l'app
  await importFiles(core, [zipFile("zieuton-exemple-1.zip")]);
  await importFiles(core, [zipFile("zieuton-exemple-2.zip")]);
  const kinds = (k) => plain(core.state.events).filter((e) => e.kind === k).map((e) => e.u).sort();
  assert.deepEqual(kinds("unfollow"), [...GONE].sort());
  assert.deepEqual(kinds("follow"), [...NEW].sort());
  assert.equal(core.state.snapshots.length, 2);
});
