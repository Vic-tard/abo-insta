// Sécurité du suivi (21 nov., PR A) : la page ne dit « plus en attente » (exportState pending:false) à la coque que quand une
// attente vue dans cette session se termine vraiment. Jamais au démarrage, jamais en démo, jamais pour un autre compte.
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
async function open(prefs, version = 10) {
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
  await page.evaluate(() => { renderAll(); renderGuided(); });
  page.errors = errors;
  return page;
}
const ended = (page) => page.evaluate(() => window.__sent.filter((m) => m.type === "exportState" && m.pending === false));

for (const [name, prefs] of [
  ["aucune demande (réglages perdus ou premier lancement)", {}],
  ["demande de plus de 5 jours", { requestedAt: ago(6 * 1440) }],
  ["demande d'un autre compte", { accts, acctCur: "a2", requestAcct: "a1", requestedAt: ago(10) }],
  ["compte 2 affiché, sans demande", { accts, acctCur: "a2" }],
]) {
  test(`démarrage, ${name} : jamais « plus en attente »`, async () => {
    for (const v of [10, 9]) {
      const page = await open(prefs, v);
      await page.evaluate(() => { renderAll(); renderWeekly(); });
      assert.deepEqual(await ended(page), [], `coque ${v}`);
      assert.deepEqual(page.errors, []);
      await page.close();
    }
  });
}

test("démarrage avec une demande : « en attente » avec son compte", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  const s = await page.evaluate(() => window.__sent.filter((m) => m.type === "exportState"));
  assert.ok(s.length && s.every((m) => m.pending === true && m.acct === "a1"), JSON.stringify(s));
  await page.close();
});

test("vraie fin : « Tout effacer » pendant une attente → « plus en attente » envoyé une fois", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await page.evaluate(() => { window.__sent.length = 0; });
  // Même effet que « Tout effacer » / « Refaire la demande » : la demande est retirée.
  await page.evaluate(() => { delete prefs.requestedAt; delete prefs.requestAcct; savePrefs(); renderWeekly(); renderWeekly(); });
  const e = await ended(page);
  assert.equal(e.length, 1);
  assert.equal(e[0].acct, "a1");
  await page.close();
});

test("vraie fin : import réel après la demande → « plus en attente »", async () => {
  const page = await open({ requestedAt: ago(10) });
  await page.evaluate(() => { window.__sent.length = 0; });
  // Un import plus récent que la demande la termine (reqPending passe à faux).
  await page.evaluate(() => { prefs.lastImportAt = new Date().toISOString(); state.snapshots.push({ takenAt: new Date().toISOString(), count: 1 }); renderWeekly(); });
  assert.equal(await page.evaluate(() => reqPending()), false);
  assert.equal((await ended(page)).length, 1);
  await page.close();
});

test("démo pendant une attente, puis vraie fin : seule la vraie fin est dite", async () => {
  const page = await open({ accts, acctCur: "a1", requestAcct: "a1", requestedAt: ago(10) });
  await page.evaluate(() => { window.__sent.length = 0; enterDemo(); renderWeekly(); leaveDemo(); renderWeekly(); });
  assert.deepEqual(await ended(page), []);
  await page.evaluate(() => { delete prefs.requestedAt; savePrefs(); renderWeekly(); });
  assert.equal((await ended(page)).length, 1);
  await page.close();
});
