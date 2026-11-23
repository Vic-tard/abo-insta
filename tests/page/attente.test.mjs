// FOU-121 P3 : pendant l'attente de l'export, la page ne dit « prête » que si l'app a VU le fichier chez Instagram,
// jamais au bout d'un délai. Ouvre index.html dans Chromium (Playwright) comme dans l'app iPhone. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { serveGuide } from "./images-zieuteur.mjs";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

// Ouvre la page dans une fausse coque, avec une demande faite il y a `mins` minutes (pas encore vue prête).
async function waiting(mins) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR" });
  await serveGuide(page);
  await page.addInitScript((m) => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, requestedAt: new Date(Date.now() - m * 60000).toISOString() }));
  }, mins);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderWeekly === "function");
  await page.evaluate(() => { renderWeekly(); renderGuided(); });
  return page;
}
const text = (page, id) => page.evaluate((i) => document.getElementById(i)?.textContent || "", id);

test("15 min après la demande, sans fichier vu : jamais « prête »", async () => {
  const page = await waiting(15);
  assert.equal(await text(page, "weekly-title"), "Ton export se prépare");
  assert.equal(await text(page, "wk-go-t"), "Vérifier mon export");
  const guided = await page.evaluate(() => document.body.innerText);
  assert.doesNotMatch(guided, /devrait être prête|sans doute arrivée|sûrement prête/i);
  assert.doesNotMatch(guided, /1 à 3 min/);
  await page.close();
});

test("2 jours après la demande, toujours rien vu : toujours « Ton export se prépare »", async () => {
  const page = await waiting(2 * 24 * 60);
  assert.equal(await text(page, "weekly-title"), "Ton export se prépare");
  await page.close();
});

test("l'app a vu le fichier prêt : la carte passe à « Ton export est prêt »", async () => {
  const page = await waiting(15);
  await page.evaluate(() => window.zyeutoMeta("ready"));
  assert.equal(await text(page, "weekly-title"), "Ton export est prêt");
  assert.equal(await text(page, "wk-go-t"), "Télécharger mon export");
  await page.close();
});
