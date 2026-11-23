// FOU-131 PR 2 (écran C) : la démo ouverte pendant une vraie demande (« Découvrir Zieuton » sur B).
// - bandeau « DÉMO · Compte fictif » ; pendant une demande, le bouton du haut s'appelle « Mon export » et ramène à B (ou E) ;
// - visite par le zieuteur : 4 bulles posées sur les vraies cartes, « Suivant » ou « Passer », jamais rejouée ;
// - la démo de la bienvenue (FOU-51) n'a pas de visite et n'écrit toujours rien sur le téléphone.
// Lancer : npm run test:lecteur.
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

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
async function open({ viewport = { width: 393, height: 852 }, colorScheme = "light", prefs = { requestedAt: ago(5) } } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion: "reduce", colorScheme });
  await serveGuide(page);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.addInitScript((p) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    if (p) localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, prefs);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(() => { window.zyeutoNotif({ status: "authorized" }); renderGuided(); });
  page.errors = errors;
  return page;
}
// Sur B, « Découvrir Zieuton ».
async function discover(page) {
  await page.waitForSelector("#gf-wait-demo", { state: "visible" });
  await page.click("#gf-wait-demo");
  await page.waitForFunction(() => DEMO === true);
}
const bubble = (page) => page.waitForSelector("#dt", { timeout: 3000 });
const say = (page) => page.textContent("#dt-say");
const inside = (a, b, pad = 0) => a.x >= b.x - pad && a.y >= b.y - pad && a.x + a.width <= b.x + b.width + pad && a.y + a.height <= b.y + b.height + pad;

test("B → « Découvrir Zieuton » : bandeau « Compte fictif », bouton « Mon export », 4 bulles dans l'ordre sur les vraies cartes", async () => {
  const page = await open();
  await discover(page);
  assert.equal((await page.textContent("#demo-bar span:not(.demo-tag)")).trim(), "Compte fictif");
  assert.equal((await page.textContent("#demo-quit")).trim(), "Mon export");
  await bubble(page);
  // Refonte FOU-131 : Départs, Arrivées, Pas en retour, Fans (le détail des textes est dans refonte-attente.test.mjs).
  const want = [
    ['.hm-tile[data-list="unfollow"]', "Les Départs"],
    ['.hm-tile[data-list="follow"]', "Les Arrivées"],
    ['.hm-tile[data-list="notback"]', "Les Pas en retour"],
    ['.hm-tile[data-list="fans"]', "Les Fans"],
  ];
  for (let i = 0; i < want.length; i++) {
    assert.equal(await page.textContent("#dt-tt"), want[i][1]);
    assert.equal(await page.textContent("#dt-n"), `Visite · ${i + 1} sur 4`);
    const card = await page.locator(want[i][0]).boundingBox(), ring = await page.locator("#dt-ring").boundingBox();
    assert.ok(inside(card, ring, 1), `l'anneau entoure la carte ${i + 1}`);
    assert.equal((await page.textContent("#dt-next")).trim(), i === 3 ? "Explorer la démo" : "Suivant");
    await page.click("#dt-next");
  }
  assert.equal(await page.locator("#dt").count(), 0, "visite finie");
  assert.equal(await page.evaluate(() => DEMO), true, "on reste libre dans la démo");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("la croix arrête la visite ; elle n'est jamais rejouée (ni en revenant, ni après réouverture de l'app)", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  await page.click("#dt-x");
  assert.equal(await page.locator("#dt").count(), 0);
  assert.equal(await page.evaluate(() => DEMO), true);
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")).demoTourDone), true, "notée tout de suite");
  // « Mon export » : retour sur B, avec la vraie demande.
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false);
  assert.equal(await page.evaluate(() => reqPending()), true);
  assert.match(await page.textContent("#gf-title"), /Ton export se prépare/);
  // Revenir dans la démo : pas de bulles.
  await discover(page);
  await page.waitForTimeout(900);
  assert.equal(await page.locator("#dt").count(), 0);
  const saved = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  await page.close();
  // Réouverture : mêmes réglages, pas de bulles.
  const again = await open({ prefs: saved });
  await discover(again);
  await again.waitForTimeout(900);
  assert.equal(await again.locator("#dt").count(), 0);
  await again.close();
});

const igSent = (page) => page.evaluate(() => window.__sent.filter((m) => m.type === "meta"));

test("U14 : fichier prêt pendant la démo : « Ton export est prêt 🎉 », « Mon export » ramène à E sans ouvrir Instagram", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  await page.evaluate(() => window.zyeutoMeta("ready"));
  assert.equal((await page.textContent("#demo-bar span:not(.demo-tag)")).trim(), "Ton export est prêt 🎉");
  assert.equal((await page.textContent("#demo-quit")).trim(), "Mon export");
  await page.click("#dt-x");
  await page.evaluate(() => { window.__sent.length = 0; });
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false);
  await page.waitForTimeout(400);
  assert.equal(await page.evaluate(() => exportSeenReady()), true);
  // Écran E visible, en haut, avec son bouton : c'est la personne qui choisit d'aller dans Instagram.
  assert.ok(await page.isVisible("#gf"));
  assert.equal(await page.textContent("#gf-title"), "Ton export est prêt\u00a0! 🎉");
  assert.match(await page.textContent("#gf-get"), /Récupérer mon export/);
  const t = await page.locator("#gf-title").boundingBox();
  assert.ok(t.y >= 0 && t.y + t.height <= 852, "titre de E visible sans défiler");
  assert.deepEqual(await igSent(page), [], "aucune commande d'ouverture d'Instagram envoyée à la coque");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("U14 : export prêt pendant qu'une bulle est affichée, clic direct sur « Mon export » : visite fermée, E affiché, Instagram jamais ouvert", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  await page.click("#dt-next");                                         // une bulle au milieu de la visite
  assert.equal(await page.textContent("#dt-n"), "Visite · 2 sur 4");
  await page.evaluate(() => { window.__sent.length = 0; window.zyeutoMeta("ready"); });
  assert.equal(await page.locator("#dt").count(), 1, "la bulle est toujours là quand le fichier devient prêt");
  assert.equal((await page.textContent("#demo-bar span:not(.demo-tag)")).trim(), "Ton export est prêt 🎉");
  await page.click("#demo-quit");                                       // sans fermer la bulle avant
  await page.waitForFunction(() => DEMO === false);
  await page.waitForTimeout(400);
  assert.equal(await page.locator("#dt").count(), 0, "la visite est fermée");
  assert.equal(await page.evaluate(() => document.documentElement.classList.contains("dt-lock") || document.body.classList.contains("dt-on")), false, "le défilement est rendu");
  assert.equal(await page.textContent("#gf-title"), "Ton export est prêt\u00a0! 🎉");
  assert.match(await page.textContent("#gf-get"), /Récupérer mon export/);
  const t = await page.locator("#gf-title").boundingBox();
  assert.ok(t.y >= 0 && t.y + t.height <= 852, "titre de E visible sans défiler");
  assert.deepEqual(await igSent(page), [], "aucune commande d'ouverture d'Instagram envoyée à la coque");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("U14 : pendant l'attente, « Mon export » ramène toujours à B sans ouvrir Instagram", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  await page.click("#dt-x");
  await page.evaluate(() => { window.__sent.length = 0; });
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false);
  await page.waitForTimeout(400);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.ok(await page.isVisible("#gf-wait-demo"));
  assert.deepEqual(await igSent(page), []);
  await page.close();
});

// Balayage horizontal (Jeux ← Accueil → Graphiques) pendant les bulles : bloqué, la page derrière ne bouge pas.
async function swipe(page, dx) {
  await page.evaluate(async (dx) => {
    const x0 = 200, y = 400, mk = (x) => new Touch({ identifier: 1, target: document.body, clientX: x, clientY: y });
    const fire = (type, x) => document.body.dispatchEvent(new TouchEvent(type, { bubbles: true, cancelable: true, touches: type === "touchend" ? [] : [mk(x)], changedTouches: [mk(x)] }));
    fire("touchstart", x0);
    for (let i = 1; i <= 10; i++) { fire("touchmove", x0 + (dx * i) / 10); await new Promise((r) => setTimeout(r, 8)); }
    fire("touchend", x0 + dx);
  }, dx);
  await page.waitForTimeout(350);
}

test("U14 : pendant la visite, le balayage ne change pas la page ; après la visite il marche à nouveau", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  for (const dx of [-250, 250]) {
    await swipe(page, dx);
    assert.equal(await page.evaluate(() => page), "home", `balayage ${dx} bloqué pendant la visite`);
    assert.equal(await page.locator("#dt").count(), 1, "la visite reste ouverte");
  }
  // Témoin : sans la visite, le même geste ouvre bien les Graphiques.
  await page.click("#dt-x");
  await swipe(page, -250);
  assert.equal(await page.evaluate(() => page), "stats");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("quitter la démo pendant la visite : les bulles disparaissent", async () => {
  const page = await open();
  await discover(page);
  await bubble(page);
  await page.evaluate(() => leaveDemo());
  assert.equal(await page.locator("#dt").count(), 0);
  await page.close();
});

test("démo de la bienvenue (sans demande) : pas de visite, bouton « Quitter la démo », rien d'écrit sur le téléphone", async () => {
  const page = await open({ prefs: null });
  await page.waitForSelector("#gf-demo");
  const before = await page.evaluate(() => localStorage.getItem("abo-prefs"));
  await page.click("#gf-demo");
  await page.waitForFunction(() => DEMO === true);
  await page.waitForTimeout(1000);
  assert.equal(await page.locator("#dt").count(), 0);
  assert.equal((await page.textContent("#demo-quit")).trim(), "Quitter la démo");
  assert.equal((await page.textContent("#demo-bar span:not(.demo-tag)")).trim(), "Compte fictif");
  assert.equal(await page.evaluate(() => localStorage.getItem("abo-prefs")), before);
  await page.close();
});

// Petit iPhone (zoom d'affichage), iPhone SE, iPhone 15 ; clair et sombre : bulle toujours dans l'écran, bandeau lisible.
for (const [name, viewport] of [["320 × 568", { width: 320, height: 568 }], ["iPhone SE", { width: 375, height: 667 }], ["iPhone 15", { width: 393, height: 852 }]]) {
  for (const colorScheme of ["light", "dark"]) {
    test(`visite lisible : ${name}, ${colorScheme === "dark" ? "sombre" : "clair"}`, async () => {
      const page = await open({ viewport, colorScheme });
      await discover(page);
      await bubble(page);
      const screen = { x: 0, y: 0, width: viewport.width, height: viewport.height };
      for (let i = 0; i < 4; i++) {
        const bub = await page.locator("#dt-bub").boundingBox(), ring = await page.locator("#dt-ring").boundingBox();
        assert.ok(inside(bub, screen), `bulle ${i + 1} dans l'écran`);
        assert.ok(bub.y >= ring.y + ring.height - 1 || bub.y + bub.height <= ring.y + 1, `bulle ${i + 1} ne cache pas sa carte`);
        const next = await page.locator("#dt-next").boundingBox();
        assert.ok(next.height >= 44, "bouton facile à toucher");
        await page.click("#dt-next");
      }
      // Le bandeau : « Compte fictif » entier dès 375 points de large.
      const cut = await page.$eval("#demo-bar span:not(.demo-tag)", (el) => ({ hidden: getComputedStyle(el).visibility === "hidden", cut: el.scrollWidth > el.clientWidth }));
      if (viewport.width >= 375) assert.deepEqual(cut, { hidden: false, cut: false });
      assert.deepEqual(page.errors, []);
      await page.close();
    });
  }
}
