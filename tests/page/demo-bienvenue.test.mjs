// FOU-51 : « Voir la démo d'abord » sur l'écran de bienvenue. La démo s'ouvre sans Instagram ni import,
// et en la quittant on retrouve la même bienvenue, sans rien d'écrit sur le téléphone. Le parcours Instagram ne change pas.
// Ouvre index.html dans Chromium (Playwright) comme dans l'app iPhone. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

// Premier lancement dans l'app iPhone : rien sur le téléphone. Les messages envoyés à l'app sont notés.
async function firstLaunch(prefs) {
  const page = await browser.newPage({ viewport: { width: 375, height: 667 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript((p) => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.__sent = [];
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m && m.type) } } };
    if (p) localStorage.setItem("abo-prefs", JSON.stringify(p));
  }, prefs || null);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !document.getElementById("gf").hidden);
  page.errors = errors;
  return page;
}
// Tout ce que la page garde sur le téléphone (localStorage + IndexedDB), pour comparer avant et après.
const stored = (page) => page.evaluate(async () => {
  const ls = {};
  for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); ls[k] = localStorage.getItem(k); }
  const idb = {};
  for (const info of (await indexedDB.databases())) {
    const db = await new Promise((ok, ko) => { const r = indexedDB.open(info.name); r.onsuccess = () => ok(r.result); r.onerror = () => ko(r.error); });
    for (const name of db.objectStoreNames) {
      idb[info.name + "/" + name] = await new Promise((ok) => {
        const all = db.transaction(name).objectStore(name).getAll();
        all.onsuccess = () => ok(JSON.stringify(all.result)); all.onerror = () => ok("?");
      });
    }
    db.close();
  }
  return { ls, idb };
});
// La sauvegarde des réglages est différée : on laisse passer son délai avant de comparer.
const settle = (page) => page.waitForTimeout(700);

test("bienvenue : le lien démo est là, discret, sous « C'est parti ! »", async () => {
  const page = await firstLaunch();
  assert.equal(await page.locator("#gf-body").getAttribute("data-step"), "welcome");
  assert.equal((await page.textContent("#gf-demo")).trim(), "Voir la démo d'abord");
  // Après le gros bouton, dans le même pied d'écran.
  assert.equal(await page.evaluate(() => document.getElementById("gf-go").nextElementSibling.id), "gf-demo");
  const go = await page.locator("#gf-go").boundingBox(), demo = await page.locator("#gf-demo").boundingBox();
  assert.ok(demo.y > go.y + go.height - 1, "le lien est sous le bouton principal");
  assert.ok(go.height > demo.height * 1.5, "le bouton principal reste bien plus gros");
  assert.ok(demo.height >= 44, "assez grand pour le doigt (44 px)");
  assert.ok(demo.y + demo.height <= 667, "visible sans défiler sur un petit iPhone (375 × 667)");
  const size = (sel) => page.$eval(sel, (el) => parseFloat(getComputedStyle(el).fontSize));
  assert.ok(await size("#gf-demo") < (await size("#gf-go")) / 1.8);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("démo depuis la bienvenue : sans Instagram ni import, puis retour à la même bienvenue, rien d'écrit", async () => {
  const page = await firstLaunch();
  await settle(page);
  const before = await stored(page);
  await page.evaluate(() => { window.__sent.length = 0; });
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  assert.equal(await page.locator("#gf").isHidden(), true, "le parcours se range pendant la démo");
  assert.equal(await page.locator("#demo-bar").isVisible(), true);
  assert.equal((await page.textContent("#demo-quit")).trim(), "Quitter la démo");
  assert.ok(await page.evaluate(() => state.snapshots.length) > 1, "la démo a ses abonnés inventés");
  // Ni Instagram ni fichier : la seule demande à l'app est une petite vibration.
  const sent = await page.evaluate(() => window.__sent.filter((t) => t !== "haptic" && t !== "update"));
  assert.deepEqual(sent, []);
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false && !document.getElementById("gf").hidden);
  assert.equal(await page.locator("#gf-body").getAttribute("data-step"), "welcome");
  assert.equal(await page.locator("#gf-go").isVisible(), true);
  assert.equal(await page.evaluate(() => state.snapshots.length), 0);
  assert.equal(await page.evaluate(() => prefs.welcomed), undefined, "la bienvenue n'est pas marquée comme vue");
  await settle(page);
  assert.deepEqual(await stored(page), before, "rien de nouveau sur le téléphone");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("réglages déjà là (thème) : gardés à l'identique après la démo", async () => {
  const page = await firstLaunch({ theme: "dark", welcomed: false });
  await settle(page);
  const before = await stored(page);
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false);
  await settle(page);
  assert.equal(await page.locator("#gf-body").getAttribute("data-step"), "welcome");
  assert.deepEqual(await stored(page), before);
  await page.close();
});

test("parcours Instagram inchangé après la démo : « C'est parti ! » mène au même plan", async () => {
  const page = await firstLaunch();
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false && !document.getElementById("gf").hidden);
  await page.click("#gf-go");
  await page.waitForFunction(() => document.getElementById("gf-body").dataset.step === "insta");
  assert.equal(await page.textContent("#gf-title"), "On va chercher tes abonnés chez Instagram");
  assert.equal((await page.textContent("#gf-meta")).trim(), "Ouvrir Instagram");
  assert.equal(await page.locator("#gf-via").isVisible(), true);
  assert.equal(await page.locator("#gf-restore").isVisible(), true);
  // Le lien démo reste propre à la bienvenue : le plan n'a pas un bouton de plus.
  assert.equal(await page.locator("#gf-demo").count(), 0);
  assert.equal(await page.evaluate(() => prefs.welcomed), true);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("un vrai fichier reçu pendant la démo : on sort de la démo et l'import se fait", async () => {
  const page = await firstLaunch();
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  const b64 = readFileSync(root + "exemple/zieuton-exemple-1.zip").toString("base64");
  await page.evaluate(async (d) => { window.zyeutoFile.begin("zieuton-exemple-1.zip"); window.zyeutoFile.add(d); await window.zyeutoFile.end(); }, b64);
  await page.waitForFunction(() => DEMO === false && state.snapshots.length === 1);
  assert.equal(await page.evaluate(() => state.snapshots[0].count), 40);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("démo : prénoms inventés au hasard (jamais Victor), deux comptes différents", async () => {
  const page = await firstLaunch();
  const seen = new Set();
  for (let i = 0; i < 6; i++) {
    await page.evaluate(() => enterDemo());
    const names = await page.evaluate(() => [prefs.me.name, prefs.accts.find((a) => a.slot === 2).p.me.name, prefs.me.ig]);
    assert.notEqual(names[0], names[1], "les deux comptes de la démo n'ont pas le même prénom");
    for (const n of names.slice(0, 2)) { assert.doesNotMatch(n, /victor|mathéo/i); seen.add(n); }
    assert.match(names[2], /^[a-z]+\.demo$/, "pseudo inventé, reconnu comme démo");
    assert.equal(await page.textContent("#acct-pill") .then((t) => t.includes(names[0])), true, "le prénom affiché en haut est celui de la démo");
    await page.evaluate(() => leaveDemo());
  }
  assert.ok(seen.size > 2, "les prénoms changent d'une démo à l'autre");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("démo : la barre « Quitter la démo » est grande et bien visible", async () => {
  const page = await firstLaunch();
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  const q = await page.locator("#demo-quit").boundingBox();
  assert.ok(q.height >= 44, "bouton d'au moins 44 px");
  assert.ok(await page.$eval("#demo-quit", (el) => parseFloat(getComputedStyle(el).fontSize)) >= 15);
  // Rien de la page ne passe sous la barre : le contenu commence en dessous.
  const bar = await page.locator("#demo-bar").boundingBox();
  const top = await page.evaluate(() => document.querySelector(".wrap > *:not([hidden])").getBoundingClientRect().top);
  assert.ok(top >= bar.y + bar.height, "le haut de l'accueil n'est pas caché par la barre");
  await page.close();
});
