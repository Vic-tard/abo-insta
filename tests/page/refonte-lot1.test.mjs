// Refonte visuelle, lot 1 puis V2 (23 nov.) : accueil, courbe des abonnés en tête des Graphiques, Zieuteur 3D des jeux, listes.
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

// La démo (compte fictif) : mêmes données que sur les captures avant/après.
async function demo({ viewport = { width: 393, height: 852 }, colorScheme = "light", reducedMotion = "reduce" } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion, colorScheme });
  await serveGuide(page);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    if (!localStorage.getItem("abo-prefs")) localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, demoTourDone: true }));
  });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(() => enterDemo());
  await page.waitForFunction(() => state.snapshots.length > 1);
  await page.evaluate(() => { document.getElementById("dt")?.remove(); if (typeof endDemoTour === "function") endDemoTour(); });
  page.errors = errors;
  return page;
}
const imgReady = (page, sel) => page.waitForFunction((s) => { const i = document.querySelector(s); return i && i.complete && i.naturalWidth > 0; }, sel, { timeout: 5000 });

test("accueil : date de l'import en premier, départs et arrivées en grand, et ils ouvrent leur liste", async () => {
  const page = await demo();
  const cap = await page.textContent("#caption");
  const { last, prev } = await page.evaluate(() => ({ last: fmtDate(state.snapshots.at(-1).takenAt), prev: fmtShort(state.snapshots.at(-2).takenAt) }));
  assert.match(cap, new RegExp(`Import du ${last}`));
  assert.match(cap, new RegExp(`comparé au ${prev}`));
  const s = await page.evaluate(() => state.snapshots.at(-1));
  assert.equal(await page.textContent("#st-down"), s.unfollows.toLocaleString("fr-FR"));
  assert.equal(await page.textContent("#st-up"), s.follows.toLocaleString("fr-FR"));
  const net = s.follows - s.unfollows;
  assert.equal(await page.textContent("#hh-net"), `${net > 0 ? "+" : net < 0 ? "−" : "±"}${Math.abs(net).toLocaleString("fr-FR")} au dernier import`);
  // La carte des chiffres passe avant « Mettre à jour » quand rien n'est en cours.
  const heroY = (await page.locator(".home-hero").boundingBox()).y, wkY = (await page.locator("#weekly").boundingBox()).y;
  assert.ok(heroY < wkY, "la carte des chiffres en premier");
  // Les cases disent la période de leur grand chiffre (depuis le premier import).
  const first = await page.evaluate(() => fmtShort(state.snapshots[0].takenAt));
  assert.equal(await page.textContent("#hs-unfollow"), `depuis le ${first}`);
  // « 11 départs » ouvre les départs de ce dernier import ; on peut passer à tous les départs.
  await page.click(".home-hero .stat.down");
  await page.waitForFunction(() => !document.getElementById("list-page").hidden);
  assert.equal(await page.textContent("#lp-title"), "Départs");
  assert.equal(await page.getAttribute('#lp-scope [data-scope="last"]', "aria-pressed"), "true");
  assert.equal(await page.locator("#people li.pp").count(), Math.min(40, s.unfollows));
  await page.click('#lp-scope [data-scope="all"]');
  const all = await page.evaluate(() => state.events.filter((e) => e.kind === "unfollow").length);
  assert.equal(await page.locator("#people li.pp").count(), Math.min(40, all));
  assert.ok(all > s.unfollows, "la liste complète en a plus");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("accueil : le Zieuteur 3D réagit au dernier import et rebondit au toucher", async () => {
  const page = await demo({ reducedMotion: "no-preference" });
  const s = await page.evaluate(() => state.snapshots.at(-1));
  const want = !s.unfollows && s.follows ? "saut" : s.follows > s.unfollows ? "clin" : s.unfollows > s.follows ? "surpris" : "neutre";
  assert.equal(await page.getAttribute("#hh-3d .zt-pose", "data-pose"), want);
  await imgReady(page, "#hh-3d img");
  // Dans la carte, derrière le panneau des chiffres : ses pattes (le 2ᵉ calque) dépassent sur le bord, pas plus.
  const z = await page.locator("#hh-3d").boundingBox(), card = await page.locator(".home-hero").boundingBox(), wall = await page.locator(".home-hero .stats").boundingBox();
  assert.ok(z.y > card.y && z.x + z.width <= card.x + card.width, "dans le cadre de la carte");
  assert.ok(z.y + z.height > wall.y && z.y + z.height - wall.y < 16, "pattes sur le bord du panneau");
  assert.equal(await page.locator("#hh-3d .zt-f img").count(), 1, "les pattes devant");
  await page.click("#hh-3d");
  assert.ok(await page.evaluate(() => document.querySelector("#hh-3d .zt-move").getAnimations().length > 0), "rebond");
  await page.close();
});

test("animations réduites : rien ne bouge au toucher du Zieuteur", async () => {
  const page = await demo({ reducedMotion: "reduce" });
  await page.click("#hh-3d");
  assert.equal(await page.evaluate(() => document.querySelector("#hh-3d .zt-move").getAnimations().length), 0);
  await page.close();
});

test("barre du bas : les 3 onglets ont leur nom, et le bas de la page n'est pas caché dessous", async () => {
  const page = await demo();
  const labels = await page.$$eval("#pager button span", (l) => l.map((s) => getComputedStyle(s).display !== "none" && s.textContent));
  assert.deepEqual(labels, ["Mini-jeux", "Accueil", "Graphiques"]);
  await page.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
  await page.waitForTimeout(100);
  const pager = await page.locator("#pager").boundingBox(), lastRow = await page.locator("#imp-row").boundingBox();
  assert.ok(lastRow.y + lastRow.height <= pager.y, "« Mes imports » au-dessus de la barre");
  await page.close();
});

for (const [name, viewport] of [["iPhone SE", { width: 375, height: 667 }], ["iPhone 15", { width: 393, height: 852 }]]) {
  for (const colorScheme of ["light", "dark"]) {
    test(`accueil lisible sans défiler : ${name}, ${colorScheme === "light" ? "clair" : "sombre"} (compte, date, départs, arrivées)`, async () => {
      const page = await demo({ viewport, colorScheme });
      const pager = await page.locator("#pager").boundingBox();
      for (const sel of ["#acct-pill", "#caption", ".home-hero .stat.down", ".home-hero .stat.up", "#st-count"]) {
        const b = await page.locator(sel).boundingBox();
        assert.ok(b && b.y >= 0 && b.y + b.height <= pager.y, `${sel} visible au-dessus de la barre`);
      }
      assert.deepEqual(page.errors, []);
      await page.close();
    });
  }
}

test("graphiques : la courbe en tête répond à une question, donne la période et lit chaque import au toucher", async () => {
  const page = await demo();
  await page.evaluate(() => setPage("stats"));
  await page.waitForSelector("#evo svg");
  assert.match(await page.textContent(".sh-q"), /Combien d'abonnés à chaque import/);
  const snaps = await page.evaluate(() => state.snapshots.map((s) => ({ c: s.count, f: s.follows, u: s.unfollows, d: fmtDate(s.takenAt), ds: fmtShort(s.takenAt) })));
  assert.match(await page.textContent(".evo-span"), new RegExp(`Du ${snaps[0].ds} au ${snaps.at(-1).ds} · ${snaps.length} imports`));
  // Par défaut : le dernier import.
  let read = await page.textContent("#evo-read");
  assert.ok(read.includes(snaps.at(-1).d) && read.includes(`${snaps.at(-1).c.toLocaleString("fr-FR")} abonnés`), read);
  // Toucher le 2e point : sa date, son nombre d'abonnés et son mouvement, comme dans « Mes imports ».
  const x = await page.evaluate(() => { const g = evoGeom(state.snapshots); return g.sx(g.xs[1]) / EVO.W; });
  const box = await page.locator("#evo").boundingBox();
  await page.mouse.click(box.x + box.width * x, box.y + box.height / 2);
  read = await page.textContent("#evo-read");
  const s = snaps[1];
  assert.ok(read.includes(s.d) && read.includes(`${s.c.toLocaleString("fr-FR")} abonnés`) && read.includes(`+${s.f.toLocaleString("fr-FR")} arrivée`) && read.includes(`−${s.u.toLocaleString("fr-FR")} départ`), read);
  assert.equal(await page.textContent("#evo-tip b"), s.c.toLocaleString("fr-FR"));
  // Au clavier : flèche gauche = import précédent.
  await page.focus("#evo"); await page.keyboard.press("ArrowLeft");
  assert.ok((await page.textContent("#evo-read")).includes("premier import"));
  // Le record a son repère ; l'ancienne carte « Record » ne fait plus doublon.
  assert.equal(await page.textContent(".evo-rec text"), "Record");
  assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById("g-evo-block")).display), "none");
  // Glisser le doigt ne sélectionne pas de texte (le surlignage bleu sur iPhone).
  assert.equal(await page.evaluate(() => getComputedStyle(document.querySelector("#st-hero")).userSelect), "none");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("graphiques : peu d'historique (1 import) et beaucoup d'imports (60) restent lisibles", async () => {
  const page = await demo();
  const one = await page.evaluate(() => evoHTML(state.snapshots.slice(0, 1)));
  assert.match(one, /commence à ton 2ᵉ import/);
  const many = await page.evaluate(() => {
    const base = state.snapshots.at(-1), t0 = Date.parse(base.takenAt);
    const snaps = Array.from({ length: 60 }, (_, i) => ({ ...base, count: 1000 + i * 7 - (i % 5) * 9, takenAt: new Date(t0 - (59 - i) * 7 * 864e5).toISOString() }));
    const d = document.createElement("div"); d.innerHTML = evoHTML(snaps);
    return { dots: d.querySelectorAll(".evo-dot").length, ticks: d.querySelectorAll(".evo-x").length, grid: d.querySelectorAll(".evo-grid").length };
  });
  assert.equal(many.dots, 0, "pas de points quand il y a beaucoup d'imports");
  assert.equal(many.ticks, 3);
  assert.ok(many.grid >= 2 && many.grid <= 6);
  await page.close();
});

test("jeu « Ça match ? » : le Zieuteur saute quand c'est juste, est choqué quand c'est raté, surpris quand le temps est écoulé", async () => {
  const page = await demo();
  await page.evaluate(() => { setPage("games"); document.getElementById("tile-back").click(); });
  await page.waitForSelector("#quiz-stage .zt-pose");
  const pose = () => page.getAttribute("#quiz-stage .zt-pose", "data-pose");
  assert.equal(await pose(), "malicieux");
  await page.click("#quiz-start");
  // Avant la réponse, Oui et Non ont exactement le même poids (même fond, même taille).
  const looks = await page.$$eval("#quiz-body .g-opt", (l) => l.map((b) => { const c = getComputedStyle(b), r = b.getBoundingClientRect(); return [c.backgroundColor, Math.round(r.width), Math.round(r.height)].join(); }));
  assert.equal(looks.length, 2); assert.equal(looks[0], looks[1]);
  await page.evaluate(() => document.querySelector(`#quiz-body .g-opt[data-a="${quiz.q.answer}"]`).click());
  assert.equal(await pose(), "saut");
  await page.click("#quiz-next");
  assert.equal(await pose(), "malicieux");
  await page.evaluate(() => [...document.querySelectorAll("#quiz-body .g-opt")].find((o) => o.dataset.a !== quiz.q.answer).click());
  assert.equal(await pose(), "choque");
  await page.click("#quiz-next");
  await page.evaluate(() => answer(null));
  assert.equal(await pose(), "surpris");
  // Le temps qui reste file sur le bord de la carte de la question.
  const bar = await page.locator("#quiz-ring").boundingBox(), card = await page.locator(".qz-card").boundingBox();
  assert.ok(bar.y >= card.y && bar.y < card.y + 30 && bar.width > card.width * 0.8);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("V2 : la police de Zieuton est chargée sans réseau, et les 4 cases ont chacune leur surface", async () => {
  const page = await demo();
  assert.ok(await page.evaluate(async () => { await document.fonts.ready; return document.fonts.check('600 20px "Zieuton Display"'); }), "police intégrée");
  const bgs = await page.$$eval("#hm-tiles .hm-tile", (l) => l.map((t) => getComputedStyle(t).backgroundImage));
  assert.equal(new Set(bgs).size, 4, "4 surfaces différentes");
  assert.deepEqual(page.errors, []);
  await page.close();
});
