// Build 23 (vidéo du 21 nov., 16 h 20) : le bon export importé (1 140 abonnés) laissait « Ton export se prépare » à l'accueil.
// L'heure d'un .zip n'a pas de fuseau horaire : elle ne prouve rien. Après un import qui ne prouve pas la demande, Zieuton demande :
// « Est-ce bien le fichier de ta demande Instagram en cours ? » (Oui / Non / Je ne sais pas). Seul « Oui » termine la demande.
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
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(() => { window.zyeutoNotif({ status: "authorized" }); renderAll(); renderGuided(); });
  page.errors = errors;
  return page;
}
const of = (page, type) => page.evaluate((t) => window.__sent.filter((m) => m.type === t), type);
async function reopen(page) {
  await page.evaluate(() => { document.getElementById("ia")?.remove(); prefs = JSON.parse(localStorage.getItem("abo-prefs")); watchInfo = null; resumeSentFor = null; askHold = 0; window.__sent.length = 0; renderAll(); });
}
// Import comme l'app : 1 140 abonnés, export récent dont l'heure .zip n'a pas de fuseau (exact = false), sauf mention.
async function importExport(page, { minsAgo = 10, exact = false } = {}) {
  await page.evaluate(async ([m, ex]) => {
    const followers = {};
    for (let i = 0; i < 1140; i++) followers["ami" + i] = 1700000000 + i;
    pending = { followers, following: null, date: new Date(Date.now() - m * 60000), dated: true, exact: ex, source: "export.zip" };
    await commit(pending.date.toISOString());
  }, [minsAgo, exact]);
}
// Le premier écran de réussite passe d'abord, puis la question.
async function passFirst(page) {
  await page.waitForSelector("#first:not([hidden])", { timeout: 4000 });
  assert.equal(await page.locator("#ia").count(), 0, "jamais par-dessus « C'est ton départ ! »");
  await page.click("#first-ok");
}
const question = (page) => page.waitForSelector("#ia", { timeout: 5000 });

test("bon export, heure du .zip sans fuseau : pas de fin automatique, question après l'écran de réussite", async () => {
  const req = ago(30);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req, readyAt: ago(12) });
  await importExport(page);
  assert.deepEqual(await of(page, "exportEnded"), [], "aucune fin sur une simple heure de fichier");
  await passFirst(page);
  await question(page);
  assert.match(await page.textContent("#ia"), /1\s140 abonnés enregistrés/);
  assert.match(await page.textContent("#ia"), /Est-ce bien le fichier de ta demande Instagram en cours/);
  assert.equal(await page.textContent("#weekly-title"), "Export à vérifier", "jamais « Ton export se prépare » à côté de l'historique");
  // Oui : fin explicite, avec le compte et l'heure de la demande.
  await page.click("#ia-yes");
  assert.deepEqual(await of(page, "exportEnded"), [{ type: "exportEnded", reason: "cleared", acct: "a1", requestedAt: req }]);
  assert.equal(await page.evaluate(() => reqPending()), false);
  assert.equal(await page.textContent("#weekly-title"), "Mettre à jour");
  assert.equal(await page.evaluate(() => state.snapshots.length), 1, "l'historique importé est gardé");
  assert.equal(await page.evaluate(() => !!(prefs.requestKept || prefs.readyAt || prefs.importAsk)), false, "état local nettoyé");
  // La coque confirme : suivi arrêté, aucun rappel.
  await page.evaluate(() => window.zyeutoWatchInfo({ waiting: false, ready: false, reminders: 0 }));
  assert.match(await page.textContent("#toast-text"), /terminée et ses rappels sont retirés/);
  // Réouverture : rien ne revient (ni question, ni reprise, ni attente).
  await reopen(page);
  await page.waitForTimeout(300);
  assert.equal(await page.locator("#ia").count(), 0);
  assert.deepEqual(await of(page, "exportResume"), []);
  assert.equal(await page.evaluate(() => reqPending()), false);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("« Oui » mais la coque suit encore cette demande : jamais annoncé comme arrêté", async () => {
  const req = ago(30);
  const page = await open({ requestedAt: req });
  await importExport(page);
  await passFirst(page);
  await question(page);
  await page.click("#ia-yes");
  await page.evaluate((r) => window.zyeutoWatchInfo({ waiting: true, ready: false, reminders: 2, requestedAt: r }), req);
  const t = await page.textContent("#toast-text");
  assert.match(t, /l'app suit encore cette demande/);
  assert.doesNotMatch(t, /rappels sont retirés/);
  await page.close();
});

for (const [btn, a] of [["#ia-no", "no"], ["#ia-idk", "unknown"]]) {
  test(`« ${a === "no" ? "Non, c'est un ancien fichier" : "Je ne sais pas"} » : demande gardée, ligne discrète, « Vérifier mon export » reste`, async () => {
    const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(30) });
    await importExport(page);
    await passFirst(page);
    await question(page);
    await page.click(btn);
    assert.deepEqual(await of(page, "exportEnded"), []);
    assert.equal(await page.evaluate(() => reqPending()), true);
    assert.equal(await page.textContent("#weekly-title"), "Export à vérifier");
    assert.match(await page.textContent("#due"), /^Demandé le /);
    assert.deepEqual(await page.$$eval("#wk-steps i", (l) => l.map((i) => i.textContent)), ["✓", "?", "3"]);
    assert.equal(await page.textContent("#wk-go-t"), "Vérifier mon export");
    assert.equal(await page.evaluate(() => prefs.importAnswer.a), a);
    // Réouverture : la réponse est gardée, la question ne revient pas, le suivi non plus n'est pas terminé.
    await reopen(page);
    await page.waitForTimeout(300);
    assert.equal(await page.locator("#ia").count(), 0);
    assert.equal(await page.evaluate(() => reqPending()), true);
    assert.deepEqual(await of(page, "exportEnded"), []);
    await page.close();
  });
}

test("import déjà fait par l'ancienne page (cas de Victor) : la question vient sans réimporter, et revient tant qu'il n'a pas répondu", async () => {
  const req = ago(60);
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: req });
  await importExport(page);
  await passFirst(page);
  // Ancienne page : demande gardée (requestKept), aucune question enregistrée.
  await page.evaluate(() => { document.getElementById("ia")?.remove(); delete prefs.importAsk; delete prefs.importAnswer; savePrefs(); });
  await reopen(page);
  await question(page);
  assert.match(await page.textContent("#ia"), /1\s140 abonnés enregistrés/);
  await reopen(page);
  await question(page);
  await page.click("#ia-yes");
  assert.equal((await of(page, "exportEnded")).length, 1);
  assert.equal(await page.evaluate(() => state.snapshots.length), 1, "rien n'est réimporté ni effacé");
  await page.close();
});

test("ancien export (heure exacte avant la demande) : demande gardée, question avec la date", async () => {
  const page = await open({ requestedAt: ago(30) });
  await importExport(page, { minsAgo: 3 * 1440, exact: true });
  assert.deepEqual(await of(page, "exportEnded"), []);
  await passFirst(page);
  await question(page);
  assert.match(await page.textContent("#ia"), /fait avant ta demande/);
  await page.close();
});

test("bon export avec heure exacte ET vu prêt par l'app : fin automatique, aucune question", async () => {
  const page = await open({ requestedAt: ago(30), readyAt: ago(12) });
  await importExport(page, { exact: true });
  assert.equal((await of(page, "exportEnded"))[0].reason, "imported");
  await passFirst(page);
  await page.waitForTimeout(3000);
  assert.equal(await page.locator("#ia").count(), 0);
  assert.equal(await page.textContent("#weekly-title"), "Mettre à jour");
  await page.close();
});

test("heure exacte après la demande mais jamais vu prêt : question (une heure de fichier seule ne suffit pas)", async () => {
  const page = await open({ requestedAt: ago(30) });
  await importExport(page, { exact: true });
  assert.deepEqual(await of(page, "exportEnded"), []);
  await passFirst(page);
  await question(page);
  await page.close();
});

test("multicompte : import dans un autre compte que celui de la demande → aucune question, aucune fin", async () => {
  const page = await open({ accts, acctCur: "a2", requestAcct: "a1", requestedAt: ago(30) });
  await importExport(page);
  await passFirst(page);
  await page.waitForTimeout(3000);
  assert.equal(await page.locator("#ia").count(), 0);
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.close();
});

test("démo : jamais de question, et la vraie question revient en sortant", async () => {
  const page = await open({ requestedAt: ago(30) });
  await importExport(page);
  await passFirst(page);
  await question(page);
  await page.evaluate(() => { document.getElementById("ia").remove(); enterDemo(); render(); });
  await page.waitForTimeout(300);
  assert.equal(await page.locator("#ia").count(), 0);
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.evaluate(() => { leaveDemo(); render(); });
  await question(page);
  await page.close();
});

test("import annulé (Annuler du message) : plus de question, la demande reste suivie", async () => {
  const page = await open({ requestedAt: ago(30) });
  await importExport(page);
  await page.click("#undo");
  await page.waitForTimeout(3200);
  assert.equal(await page.locator("#ia").count(), 0);
  assert.equal(await page.evaluate(() => reqPending()), true);
  assert.deepEqual(await of(page, "exportEnded"), []);
  await page.close();
});
