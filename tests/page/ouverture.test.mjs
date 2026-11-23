// Écran d'ouverture (Victor, 24 nov.) : le visuel fixe net (logo) en fond, seul le petit zieuteur animé par-dessus,
// rangés dans l'app (coque 24), sans écran vide au lancement.
// - Images fournies par l'app (ZYEUTO_ASSETS) : l'animation s'affiche sans réseau, puis la page dit « opening/shown »
//   à la coque (qui efface alors son écran de lancement, la même première image).
// - « Réduire les animations » : la première image fixe (pas l'animation), puis l'app.
// - Rien d'affichable : la page dit « opening/none » tout de suite et passe à l'app ; jamais bloquée.
// Lancer : node --test tests/page/ouverture.test.mjs
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
const FOND = "media/ouverture-v2-fond.jpg", ANIM = "media/ouverture-v2-zieuteur.webp", STILL = "media/ouverture-v2-image1.jpg";
const dataURL = (f, type) => `data:${type};base64,` + readFileSync(root + f).toString("base64");
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function open({ reducedMotion = "no-preference", colorScheme = "light", assets = true } = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion, colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  // Pas de réseau : tout doit venir de l'app.
  await page.route(/^https?:/, (r) => r.abort());
  await page.addInitScript((a) => {
    if (a) window.ZYEUTO_ASSETS = a;
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.__sent = [];
    window.__t0 = performance.now();
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push({ ...m, at: performance.now() - window.__t0 }) } } };
  }, assets ? { [FOND]: dataURL(FOND, "image/jpeg"), [ANIM]: dataURL(ANIM, "image/webp"), [STILL]: dataURL(STILL, "image/jpeg") } : null);
  await page.goto("file://" + root + "index.html#ouverture");
  page.errors = errors;
  return page;
}
const openings = (page) => page.evaluate(() => window.__sent.filter((m) => m.type === "opening"));

const jpegSize = (f) => {
  const jpg = readFileSync(root + f);
  for (let i = 2; i < jpg.length;) {
    const marker = jpg[i + 1], len = jpg.readUInt16BE(i + 2);
    if (marker === 0xc0 || marker === 0xc2) return [jpg.readUInt16BE(i + 7), jpg.readUInt16BE(i + 5)];
    i += 2 + len;
  }
  return null;
};
test("fichiers : fond net 941 × 1673 (visuel fixe), bande animée 720 × 460 (lignes 620 à 1080 de la vidéo)", () => {
  assert.deepEqual(jpegSize(FOND), [941, 1673]);
  assert.deepEqual(jpegSize(STILL), [941, 1673]);
  const webp = readFileSync(root + ANIM);
  assert.equal(webp.toString("ascii", 8, 12), "WEBP");
  const vp8x = webp.indexOf("VP8X");
  assert.ok(vp8x > 0, "WebP étendu (animé)");
  const w = 1 + webp.readUIntLE(vp8x + 12, 3), h = 1 + webp.readUIntLE(vp8x + 15, 3);
  assert.deepEqual([w, h], [720, 460]);
});

test("sans réseau, l'animation rangée dans l'app s'affiche, la coque est prévenue, puis on passe à l'app", async () => {
  const page = await open({ colorScheme: "dark" });
  await page.waitForSelector("#op .op-zt");
  assert.match(await page.getAttribute("#op .op-bg", "src"), /^data:image\/jpeg/);
  assert.match(await page.getAttribute("#op .op-zt", "src"), /^data:image\/webp/);
  // Scène 9:16 entière à l'écran ; la bande animée tombe sur les lignes 620 à 1080 (sur 1280).
  const box = await page.$eval("#op .op-stage", (e) => e.getBoundingClientRect().toJSON());
  const zt = await page.$eval("#op .op-zt", (e) => e.getBoundingClientRect().toJSON());
  assert.ok(Math.abs(box.width / box.height - 720 / 1280) < 0.01, "format 9:16");
  assert.ok(box.width <= 393.5 && box.height <= 852.5, "entière à l'écran");
  assert.ok(Math.abs((zt.top - box.top) / box.height - 620 / 1280) < 0.003);
  assert.ok(Math.abs(zt.height / box.height - 460 / 1280) < 0.003);
  await page.waitForFunction(() => window.__sent.some((m) => m.type === "opening"));
  const [first] = await openings(page);
  assert.equal(first.state, "shown");
  assert.ok(first.at < 1500, "prévenue vite : " + Math.round(first.at) + " ms");
  // Fond rose même en mode sombre.
  assert.equal(await page.$eval("#op", (e) => getComputedStyle(e).backgroundColor === "rgb(248, 215, 226)"), true);
  await page.waitForSelector("#op", { state: "detached", timeout: 5000 });
  assert.equal((await openings(page)).length, 1, "un seul message");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("Réduire les animations : la première image, fixe, puis l'app", async () => {
  const page = await open({ reducedMotion: "reduce" });
  await page.waitForSelector("#op .op-bg");
  assert.match(await page.getAttribute("#op .op-bg", "src"), /^data:image\/jpeg/);
  assert.equal(await page.$("#op .op-zt"), null, "pas d'animation");
  await page.waitForFunction(() => window.__sent.some((m) => m.type === "opening"));
  assert.equal((await openings(page))[0].state, "shown");
  await page.waitForSelector("#op", { state: "detached", timeout: 3000 });
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("rien à afficher (ni app ni réseau) : la coque est prévenue et l'app s'ouvre, sans blocage", async () => {
  const page = await open({ assets: false });
  await page.waitForSelector("#op", { state: "detached", timeout: 3000 });
  const sent = await openings(page);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].state, "none");
  assert.deepEqual(page.errors, []);
  await page.close();
});
