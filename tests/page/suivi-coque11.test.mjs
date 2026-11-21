// Sécurité du suivi (21 nov., PR B, coque 11 = build 22). La page :
// - termine le suivi seulement avec une raison (exportEnded : import réel ou demande retirée), le compte et l'heure de la demande ;
// - demande une reprise (exportResume) quand elle garde une demande prouvée que la coque ne suit plus, une seule fois ;
// - dit « Rappel programmé » seulement si la coque a vraiment un rappel enregistré pour CETTE demande.
// Une demande gardée par la page n'est jamais une preuve : aucune reprise ne mène à « prêt » ni à l'écran A.
// Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

const accts = [{ id: "a1", slot: 1, h: [], n: 0 }, { id: "a2", slot: 2, h: [], n: 0 }];
const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
async function open(prefs, version = 11) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(([p, v]) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: v, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, [prefs, version]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => { window.zyeutoNotif({ status: "authorized" }); renderAll(); renderGuided(); });
  page.errors = errors;
  return page;
}
const of = (page, type) => page.evaluate((t) => window.__sent.filter((m) => m.type === t), type);
const info = (page, i) => page.evaluate((x) => window.zyeutoWatchInfo(x), i);
const gf = (page) => page.evaluate(() => document.getElementById("gf").innerText);

test("coque 11 : plus aucun exportState (ni au démarrage, ni en démo)", async () => {
  for (const prefs of [{}, { requestedAt: ago(10) }, { accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) }]) {
    const page = await open(prefs);
    await page.evaluate(() => { enterDemo(); renderWeekly(); leaveDemo(); renderWeekly(); });
    assert.deepEqual(await of(page, "exportState"), []);
    assert.deepEqual(await of(page, "exportEnded"), []);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test("coque 11 : fin par « Tout effacer » / « Refaire » → exportEnded cleared, avec compte et heure de la demande", async () => {
  const req = ago(10);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req });
  await page.evaluate(() => { delete prefs.requestedAt; delete prefs.requestAcct; savePrefs(); renderWeekly(); renderWeekly(); });
  const e = await of(page, "exportEnded");
  assert.equal(e.length, 1);
  assert.deepEqual(e[0], { type: "exportEnded", reason: "cleared", acct: "a1", requestedAt: req });
  await page.close();
});

test("coque 11 : fin par import réel → exportEnded imported avec la date d'import", async () => {
  const req = ago(10);
  const page = await open({ requestedAt: req });
  await page.evaluate(() => { prefs.lastImportAt = new Date().toISOString(); state.snapshots.push({ takenAt: new Date().toISOString(), count: 1 }); renderWeekly(); });
  const e = await of(page, "exportEnded");
  assert.equal(e.length, 1);
  assert.equal(e[0].reason, "imported");
  assert.equal(e[0].requestedAt, req);
  assert.ok(Date.parse(e[0].importedAt) > Date.parse(req));
  await page.close();
});

test("coque 11 : demande d'un autre compte → jamais de fin ni de reprise depuis le compte affiché", async () => {
  const page = await open({ accts, acctCur: "a2", requestAcct: "a1", requestedAt: ago(10) });
  await info(page, { waiting: false, ready: false, reminders: 0 });
  await page.evaluate(() => renderWeekly());
  assert.deepEqual(await of(page, "exportEnded"), []);
  assert.deepEqual(await of(page, "exportResume"), []);
  await page.close();
});

test("demande déjà perdue par la coque : une seule reprise, sans preuve, et la page reste sur « se prépare »", async () => {
  const req = ago(40);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req, requestExisting: true, requestToday: true });
  await info(page, { waiting: false, ready: false, reminders: 0 });
  await info(page, { waiting: false, ready: false, reminders: 0 });
  const r = await of(page, "exportResume");
  assert.equal(r.length, 1, "une seule reprise par demande");
  assert.deepEqual(r[0], { type: "exportResume", acct: "a1", requestedAt: req, existing: true, today: true, proven: true });
  // Rien n'est inventé : pas d'écran A, pas de « prêt », pas de « Rappel programmé » tant que la coque n'a pas de rappel.
  assert.equal(await page.evaluate(() => document.getElementById("asked").hidden), true);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare 👀");
  assert.equal(await page.evaluate(() => exportSeenReady()), false);
  assert.doesNotMatch(await gf(page), /Rappel programmé/);
  await page.close();
});

for (const [name, prefs, w] of [
  ["coque qui suit déjà", { requestedAt: ago(10) }, { waiting: true, ready: false, reminders: 1 }],
  ["fichier déjà vu prêt par la coque", { requestedAt: ago(10) }, { waiting: false, ready: true, reminders: 0 }],
  ["demande « à vérifier » (jamais prouvée)", { requestedAt: ago(10), requestUnsure: true }, { waiting: false, ready: false, reminders: 0 }],
  ["demande de plus de 4 jours", { requestedAt: ago(4 * 1440 + 30) }, { waiting: false, ready: false, reminders: 0 }],
  ["aucune demande", {}, { waiting: false, ready: false, reminders: 0 }],
  ["fichier déjà vu prêt par la page", { requestedAt: ago(10), readyAt: ago(2) }, { waiting: false, ready: false, reminders: 0 }],
]) {
  test(`pas de reprise : ${name}`, async () => {
    const page = await open(prefs);
    await info(page, w);
    assert.deepEqual(await of(page, "exportResume"), []);
    await page.close();
  });
}

test("pas de reprise pendant la démo ; après la démo, oui", async () => {
  const page = await open({ requestedAt: ago(10) });
  await page.evaluate(() => enterDemo());
  await info(page, { waiting: false, ready: false, reminders: 0 });
  assert.deepEqual(await of(page, "exportResume"), []);
  await page.evaluate(() => leaveDemo());
  assert.ok((await of(page, "watch")).length >= 1, "la page redemande l'état en sortant de la démo");
  await info(page, { waiting: false, ready: false, reminders: 0 });
  assert.equal((await of(page, "exportResume")).length, 1);
  await page.close();
});

test("« Rappel programmé » seulement avec un rappel enregistré pour cette demande", async () => {
  const req = ago(10);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req });
  assert.match(await gf(page), /Notifications autorisées/);
  await info(page, { waiting: true, ready: false, reminders: 0, acct: "a1", requestedAt: req });
  assert.match(await gf(page), /Notifications autorisées/, "aucun rappel enregistré");
  await info(page, { waiting: true, ready: false, reminders: 1, acct: "a2", requestedAt: req });
  assert.doesNotMatch(await gf(page), /Rappel programmé/, "rappel d'un autre compte");
  await info(page, { waiting: true, ready: false, reminders: 1, acct: "a1", requestedAt: ago(3000) });
  assert.doesNotMatch(await gf(page), /Rappel programmé/, "rappel d'une autre demande");
  await info(page, { waiting: true, ready: false, reminders: 2, acct: "a1", requestedAt: req });
  const txt = await gf(page);
  assert.match(txt, /Rappel programmé/);
  assert.match(txt, /Un rappel ne veut pas dire que ton fichier est prêt/);
  assert.doesNotMatch(txt, /Rappel activé/);
  await page.close();
});

test("coque 10 (build 21) : aucun message nouveau, « Notifications autorisées »", async () => {
  const page = await open({ requestedAt: ago(10) }, 10);
  await info(page, { waiting: false, ready: false, reminders: 2 });
  await page.evaluate(() => { leaveDemo(); renderWeekly(); });
  for (const t of ["exportEnded", "exportResume", "watch"]) assert.deepEqual(await of(page, t), [], t);
  assert.match(await gf(page), /Notifications autorisées/);
  assert.doesNotMatch(await gf(page), /Rappel programmé/);
  await page.close();
});
