// FOU-124 : écran d'attente après la demande d'export. Aucune estimation de délai, aucune promesse de surveillance
// quand l'app est fermée, « Découvrir Zieuton » mis en avant, « Refaire la demande » protégé contre les doublons.
// Ouvre index.html dans Chromium (Playwright) comme dans l'app iPhone. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function waiting(mins, extra = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(([m, x]) => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, requestedAt: new Date(Date.now() - m * 60000).toISOString(), ...x }));
  }, [mins, extra]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
const gfText = (page) => page.evaluate(() => document.getElementById("gf").innerText);

test("attente : pas d'estimation de délai ni de progression fixe", async () => {
  for (const mins of [1, 15, 200]) {
    const page = await waiting(mins);
    assert.equal(await page.textContent("#gf-title"), "Instagram prépare ta liste");
    const txt = await gfText(page);
    assert.doesNotMatch(txt, /quelques minutes|en général|1 à 3 min|devrait être prête|sûrement prête/i);
    // La barre n'annonce aucun pourcentage.
    assert.equal(await page.locator(".gx-track[aria-valuenow]").count(), 0);
    assert.equal(await page.locator(".gx-track.wait").count(), 1);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test("attente : on peut fermer l'app, sans promesse de surveillance en arrière-plan", async () => {
  const page = await waiting(5);
  const txt = await gfText(page);
  assert.match(txt, /Tu peux fermer l'app/);
  assert.match(txt, /à chaque ouverture de Zieuton/);
  assert.match(txt, /Quand Zieuton est fermé, je ne peux pas regarder chez Instagram/);
  assert.doesNotMatch(txt, /je guette|en continu|toutes les \d+ secondes|en permanence/i);
  await page.close();
});

test("demande déjà en cours : pas de « je guette »", async () => {
  const page = await waiting(5, { requestExisting: true });
  const txt = await gfText(page);
  assert.match(txt, /déjà en cours/);
  assert.doesNotMatch(txt, /je guette/i);
  await page.close();
});

test("« Découvrir Zieuton en attendant » est le bouton principal, « Refaire la demande » est discret", async () => {
  const page = await waiting(5);
  const first = await page.evaluate(() => { const b = document.querySelector("#gf .gf-foot .btn"); return b && { id: b.id, cls: b.className, t: b.textContent.trim() }; });
  assert.equal(first.id, "gf-wait-demo");
  assert.match(first.cls, /cheer/);
  assert.equal(first.t, "Découvrir Zieuton en attendant");
  assert.match(await page.getAttribute("#gf-back", "class"), /\balt\b/);
  await page.close();
});

test("« Refaire la demande » demande une confirmation : rien n'est effacé sans elle", async () => {
  const page = await waiting(5);
  const other = await page.evaluate(() => Object.keys(localStorage).filter((k) => k !== "abo-prefs").map((k) => k + "=" + localStorage.getItem(k)).sort());
  await page.click("#gf-back");
  assert.match(await page.textContent("#gf-redo"), /doublon/);
  let p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.ok(p.requestedAt, "la demande est toujours notée");
  // Le rafraîchissement de l'écran ne referme pas la confirmation.
  await page.evaluate(() => { const g = document.getElementById("gf-redo"); if (!g) throw new Error("absente"); });
  await page.click("#gf-redo-no");
  assert.equal(await page.locator("#gf-redo").count(), 0);
  assert.ok(await page.isVisible("#gf-back"));
  p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.ok(p.requestedAt, "« Non, j'attends » ne change rien");
  await page.click("#gf-back");
  await page.click("#gf-redo-yes");
  p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.equal(p.requestedAt, undefined, "confirmé : on peut refaire la demande");
  assert.match(await page.textContent("#gf-title"), /Zieuton en haut|On va chercher/);
  // Les autres données (imports, comptes…) ne bougent pas.
  const after2 = await page.evaluate(() => Object.keys(localStorage).filter((k) => k !== "abo-prefs").map((k) => k + "=" + localStorage.getItem(k)).sort());
  assert.deepEqual(after2, other);
  await page.close();
});

test("fichier vu prêt : l'écran passe à « Récupérer ma liste » (téléchargement et import inchangés)", async () => {
  const page = await waiting(5);
  await page.evaluate(() => window.zyeutoMeta("ready"));
  assert.equal(await page.textContent("#gf-title"), "Ta liste est prête");
  assert.match(await page.textContent("#gf-get"), /Récupérer ma liste/);
  await page.close();
});

test("petit iPhone : le bouton principal reste atteignable, pas de défilement de côté", async () => {
  const page = await browser.newPage({ viewport: { width: 320, height: 568 }, locale: "fr-FR", reducedMotion: "reduce" });
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, requestedAt: new Date(Date.now() - 5 * 60000).toISOString() }));
  });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  await page.locator("#gf-wait-demo").scrollIntoViewIfNeeded();
  assert.ok(await page.locator("#gf-wait-demo").isVisible());
  assert.ok(await page.evaluate(() => document.getElementById("gf").scrollWidth <= window.innerWidth));
  await page.close();
});
