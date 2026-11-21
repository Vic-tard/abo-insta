// Vidéo du 21 nov. 13 h 50 : ouvrir la démo pendant une vraie demande faisait envoyer « plus en attente » à la coque,
// qui oubliait alors la demande (plus de rappel, plus de « prêt », bandeau « En attente : pas prêt »).
// Règle : aucun écran de démo ne parle de l'attente à la coque. Lancer : npm run test:lecteur.
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
async function open(prefs) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript((p) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: 10, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, prefs);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
const states = (page) => page.evaluate(() => window.__sent.filter((m) => m.type === "exportState"));
const stored = (page) => page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
const ago = (min) => new Date(Date.now() - min * 60000).toISOString();

// Les trois cas de la vraie vie : demande sur le compte « a1 » (même id que le compte de démo), demande sans compte noté
// (un seul compte), demande sur le 2e compte affiché.
for (const [name, prefs] of [
  ["demande sur a1 (même id que la démo)", { accts, acctCur: "a1", requestAcct: "a1" }],
  ["demande sans compte noté", {}],
  ["demande sur le 2e compte", { accts, acctCur: "a2", requestAcct: "a2" }],
]) {
  test(`démo ouverte puis quittée pendant une vraie demande (${name}) : jamais « plus en attente », la demande reste suivie`, async () => {
    const page = await open({ ...prefs, requestedAt: ago(10) });
    await page.evaluate(() => { window.__sent.length = 0; });
    await page.evaluate(() => enterDemo());
    // Tout ce qu'on fait dans la démo, y compris changer de compte de démo.
    await page.evaluate(() => { renderAll(); renderWeekly(); });
    await page.evaluate(() => leaveDemo());
    await page.evaluate(() => { renderAll(); renderWeekly(); renderGuided(); });
    assert.deepEqual((await states(page)).filter((m) => m.pending === false), [], "la coque ne doit pas oublier la demande");
    assert.ok((await stored(page)).requestedAt, "la demande est gardée");
    assert.equal(await page.evaluate(() => reqPending()), true);
    assert.equal(await page.textContent("#gf-title"), "Ton export se prépare 👀");
    assert.deepEqual(page.errors, []);
    await page.close();
  });
}

test("démo : le fichier prêt de la vraie demande arrive toujours après la sortie de démo", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await page.evaluate(() => enterDemo());
  await page.evaluate(() => leaveDemo());
  await page.evaluate(() => window.zyeutoMeta("ready"));
  assert.equal(await page.textContent("#gf-title"), "Ton export est prêt ! 🎉");
  await page.close();
});

test("réouverture de l'app après la démo : la demande et son compte sont intacts", async () => {
  const first = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await first.evaluate(() => { enterDemo(); leaveDemo(); });
  const saved = await stored(first);
  await first.close();
  // Nouvelle page avec les réglages enregistrés (comme une app relancée).
  const page = await open(saved);
  const p = await stored(page);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare 👀");
  assert.ok(p.requestedAt);
  assert.equal(p.requestAcct, "a1");
  assert.equal(p.acctCur, "a1");
  await page.close();
});

test("hors démo, la vraie fin d'attente est toujours dite à la coque (« Refaire la demande »)", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await page.evaluate(() => { enterDemo(); leaveDemo(); window.__sent.length = 0; });
  // Fin réelle de l'attente : la demande est retirée côté page.
  await page.evaluate(() => { delete prefs.requestedAt; savePrefs(); renderWeekly(); });
  const s = await states(page);
  assert.ok(s.some((m) => m.pending === false && m.acct === "a1"), JSON.stringify(s));
  await page.close();
});
