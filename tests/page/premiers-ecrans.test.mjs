// Refonte « Bonbon prune » (maquettes validées par Victor le 25 nov.) : les trois premiers écrans du premier lancement.
// 1. « Salut, jeune zieuteur·euse ! » : le zieuteur derrière son mur prune ; le toucher le cache un instant, sans rien interrompre.
// 2. « On va chercher tes abonnés chez Instagram » : 3 cartes (titre + une phrase), zieuteur immobile, liens à gauche et à droite.
// 3. « Zieuton en haut, Instagram en bas » : 2 rappels courts, un doigt qui touche deux fois la partie Instagram puis s'en va.
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

// Dans l'app (coque 23), la page est affichée par loadHTMLString à l'adresse GitHub Pages.
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
// Refonte « Bonbon prune » (25 nov.) : les poses du zieuteur sont rangées dans la page (WebP), sans aucune demande réseau.
const loaded = (page, sel = "#gf .bb-zt img") => page.waitForFunction((s) => {
  const l = [...document.querySelectorAll(s)];
  return l.length > 0 && l.every((i) => i.complete && i.naturalWidth > 0);
}, sel, { timeout: 5000 });

test("app (page à l'adresse GitHub Pages) : les poses du zieuteur viennent de la page, sans réseau", async () => {
  const page = await openLikeApp({ zieuton: false, github: false });
  await loaded(page);
  assert.ok((await page.$$eval("#gf .bb-zt img", (l) => l.map((i) => i.src))).every((u) => u.startsWith("blob:")));
  assert.deepEqual(page.hits, { zieuton: 0, github: 0 }, "aucune demande à zieuton.com ni à GitHub Pages");
  assert.equal(await page.locator("#gf .bb-svg").count(), 0);
  await page.close();
});

test("site (Safari, sans l'app) : mêmes poses, rangées dans la page", async () => {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 } });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await loaded(page);
  await page.close();
});

test("bienvenue : titre, 3 cartes, « C'est parti ! » et le lien démo", async () => {
  const page = await open();
  await loaded(page);
  assert.equal((await page.textContent("#gf-title")).replace(/\s+/g, " ").trim(), "Salut, jeune zieuteur·euse !");
  assert.deepEqual(await page.$$eval(".bb-c3 li", (l) => l.map((li) => li.textContent.trim())), ["Mot de passe saisi chez Instagram", "Je te guide pas à pas", "Tout reste chez toi"]);
  assert.equal((await page.textContent("#gf-go")).trim(), "C'est parti\u00a0!");
  assert.equal(await page.locator("#gf-demo").isVisible(), true);
  // Le zieuteur est derrière son mur (le mur passe devant lui).
  assert.ok(await page.$eval("#gf .bb-zt .bb-mur", (m) => +getComputedStyle(m).zIndex > 0));
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("toucher le zieuteur : il se cache derrière son mur puis revient, sans rien interrompre", async () => {
  const page = await open();
  await loaded(page);
  const z = page.locator("#gf button.bb-zt");
  const b = await z.boundingBox();
  await page.mouse.move(b.x + b.width / 2, b.y + b.height / 3);
  await page.mouse.down();
  assert.match(await z.getAttribute("class"), /\bhid\b/, "il plonge derrière le mur");
  await page.waitForTimeout(250);
  const y = await page.$eval("#gf button.bb-zt img", (i) => new DOMMatrix(getComputedStyle(i).transform).m42);
  assert.ok(y > 50, "l'image est descendue derrière le mur (" + y + " px)");
  await page.mouse.up();
  assert.doesNotMatch(await z.getAttribute("class"), /\bhid\b/, "il remonte");
  assert.equal(await page.locator("#gf-body").getAttribute("data-step"), "welcome", "toujours sur la bienvenue");
  // Même chose sur l'écran « Zieuton en haut » : le tutoriel continue.
  await click(page, "gf-go"); await click(page, "gf-meta");
  await page.locator("#gf button.bb-zt").click();
  assert.match(await page.textContent("#gf-title"), /Zieuton en haut/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

// Toutes les animations en cours dans le parcours (CSS et JS), avec leur nombre de répétitions.
const running = (page) => page.evaluate(() => document.getAnimations()
  .filter((a) => a.playState === "running" && a.effect?.target?.closest?.("#gf"))
  .map((a) => ({ name: a.animationName || "js", el: a.effect.target.className?.baseVal ?? a.effect.target.className, loop: a.effect.getComputedTiming().iterations === Infinity })));

test("aucune animation en boucle sur les 3 premiers écrans ; réduction des animations = rien ne bouge", async () => {
  let page = await open();
  for (const next of ["gf-go", "gf-meta", null]) {
    await page.waitForTimeout(300);
    assert.deepEqual((await running(page)).filter((a) => a.loop), [], "aucune boucle");
    if (next) await click(page, next);
  }
  // Le doigt de « Zieuton en haut » touche deux fois puis disparaît : une seule fois.
  await page.waitForTimeout(4500);
  assert.deepEqual(await running(page), [], "tout est fini, rien ne se répète");
  assert.equal(await page.$eval(".bb-tel-b .bb-doigt", (d) => getComputedStyle(d).opacity), "0");
  await page.close();
  page = await open({ reducedMotion: "reduce" });
  await page.waitForTimeout(300);
  assert.deepEqual(await running(page), [], "bienvenue : rien ne bouge");
  await click(page, "gf-go");
  await page.waitForTimeout(300);
  assert.deepEqual(await running(page), [], "écran des 3 étapes");
  await click(page, "gf-meta");
  await page.waitForTimeout(300);
  assert.deepEqual(await running(page), [], "écran Zieuton en haut");
  await page.close();
});

test("pose illisible : l'ancien dessin s'affiche à la place, derrière le même mur", async () => {
  const page = await open();
  await loaded(page);
  await page.evaluate(() => bbFail(document.querySelector("#gf .bb-zt img")));
  assert.equal(await page.locator("#gf .bb-zt .bb-svg svg").count(), 1);
  await page.close();
});

test("écran des 3 étapes : titres + une phrase, bouton « Continuer », liens à gauche et à droite", async () => {
  const page = await open();
  await click(page, "gf-go");
  await page.waitForSelector(".bb-pl .bb-zt");
  // Ce bouton ouvre encore le tutoriel : il n'annonce pas « Ouvrir Instagram ».
  assert.equal((await page.textContent("#gf-meta")).trim(), "Continuer");
  assert.equal((await page.textContent("#gf-title")).replace(/\s+/g, " ").trim(), "On va chercher tes abonnés chez Instagram");
  const steps = await page.$$eval(".bb-cards li", (l) => l.map((li) => [li.querySelector("b").textContent, li.querySelector("small").textContent]));
  assert.deepEqual(steps, [
    ["Ouvre Instagram", "Tu restes dans Zieuton, je ne te lâche pas."],
    ["Demande ton export", "Je te montre pile où toucher."],
    ["Récupère ton fichier", "Instagram le prépare, tu reviens ici le chercher."],
  ]);
  // Ici le zieuteur reste immobile : ce n'est pas un bouton.
  assert.equal(await page.locator(".bb-pl button.bb-zt").count(), 0);
  await page.waitForTimeout(2900);
  const via = await page.locator("#gf-via").boundingBox(), rs = await page.locator("#gf-restore").boundingBox();
  const btn = await page.locator("#gf-meta").boundingBox();
  assert.ok(via.x < rs.x && Math.abs(via.y - rs.y) < 2, "« Passer par l'app » à gauche, « J'ai une sauvegarde » à droite");
  assert.ok(via.height >= 44 && rs.height >= 44, "zones tactiles de 44 px");
  assert.ok(btn.height >= 70, "gros bouton");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("« Zieuton en haut, Instagram en bas » : consignes courtes et doigt qui touche la partie Instagram", async () => {
  const page = await open();
  await click(page, "gf-go");
  await page.waitForSelector("#gf-meta");
  await click(page, "gf-meta");
  await page.waitForSelector(".bb-rap");
  assert.equal((await page.textContent("#gf-meta")).trim(), "Ouvrir Instagram");
  assert.deepEqual(await page.$$eval(".bb-rap > div", (l) => l.map((d) => [d.querySelector("b").textContent, d.querySelector("small").textContent])), [["Mot de passe", "Il reste chez Instagram."], ["Cookies\u00a0?", "Refuse les cookies optionnels."]]);
  // Le doigt est dans la partie Instagram (en bas) ; il touche deux fois puis s'en va.
  const tel = await page.locator(".bb-tel-b").boundingBox(), d = await page.locator(".bb-tel-b .bb-doigt").boundingBox();
  assert.ok(d.y > tel.y && d.y < tel.y + tel.height, "le doigt est sur Instagram");
  const it = await page.$eval(".bb-tel-b .bb-doigt", (e) => getComputedStyle(e).animationIterationCount);
  assert.equal(it, "1", "pas en boucle");
  assert.equal(await page.locator(".bb-tel-b .bb-onde").count(), 2, "deux touches");
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
