// Tests de l'enregistrement des données (FOU-39 : numéro de version et migration ; FOU-40 : gros comptes).
// Lancer : npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { loadCore, plain, names, followersJson, followingJson, makeZip, DIR } from "./helpers.mjs";

// Un état tel que la page l'enregistre aujourd'hui (avant le numéro de version) : deux imports, un départ, une arrivée.
const OLD_STATE = {
  snapshots: [
    { id: 1, takenAt: "2026-01-10T12:00:00.000Z", source: "followers_1.json", count: 3, hash: "aaa", unfollows: 0, follows: 0 },
    { id: 2, takenAt: "2026-02-10T12:00:00.000Z", source: "followers_1.json + following.json", count: 3, hash: "bbb", unfollows: 1, follows: 1 },
  ],
  events: [
    { u: "lea.test", kind: "unfollow", at: "2026-02-10T12:00:00.000Z", since: "2026-01-10T12:00:00.000Z", ts: 1704067200 },
    { u: "zoe.test", kind: "follow", at: "2026-02-10T12:00:00.000Z", since: "2026-01-10T12:00:00.000Z" },
  ],
  followers: { "hugo.test": 1704067260, "ines.test": null, "zoe.test": 1707000000 },
  following: { "hugo.test": 1704067260 },
  followingAt: "2026-02-10T12:00:00.000Z",
};
const OLD_PREFS = { requestedAt: "2026-02-01T10:00:00.000Z", acctCur: "a1", accts: [{ id: "a1", slot: 1, h: [1, 2], n: 3 }], plus: { tier: "avie" } };

// ---------- FOU-39 : migration ----------
test("anciennes données (sans numéro) : passent à la version actuelle sans rien perdre", () => {
  const core = loadCore();
  const raw = structuredClone(OLD_STATE);
  const m = core.migrateState(raw);
  assert.equal(m.ok, true);
  assert.equal(m.keep, false);
  assert.equal(m.data.v, core.STATE_V);
  const { v, ...rest } = plain(m.data);
  assert.deepStrictEqual(rest, OLD_STATE, "historique identique, seul le numéro est ajouté");
  assert.deepStrictEqual(raw, OLD_STATE, "l'original n'est pas modifié");
  assert.equal(core.errors.length, 0);

  const p = core.migratePrefs(structuredClone(OLD_PREFS));
  assert.equal(p.ok, true);
  assert.equal(p.data.v, core.PREFS_V);
  const { v: pv, ...prest } = plain(p.data);
  assert.deepStrictEqual(prest, OLD_PREFS);
});

test("données déjà à jour : rendues telles quelles", () => {
  const core = loadCore();
  const cur = { ...structuredClone(OLD_STATE), v: core.STATE_V };
  const m = core.migrateState(cur);
  assert.equal(m.ok, true);
  assert.deepStrictEqual(plain(m.data), plain(cur));
});

test("rien d'enregistré : pas d'erreur, rien à garder", () => {
  const core = loadCore();
  for (const raw of [null, undefined]) {
    const m = core.migrateState(raw);
    assert.equal(m.ok, false);
    assert.equal(m.keep, false);
  }
  assert.equal(core.errors.length, 0);
});

test("données inconnues : gardées telles quelles, erreur notée", () => {
  const core = loadCore();
  const cases = ["bonjour", 42, [1, 2, 3], { snapshots: "pas une liste", events: [], followers: {} }, { autre: true }, { ...OLD_STATE, v: "deux" }];
  for (const raw of cases) {
    const before = JSON.stringify(raw);
    const m = core.migrateState(raw);
    assert.equal(m.ok, false, JSON.stringify(raw));
    assert.equal(m.keep, true, "à copier à part avant tout enregistrement");
    assert.equal(m.data, raw, "les données sont rendues telles quelles");
    assert.equal(JSON.stringify(raw), before, "et jamais modifiées");
  }
  assert.equal(core.errors.length, cases.length);
  assert.ok(core.errors.every((e) => e.where === "migrate-state"));

  const p = core.migratePrefs(["pas", "des", "réglages"]);
  assert.equal(p.ok, false);
  assert.equal(p.keep, true);
});

test("données d'une version future : lues si possible, jamais réécrites à l'ancienne, copie à garder", () => {
  const core = loadCore();
  const future = { ...structuredClone(OLD_STATE), v: core.STATE_V + 5, nouveauChamp: { x: 1 } };
  const before = JSON.stringify(future);
  const m = core.migrateState(future);
  assert.equal(m.keep, true, "la page en garde une copie à part");
  assert.equal(m.ok, true, "la forme est connue : l'historique reste visible");
  assert.equal(m.data, future, "rendues telles quelles");
  assert.equal(JSON.stringify(future), before, "rien n'est écrasé ni retiré");
  assert.equal(m.data.v, core.STATE_V + 5, "le numéro n'est pas baissé");
  assert.match(core.errors[0].message, /plus récente/);

  const weird = { v: core.STATE_V + 1, historique: "autre forme" };
  const w = core.migrateState(weird);
  assert.equal(w.ok, false);
  assert.equal(w.keep, true);
  assert.equal(w.data, weird);
});

// ---------- FOU-40 : copie de secours dans localStorage ----------
test("petit compte : copie complète dans localStorage, relue à l'identique", () => {
  const core = loadCore();
  const s = { ...structuredClone(OLD_STATE), v: core.STATE_V };
  const txt = core.lsCopyText(s);
  assert.deepStrictEqual(JSON.parse(txt), plain(s));
});

test("compte moyen : copie légère (dernier import + listes) ; IndexedDB reste la référence", () => {
  const core = loadCore();
  const s = { ...structuredClone(OLD_STATE), v: core.STATE_V };
  const full = JSON.stringify(s).length;
  const lite = JSON.parse(core.lsCopyText(s, full - 1));
  assert.equal(lite.lite, true);
  assert.deepStrictEqual(lite.snapshots, [OLD_STATE.snapshots[1]]);
  assert.deepStrictEqual(lite.followers, OLD_STATE.followers);
  assert.deepStrictEqual(lite.events, []);
  // Au chargement, la copie complète d'IndexedDB gagne toujours sur la copie légère.
  assert.equal(core.pickState(s, lite), s);
  const one = { ...s, snapshots: s.snapshots.slice(1) };
  assert.equal(core.pickState(one, lite), one, "à égalité d'imports, la complète");
  // IndexedDB vidée : la copie légère dépanne (sans son repère « lite »), et c'est noté.
  const back = core.pickState(null, lite);
  assert.equal(back.lite, undefined);
  assert.deepStrictEqual(back.followers, OLD_STATE.followers);
  assert.equal(core.errors.at(-1).where, "start-lite");
});

test("trop gros même en copie légère : rien dans localStorage", () => {
  const core = loadCore();
  const s = { ...structuredClone(OLD_STATE), v: core.STATE_V };
  assert.equal(core.lsCopyText(s, 50), null);
});

// Faux localStorage de Safari : environ 5 Mo (en caractères), erreur QuotaExceededError au-delà.
function fakeLocalStorage(limit = 5 * 1024 * 1024) {
  const m = new Map();
  const used = () => [...m].reduce((n, [k, v]) => n + k.length + v.length, 0);
  return {
    getItem: (k) => (m.has(k) ? m.get(k) : null),
    setItem(k, v) {
      const prev = m.has(k) ? k.length + m.get(k).length : 0;
      if (used() - prev + k.length + v.length > limit) { const e = new Error("The quota has been exceeded."); e.name = "QuotaExceededError"; throw e; }
      m.set(k, String(v));
    },
    removeItem: (k) => m.delete(k),
    size: used,
  };
}

test("compte de 200 000 abonnés : s'importe, s'enregistre et se recharge sans perte", async () => {
  const core = loadCore();
  const N = 200000;
  const jan = names("compte_", 0, N);
  // Un mois plus tard : 1 500 départs, 2 000 arrivées.
  const feb = [...jan.slice(1500), ...names("nouveau_", 0, 2000)];
  const zip = (list, date) => makeZip([
    { name: DIR + "followers_1.json", text: followersJson(list) },
    { name: DIR + "following.json", text: followingJson(list.slice(0, 7500)) },
  ], { date });

  for (const [list, date] of [[jan, new Date("2026-01-10T12:00:00")], [feb, new Date("2026-02-10T12:00:00")]]) {
    const ex = await core.readExport([zip(list, date)]);
    assert.equal(Object.keys(ex.followers).length, list.length);
    await core.recordSnapshot(ex.followers, ex.following, ex.date.toISOString(), ex.source);
  }
  const s = core.state;
  s.v = core.STATE_V;
  assert.equal(s.snapshots.length, 2);
  assert.equal(Object.keys(s.followers).length, N + 500);
  assert.equal(s.events.filter((e) => e.kind === "unfollow").length, 1500);
  assert.equal(s.events.filter((e) => e.kind === "follow").length, 2000);

  // Enregistrement comme save() : IndexedDB (copie structurée) + localStorage (déjà occupé par les réglages).
  const idb = new Map();
  idb.set("state", structuredClone(s));
  const ls = fakeLocalStorage();
  ls.setItem("abo-prefs", JSON.stringify({ ...OLD_PREFS, v: core.PREFS_V }));
  const txt = core.lsCopyText(s);
  assert.equal(txt, null, "historique trop gros pour localStorage : on n'essaie même pas");
  assert.ok(JSON.stringify(s).length > core.LS_MAX);
  assert.ok(ls.size() < 5000, "les réglages gardent leur place");
  ls.setItem("abo-prefs", JSON.stringify({ ...OLD_PREFS, v: core.PREFS_V, demande: "encore possible" }));

  // Avant FOU-40 : la copie complète faisait échouer localStorage (en silence).
  assert.throws(() => ls.setItem("abo-state", JSON.stringify(s)), { name: "QuotaExceededError" });

  // Rechargement : migration puis choix de la copie.
  const fromIdb = core.migrateState(idb.get("state"));
  assert.equal(fromIdb.ok, true);
  const lsRaw = ls.getItem("abo-state");
  const fromLs = lsRaw ? core.migrateState(JSON.parse(lsRaw)).data : null;
  const back = core.pickState(fromIdb.data, fromLs);
  assert.deepStrictEqual(plain(back), plain(s), "rien de perdu");
  assert.equal(core.errors.length, 0);

  // Et l'import suivant se compare bien à cet historique rechargé.
  core.state = back;
  const mar = [...feb.slice(10)];
  const ex = await core.readExport([zip(mar, new Date("2026-03-10T12:00:00"))]);
  const r = await core.recordSnapshot(ex.followers, ex.following, ex.date.toISOString(), ex.source);
  assert.equal(r.status, "ok");
  assert.equal(r.unfollows.length, 10);
  assert.equal(r.follows.length, 0);
});
