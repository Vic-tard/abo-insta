// FOU-121 P6 : chemin de secours par l'app Instagram officielle. Ouvre index.html dans Chromium (Playwright)
// comme dans l'app iPhone. Lancer : npm run test:lecteur.
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

// La page dans une fausse coque. `prefs` : réglages de départ. Les messages envoyés à la coque sont gardés dans window.sent.
async function app(prefs, viewport = { width: 393, height: 852 }) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion: "reduce" });
  await serveGuide(page);
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript((p) => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.sent = [];
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.sent.push(m) } } };
    localStorage.setItem("abo-prefs", JSON.stringify(p));
  }, prefs);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && typeof openViaApp === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
// Visible : présent, pas caché, et ni lui ni ses parents en display:none (les écrans plein écran sont en position fixe).
const vis = (page, id) => page.evaluate((i) => { const e = document.getElementById(i); return !!e && e.getClientRects().length > 0 && getComputedStyle(e).visibility !== "hidden"; }, id);
const say = (page) => page.evaluate(() => document.getElementById("va-title")?.textContent || "");

test("le plan propose « Passer par l'app Instagram », qui ouvre le chemin de secours", async () => {
  const page = await app({ welcomed: true });
  assert.ok(await vis(page, "gf-via"), "lien visible sur le plan");
  await page.click("#gf-via");
  assert.ok(await vis(page, "va"));
  assert.match(await say(page), /app Instagram/);
  const txt = await page.evaluate(() => document.getElementById("va").innerText);
  assert.match(txt, /Espace Comptes/);
  assert.match(txt, /Exporter vos informations/);
  assert.match(txt, /Ne le donne jamais/);
  // Si le bouton ouvre Safari : comment ouvrir l'app Instagram à la main. Et aucune promesse « pas d'alerte ».
  assert.ok(await vis(page, "va-manual"));
  assert.match(await page.textContent("#va-manual"), /ouvre Safari/);
  assert.match(await page.textContent("#va-manual"), /écran d'accueil/);
  assert.match(txt, /Instagram demande une vérification/);
  assert.doesNotMatch(txt, /pas d'alerte|aucune alerte|sans alerte/i);
  // Bouton vers l'app Instagram officielle, jamais un mot de passe ni un code demandé.
  assert.equal(await page.getAttribute("#va-open", "href"), "https://www.instagram.com/");
  assert.equal(await page.locator("#va input").count(), 0, "aucun champ à remplir");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("l'écran avant Instagram (après un blocage, par exemple) propose aussi l'app Instagram", async () => {
  const page = await app({ welcomed: true });
  await page.click("#gf-meta"); // « Continuer » sur le plan → écran « Zieuton en haut, Instagram en bas »
  assert.match(await page.textContent("#gf-title"), /Zieuton en haut/);
  assert.ok(await vis(page, "gf-via"));
  await page.click("#gf-via");
  assert.ok(await vis(page, "va"));
  // Rien n'a été envoyé à la coque : on n'ouvre pas Instagram dans Zieuton.
  assert.equal(await page.evaluate(() => window.sent.filter((m) => m.type === "meta").length), 0);
  await page.close();
});

test("les captures défilent une à une, et la demande n'est jamais notée comme faite", async () => {
  const page = await app({ welcomed: true });
  await page.evaluate(() => openViaApp());
  await page.click("#va-next");
  assert.match(await say(page), /Créer une exportation/);
  assert.match(await page.getAttribute("#va-fig img", "src"), /guide\/ig-01\.jpg$/);
  const n = await page.evaluate(() => IG_SHOTS.length);
  for (let k = 1; k < n; k++) await page.click("#va-next");
  assert.match(await say(page), /Commencer l'exportation/);
  assert.equal(await page.textContent("#va-next"), "C'est demandé");
  await page.click("#va-next");
  assert.match(await say(page), /quand c'est prêt/);
  assert.ok(await vis(page, "va-file"));
  // Le rappel pour ouvrir l'app à la main est aussi là au moment de télécharger.
  assert.match(await page.evaluate(() => document.getElementById("va").innerText), /depuis l'écran d'accueil si le bouton ouvre Safari/);
  // Zieuton ne voit pas ce qui se passe dans l'app Instagram : pas de « demandé », pas de guet.
  const p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.equal(p.requestedAt, undefined);
  assert.equal(await page.evaluate(() => reqPending()), false);
  await page.click("#va-prev");
  assert.match(await say(page), /Commencer l'exportation/);
  await page.close();
});

test("refermé puis rouvert : on reprend à la même capture", async () => {
  const page = await app({ welcomed: true });
  await page.evaluate(() => openViaApp());
  await page.click("#va-next"); await page.click("#va-next"); await page.click("#va-next");
  const at = await say(page);
  await page.click("#va-x");
  assert.equal(await vis(page, "va"), false);
  // Le parcours guidé est toujours là dessous, la page reste bloquée.
  assert.ok(await vis(page, "gf"));
  assert.equal(await page.evaluate(() => document.documentElement.style.overflow), "hidden");
  await page.evaluate(() => openViaApp());
  assert.equal(await say(page), at);
  await page.close();
});

test("après 5 jours, on reprend au début (Instagram ne garde le fichier que 4 jours)", async () => {
  const page = await app({ welcomed: true, viaApp: { step: 6, at: Date.now() - 6 * 864e5 } });
  await page.evaluate(() => openViaApp());
  assert.match(await say(page), /Fais ta demande/);
  await page.close();
});

test("« Choisir mon fichier » referme et ouvre le choix du fichier", async () => {
  const page = await app({ welcomed: true, viaApp: { step: 99, at: Date.now() } });
  await page.evaluate(() => { window.picked = 0; document.getElementById("file").click = () => { window.picked++; }; openViaApp(); });
  assert.match(await say(page), /quand c'est prêt/);
  await page.click("#va-file");
  assert.equal(await page.evaluate(() => window.picked), 1);
  assert.equal(await vis(page, "va"), false);
  await page.close();
});

test("petit iPhone : le bouton de la suite reste atteignable", async () => {
  const page = await app({ welcomed: true }, { width: 320, height: 568 });
  await page.evaluate(() => openViaApp());
  await page.click("#va-next");
  await page.locator("#va-next").scrollIntoViewIfNeeded();
  assert.ok(await page.locator("#va-next").isVisible());
  const wide = await page.evaluate(() => document.getElementById("va").scrollWidth <= window.innerWidth);
  assert.ok(wide, "pas de défilement horizontal");
  await page.close();
});
