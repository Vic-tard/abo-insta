// Refonte visuelle (23 nov.) : les trois premiers écrans du premier lancement.
// 1. « Salut, jeune zieuteur·euse ! » : le Zieuteur 3D P06 en deux calques (perso + bloc) ; au toucher, seul le perso
//    rebondit (350 ms), le bloc reste fixe ; rien ne bouge si l'iPhone réduit les animations.
// 2. « On va chercher tes abonnés chez Instagram » : 3 étapes (titre + une phrase), liens en bas à gauche et à droite.
// 3. « Zieuton en haut, Instagram en bas » : consignes et « J'ai compris, on y va » là dès l'arrivée.
// Sur un iPhone SE (375 × 667), les boutons principaux sont visibles sans faire défiler.
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

async function open({ viewport = { width: 393, height: 852 }, colorScheme = "light", reducedMotion = "no-preference", block } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion, colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/ERR_FILE_NOT_FOUND|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  if (block) await page.route(block, (r) => r.abort());
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
  });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  page.errors = errors;
  return page;
}
const click = (page, id) => page.evaluate((i) => document.getElementById(i).click(), id);
const inView = async (page, sel) => {
  const b = await page.locator(sel).boundingBox(), v = page.viewportSize();
  return b && b.y >= 0 && b.y + b.height <= v.height && b.x >= 0 && b.x + b.width <= v.width;
};

test("bienvenue : le Zieuteur 3D en deux calques, chargés depuis guide/", async () => {
  const page = await open();
  await page.waitForFunction(() => [...document.querySelectorAll("#wl-tap .zt img")].every((i) => i.complete && i.naturalWidth > 0));
  const srcs = await page.$$eval("#wl-tap .zt img", (l) => l.map((i) => i.getAttribute("src")));
  assert.deepEqual(srcs, ["guide/zieuteur-p06-perso-v1.png", "guide/zieuteur-p06-bloc-v1.png", "guide/zieuteur-p06-perso-v1.png"]);
  assert.equal(await page.locator("#wl-tap .wl-art").count(), 0, "plus d'icône carrée");
  assert.equal((await page.textContent("#gf-title")).replace(/\s+/g, " ").trim(), "Salut, jeune zieuteur·euse !");
  assert.equal(await page.locator(".wl-pts li").count(), 3);
  assert.equal(await page.locator("#gf-demo").isVisible(), true);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("bienvenue : toucher la tête = rebond de 350 ms du perso, le bloc ne bouge pas, nouvelle réplique", async () => {
  const page = await open();
  await page.waitForSelector("#wl-tap .zt");
  await click(page, "wl-tap");
  const anims = await page.evaluate(() => document.getAnimations().filter((a) => a.effect?.target?.closest?.(".zt")).map((a) => ({
    cls: a.effect.target.className, dur: a.effect.getTiming().duration,
  })));
  assert.equal(anims.filter((a) => /zt-move/.test(a.cls) && a.dur === 350).length, 2, "derrière et pattes devant bougent ensemble");
  assert.ok(!anims.some((a) => !/zt-move/.test(a.cls) && a.dur === 350), "le bloc reste fixe");
  await page.waitForFunction(() => document.getElementById("wl-bubble").textContent.includes("Hé"), null, { timeout: 2000 });
  // Un 2e toucher après la fin donne la réplique suivante.
  await page.waitForTimeout(100);
  await click(page, "wl-tap");
  await page.waitForFunction(() => document.getElementById("wl-bubble").textContent.includes("Tu m'as vu"), null, { timeout: 2000 });
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("bienvenue : réduction des animations = aucun rebond, la réplique change quand même", async () => {
  const page = await open({ reducedMotion: "reduce" });
  await page.waitForSelector("#wl-tap .zt");
  await click(page, "wl-tap");
  const n = await page.evaluate(() => document.getAnimations().filter((a) => a.effect?.target?.closest?.(".zt")).length);
  assert.equal(n, 0);
  assert.match(await page.textContent("#wl-bubble"), /Hé/);
  await page.close();
});

test("bienvenue : sans les images du Zieuteur, l'ancien dessin reste affiché", async () => {
  const page = await open({ block: /zieuteur-p06/ });
  await page.waitForSelector("#wl-tap .zt.zt-off svg");
  await click(page, "wl-tap");
  assert.match(await page.textContent("#wl-bubble"), /Hé/);
  await page.close();
});

test("écran des 3 étapes : titres + une phrase, bouton présent, liens à gauche et à droite", async () => {
  const page = await open();
  await click(page, "gf-go");
  await page.waitForSelector(".pl2 .zt");
  const steps = await page.$$eval(".pl2 .pl-steps li", (l) => l.map((li) => [li.querySelector("b").textContent, li.querySelector("small").textContent]));
  assert.deepEqual(steps, [
    ["Ouvre Instagram", "Tu restes dans Zieuton."],
    ["Demande ton export", "Le Zieuteur te montre où toucher."],
    ["Récupère ton fichier", "Reviens ici quand Instagram l'a préparé."],
  ]);
  await page.waitForTimeout(1300);
  const via = await page.locator("#gf-via").boundingBox(), rs = await page.locator("#gf-restore").boundingBox();
  const btn = await page.locator("#gf-meta").boundingBox(), list = await page.locator(".pl2 .pl-steps").boundingBox();
  assert.ok(via.x < rs.x && Math.abs(via.y - rs.y) < 2, "« Passer par l'app » à gauche, « J'ai une sauvegarde » à droite");
  assert.ok(via.height >= 44 && rs.height >= 44, "zones tactiles de 44 px");
  assert.ok(btn.height >= 70, "bouton plus haut");
  assert.ok(btn.y - (list.y + list.height) < 40, "les étapes descendent jusqu'au bouton (pas de grand vide)");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("« Zieuton en haut, Instagram en bas » : consignes et bouton là dès l'arrivée", async () => {
  const page = await open();
  await click(page, "gf-go");
  await page.waitForSelector("#gf-meta");
  await click(page, "gf-meta");
  await page.waitForSelector(".in-pts");
  await page.waitForTimeout(50);
  const op = await page.$$eval(".in-pts li, .in ~ .pl-foot", (l) => l.map((e) => +getComputedStyle(e).opacity));
  assert.ok(op.every((o) => o === 1), "rien n'attend pour apparaître");
  assert.equal((await page.textContent("#gf-meta")).trim(), "J'ai compris, on y va");
  // Le geste : bandeau Zieuton d'abord, puis le bouton bleu.
  const d = await page.evaluate(() => ({ zy: getComputedStyle(document.querySelector(".in-zy")).animationDelay, tap: getComputedStyle(document.querySelector(".in-tap")).animationDelay }));
  assert.ok(parseFloat(d.zy) < parseFloat(d.tap));
  assert.deepEqual(page.errors, []);
  await page.close();
});

for (const colorScheme of ["light", "dark"]) {
  test(`iPhone SE (${colorScheme}) : les boutons principaux sont visibles sans défiler`, async () => {
    const page = await open({ viewport: { width: 375, height: 667 }, colorScheme });
    await page.waitForTimeout(4500);
    assert.ok(await inView(page, "#gf-go"), "C'est parti !");
    assert.ok(await inView(page, "#gf-demo"), "Voir la démo d'abord");
    await click(page, "gf-go");
    await page.waitForTimeout(1400);
    for (const id of ["#gf-meta", "#gf-via", "#gf-restore"]) assert.ok(await inView(page, id), id);
    await click(page, "gf-meta");
    await page.waitForTimeout(300);
    for (const id of ["#gf-meta", "#gf-via"]) assert.ok(await inView(page, id), id + " (écran 3)");
    await page.close();
  });
}
