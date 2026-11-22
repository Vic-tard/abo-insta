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
// Refonte FOU-131 : rappels, e-mail et « Refaire la demande » sont dans « Plus d'infos » : on l'ouvre avant de lire l'écran.
const openInfo = async (page) => { if (await page.isVisible("#gw-more") && !(await page.isVisible("#gw-info"))) await page.click("#gw-more"); };
const gf = async (page) => { await openInfo(page); return page.evaluate(() => document.getElementById("gf").innerText); };

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

// Relecture ChatGPT (21 nov.), point 1 : « cleared » seulement après une action confirmée, jamais sur une disparition des réglages.
test("réglages perdus ou modifiés pendant une demande : aucune fin envoyée, le suivi natif reste intact", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await page.evaluate(() => { delete prefs.requestedAt; delete prefs.requestAcct; savePrefs(); renderAll(); renderWeekly(); });
  await page.evaluate(() => { prefs.requestedAt = new Date(Date.now() - 3 * 864e5).toISOString(); renderWeekly(); delete prefs.requestedAt; renderWeekly(); });
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.close();
});

test("« Refaire la demande » puis « Non, j'attends » : rien n'est terminé", async () => {
  const page = await open({ requestedAt: ago(10) });
  await page.evaluate(() => confirmRedo(() => {}));
  await page.click("#gf-redo-no");
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.close();
});

test("« Refaire quand même » confirmé : exportEnded cleared, avec compte et heure de la demande", async () => {
  const req = ago(10);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req });
  await page.evaluate(() => confirmRedo(() => {}));
  await page.click("#gf-redo-yes");
  assert.deepEqual(await of(page, "exportEnded"), [{ type: "exportEnded", reason: "cleared", acct: "a1", requestedAt: req }]);
  await page.close();
});

test("« Oui, tout effacer » confirmé : exportEnded cleared", async () => {
  const req = ago(10);
  const page = await open({ requestedAt: req });
  await page.evaluate(() => document.getElementById("reset-yes").click());
  const e = await of(page, "exportEnded");
  assert.equal(e.length, 1);
  assert.equal(e[0].reason, "cleared");
  assert.equal(e[0].requestedAt, req);
  await page.close();
});

// Réouverture de l'app : la page relit ses réglages enregistrés, avec le même historique, et la coque redonne son état.
async function reopen(page) {
  await page.evaluate(() => { prefs = JSON.parse(localStorage.getItem("abo-prefs")); watchInfo = null; resumeSentFor = null; window.__sent.length = 0; renderAll(); });
}
// Point 2 : seul un export d'Instagram daté après la demande la termine. On importe comme l'app (commit), avec un faux export.
// exact : heure UTC du .zip (champ 0x5455) ; sans elle, l'heure du .zip n'a pas de fuseau (build 23).
async function importExport(page, { minsAgo, dated = true, manual = false, exact = false }) {
  await page.evaluate(async ([m, d, man, ex]) => {
    const followers = {};
    for (let i = 0; i < 60; i++) followers["ami" + i] = 1700000000 + i;
    pending = { followers, following: null, date: new Date(Date.now() - m * 60000), dated: d, exact: d && ex, source: d ? "export.zip" : "followers_1.json" };
    const takenAt = man ? new Date(Date.now() - 60000).toISOString() : pending.date.toISOString();
    await commit(takenAt);
  }, [minsAgo, dated, manual, exact]);
}

test("nouvelle demande en cours + import d'un ancien export : suivi conservé, demande toujours visible, même après réouverture", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(30) });
  await importExport(page, { minsAgo: 3 * 1440 });
  assert.deepEqual(await of(page, "exportEnded"), [], "la coque garde son suivi");
  assert.equal(await page.evaluate(() => reqPending()), true, "la page garde la demande en attente");
  // Avec un historique, la demande gardée se voit discrètement sur la carte de l'accueil (build 23 : plus « se prépare »).
  assert.equal(await page.textContent("#weekly-title"), "Demande toujours suivie");
  // Fermeture et réouverture de l'app : réglages relus depuis le stockage (l'historique reste celui du téléphone).
  // Rien ne change, et la page ne demande pas de reprise (la coque suit toujours).
  await reopen(page);
  const again = page;
  const saved = await page.evaluate(() => prefs);
  assert.equal(await again.evaluate(() => reqPending()), true);
  assert.equal(await again.textContent("#weekly-title"), "Demande toujours suivie");
  await info(again, { waiting: true, ready: false, reminders: 1, acct: "a1", requestedAt: saved.requestedAt });
  assert.deepEqual(await of(again, "exportEnded"), []);
  assert.deepEqual(await of(again, "exportResume"), []);
  assert.equal(await again.evaluate(() => reminderSet()), true, "la coque suit toujours cette demande, avec un rappel");
  await page.close();
});

test("coque 10 (build 21) : un ancien export ne fait pas non plus disparaître la demande", async () => {
  const page = await open({ requestedAt: ago(30) }, 10);
  await page.evaluate(() => { window.__sent.length = 0; });
  await importExport(page, { minsAgo: 3 * 1440 });
  await page.evaluate(() => renderWeekly());
  assert.equal(await page.evaluate(() => reqPending()), true);
  assert.deepEqual(await page.evaluate(() => window.__sent.filter((m) => m.type === "exportState" && m.pending === false)), []);
  await page.close();
});

test("téléchargement puis import du bon export (heure exacte + vu prêt) : fin normale (page et coque), même après réouverture", async () => {
  const page = await open({ requestedAt: ago(30), readyAt: ago(12) });
  await importExport(page, { minsAgo: 10, exact: true });
  assert.equal((await of(page, "exportEnded")).length, 1);
  assert.equal(await page.evaluate(() => reqPending()), false);
  assert.equal(await page.textContent("#weekly-title"), "Mettre à jour");
  await reopen(page);
  assert.equal(await page.evaluate(() => reqPending()), false);
  assert.deepEqual(await of(page, "exportResume"), []);
  await page.close();
});

test("import du bon export (heure exacte après la demande, vu prêt, bon compte) : suivi terminé", async () => {
  const req = ago(30);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req, readyAt: ago(12) });
  await importExport(page, { minsAgo: 10, exact: true });
  const e = await of(page, "exportEnded");
  assert.equal(e.length, 1);
  assert.equal(e[0].reason, "imported");
  assert.equal(e[0].acct, "a1");
  assert.equal(e[0].requestedAt, req);
  assert.ok(Date.parse(e[0].importedAt) > Date.parse(req), "date de l'export, pas heure de l'import");
  assert.ok(Date.parse(e[0].importedAt) < Date.now() - 5 * 60000);
  await page.close();
});

for (const [name, opt] of [
  ["un .json seul (date du fichier sur le téléphone, pas d'Instagram)", { minsAgo: 10, dated: false }],
  ["date changée à la main", { minsAgo: 10, manual: true }],
  ["export daté pile avant la demande", { minsAgo: 31 }],
]) {
  test(`origine ou date incertaine (${name}) : la demande suivie n'est pas supprimée`, async () => {
    const page = await open({ requestedAt: ago(30) });
    await importExport(page, opt);
    assert.deepEqual(await of(page, "exportEnded"), []);
    assert.equal(await page.evaluate(() => reqPending()), true, "page d'accord avec la coque : demande gardée");
    await page.close();
  });
}

test("multicompte : bon export importé dans l'autre compte → la demande du compte 1 reste suivie", async () => {
  const page = await open({ accts, acctCur: "a2", requestAcct: "a1", requestedAt: ago(30), readyAt: ago(12) });
  await importExport(page, { minsAgo: 10, exact: true });
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.close();
});

test("coque 10 (page plus ancienne côté coque) : aucun exportEnded, même pour le bon export", async () => {
  const page = await open({ requestedAt: ago(30), readyAt: ago(12) }, 10);
  await importExport(page, { minsAgo: 10, exact: true });
  assert.deepEqual(await of(page, "exportEnded"), []);
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
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
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
