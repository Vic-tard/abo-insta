// Refonte visuelle (23 nov.) : les trois premiers écrans du premier lancement.
// 1. « Salut, jeune zieuteur·euse ! » : le Zieuteur 3D P06 en deux calques (perso + bloc) ; au toucher, seul le perso
//    rebondit (350 ms), le bloc reste fixe ; rien ne bouge si l'iPhone réduit les animations.
// 2. « On va chercher tes abonnés chez Instagram » : 3 étapes (titre + une phrase), liens en bas à gauche et à droite.
// 3. « Zieuton en haut, Instagram en bas » : consignes et « Ouvrir Instagram » là dès l'arrivée.
// Sur un iPhone SE (375 × 667), les boutons principaux sont visibles sans faire défiler.
// Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

const ZT = ["zieuteur-p06-perso-v1.png", "zieuteur-p06-bloc-v1.png"];
const GH = "https://vic-tard.github.io/abo-insta/";
// Les images « en ligne » sont servies depuis le dépôt ; hits compte les demandes par site.
async function serveImages(page, { zieuton = true, github = true } = {}) {
  const hits = { zieuton: 0, github: 0 };
  const serve = (key, on) => async (r) => {
    hits[key]++;
    if (!on) return r.abort();
    const f = r.request().url().split("/guide/")[1].split("?")[0];
    await r.fulfill({ contentType: "image/png", body: readFileSync(root + "guide/" + f) });
  };
  await page.route("https://zieuton.com/guide/**", serve("zieuton", zieuton));
  await page.route(GH + "guide/**", serve("github", github));
  return hits;
}
async function open({ viewport = { width: 393, height: 852 }, colorScheme = "light", reducedMotion = "no-preference", block, assets } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion, colorScheme });
  page.hits = await serveImages(page);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error" && !/ERR_FILE_NOT_FOUND|Failed to load resource/.test(m.text())) errors.push(m.text()); });
  if (block) await page.route(block, (r) => r.abort());
  await page.addInitScript((a) => {
    if (a) window.ZYEUTO_ASSETS = a;
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
  }, assets || null);
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

const loaded = (page) => page.waitForFunction(() => [...document.querySelectorAll("#wl-tap .zt img")].length === 3
  && [...document.querySelectorAll("#wl-tap .zt img")].every((i) => i.complete && i.naturalWidth > 0), null, { timeout: 5000 });
const srcs = (page) => page.$$eval("#wl-tap .zt img", (l) => l.map((i) => i.currentSrc || i.src));

// Non-régression (relecture du 23 nov.) : dans l'app (coque 23), la page est affichée par loadHTMLString à l'adresse
// GitHub Pages, que la page vienne de l'app ou du canal test. Les images doivent être lues sur zieuton.com.
async function openLikeApp({ zieuton = true, github = true } = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR" });
  const hits = await serveImages(page, { zieuton, github });
  await page.route(GH, (r) => r.fulfill({ contentType: "text/html", body: readFileSync(root + "index.html") }));
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
  });
  await page.goto(GH);
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  page.hits = hits;
  return page;
}

test("app (coque 23, page à l'adresse GitHub Pages) : les deux PNG viennent de zieuton.com", async () => {
  const page = await openLikeApp({ github: false });
  await loaded(page);
  const s = await srcs(page);
  assert.deepEqual(s, [ZT[0], ZT[1], ZT[0]].map((f) => "https://zieuton.com/guide/" + f));
  assert.equal(page.hits.github, 0, "aucune demande à GitHub Pages quand zieuton.com répond");
  assert.equal(await page.locator(".zt-off").count(), 0);
  await page.close();
});

test("app : zieuton.com injoignable → GitHub Pages en secours, puis l'ancien dessin si rien ne répond", async () => {
  let page = await openLikeApp({ zieuton: false });
  await loaded(page);
  assert.ok((await srcs(page)).every((u) => u.startsWith(GH + "guide/zieuteur-p06-")));
  await page.close();
  page = await openLikeApp({ zieuton: false, github: false });
  await page.waitForSelector("#wl-tap .zt.zt-off svg");
  await page.close();
});

test("app : une image rangée dans l'app (builds suivants) passe avant le réseau", async () => {
  const png = (f) => "data:image/png;base64," + readFileSync(root + "guide/" + f).toString("base64");
  const page = await open({ assets: { ["guide/" + ZT[0]]: png(ZT[0]), ["guide/" + ZT[1]]: png(ZT[1]) } });
  await loaded(page);
  assert.ok((await srcs(page)).every((u) => u.startsWith("data:image/png")));
  assert.deepEqual(page.hits, { zieuton: 0, github: 0 });
  await page.close();
});

test("site (Safari, sans l'app) : chemins relatifs, servis par le site lui-même", async () => {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 } });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await loaded(page);
  assert.deepEqual(await page.$$eval("#wl-tap .zt img", (l) => l.map((i) => i.getAttribute("src"))), [ZT[0], ZT[1], ZT[0]].map((f) => "guide/" + f));
  await page.close();
});

test("bienvenue : le Zieuteur 3D en deux calques", async () => {
  const page = await open();
  await loaded(page);
  assert.equal(await page.locator("#wl-tap .wl-art").count(), 0, "plus d'icône carrée");
  assert.equal((await page.textContent("#gf-title")).replace(/\s+/g, " ").trim(), "Salut, jeune zieuteur·euse !");
  assert.deepEqual(await page.$$eval(".wl-pts li", (l) => l.map((li) => li.textContent.trim())), ["Mot de passe saisi chez Instagram", "Je te guidepas à pas", "Tout restechez toi"]);
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

// Toutes les animations en cours dans le parcours (CSS et JS), avec leur nombre de répétitions.
const running = (page) => page.evaluate(() => document.getAnimations()
  .filter((a) => a.playState === "running" && a.effect?.target?.closest?.("#gf"))
  .map((a) => ({ name: a.animationName || "js", el: a.effect.target.className?.baseVal ?? a.effect.target.className, loop: a.effect.getComputedTiming().iterations === Infinity })));

test("bienvenue : réduction des animations = aucun rebond, aucune boucle, même après plusieurs secondes", async () => {
  const page = await open({ reducedMotion: "reduce" });
  await page.waitForSelector("#wl-tap .zt");
  // « Touche ma tête ! » arrive au bout de 4,8 s : on attend au-delà, sans toucher.
  await page.waitForFunction(() => document.getElementById("wl-stage").classList.contains("hinting"), null, { timeout: 7000 });
  await page.waitForTimeout(1500);
  assert.deepEqual((await running(page)).filter((a) => a.loop), [], "aucune animation en boucle (ni anneau, ni yeux, ni étincelles)");
  assert.deepEqual(await running(page), [], "rien ne bouge du tout");
  await click(page, "wl-tap");
  const n = await page.evaluate(() => document.getAnimations().filter((a) => a.effect?.target?.closest?.(".zt")).length);
  assert.equal(n, 0, "pas de rebond");
  assert.match(await page.textContent("#wl-bubble"), /Hé/);
  await page.waitForTimeout(3000);
  assert.deepEqual((await running(page)).filter((a) => a.loop), []);
  // Les deux écrans suivants non plus.
  await click(page, "gf-go");
  await page.waitForTimeout(2000);
  assert.deepEqual((await running(page)).filter((a) => a.loop), [], "écran des 3 étapes");
  await click(page, "gf-meta");
  await page.waitForTimeout(4000);
  assert.deepEqual((await running(page)).filter((a) => a.loop), [], "écran Zieuton en haut");
  await page.close();
});

test("bienvenue : sans les images du Zieuteur, l'ancien dessin reste affiché", async () => {
  const page = await open({ block: /zieuteur-p06/ });
  await page.waitForSelector("#wl-tap .zt.zt-off svg");
  await click(page, "wl-tap");
  assert.match(await page.textContent("#wl-bubble"), /Hé/);
  await page.close();
});

test("écran des 3 étapes : titres + une phrase, bouton « Continuer », liens à gauche et à droite", async () => {
  const page = await open();
  await click(page, "gf-go");
  await page.waitForSelector(".pl2 .zt");
  // Ce bouton ouvre encore le tutoriel : il n'annonce pas « Ouvrir Instagram ».
  assert.equal((await page.textContent("#gf-meta")).trim(), "Continuer");
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
  assert.equal((await page.textContent("#gf-meta")).trim(), "Ouvrir Instagram");
  assert.equal(await page.locator(".in-zy .zt").count(), 0, "pas de Zieuteur dans le bandeau du schéma");
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
