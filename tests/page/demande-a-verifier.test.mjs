// FOU-126, relecture ChatGPT du 18 nov. (14 h 09) : plus de boucle « Zieuton en haut, Instagram en bas » → « J'ai compris, on y va ».
// Instagram fermé avec une demande possible mais pas prouvée : la coque envoie « unsure », la page passe directement sur une attente
// honnête « Demande à vérifier ». Une coque plus ancienne n'envoie jamais « unsure » : rien ne change pour elle.
// Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
import { execSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function open({ version = 10, prefs = {} } = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(([v, p]) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: v, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, [version, prefs]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
const gfText = (page) => page.evaluate(() => document.getElementById("gf").innerText);
const sent = (page) => page.evaluate(() => window.__sent);
const prefsOf = (page) => page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));

// Jusqu'à l'écran « Zieuton en haut, Instagram en bas », puis Instagram (comme dans la vidéo du 18 nov.).
async function toInstagram(page) {
  await page.click("#gf-meta");                                   // « Ouvrir Instagram »
  assert.match(await gfText(page), /Zieuton en haut/);
  await page.click("#gf-meta");                                   // « J'ai compris, on y va »
  const metas = (await sent(page)).filter((m) => m.type === "meta");
  assert.equal(metas.at(-1).mode, "request");
}

test("retour d'Instagram sans preuve, ligne du jour vue : attente « Demande à vérifier », jamais « Zieuton en haut »", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  const txt = await gfText(page);
  assert.doesNotMatch(txt, /Zieuton en haut|J'ai compris, on y va/, "plus de boucle vers l'écran d'avant Instagram");
  assert.match(txt, /Demande à vérifier/);
  assert.match(txt, /Vérifie la demande, sans la refaire/);
  assert.match(txt, /demande d'aujourd'hui chez Instagram, sans pouvoir confirmer que c'est la tienne/);
  assert.match(txt, /Ne refais rien/);
  assert.doesNotMatch(txt, /C'est demandé|Bravo|Instagram prépare ta liste|Rappel activé|Ta liste est prête/, "aucune preuve inventée, aucune promesse");
  assert.equal(await page.evaluate(() => document.getElementById("asked").hidden), true, "pas de fenêtre « C'est demandé »");
  const p = await prefsOf(page);
  assert.equal(p.requestUnsure, true);
  assert.ok(p.requestedAt, "l'attente est notée, pour ne pas proposer une nouvelle demande");
  assert.equal(p.requestExisting, undefined);
  assert.equal(p.readyAt, undefined);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("« Demande à vérifier » sans ligne du jour : texte neutre", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: false }));
  const txt = await gfText(page);
  assert.match(txt, /Je n'ai pas pu confirmer ta demande chez Instagram/);
  assert.doesNotMatch(txt, /demande d'aujourd'hui/);
  await page.close();
});

test("« Vérifier dans Instagram » rouvre la liste en mode demande, sans refaire tout le parcours", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  assert.equal(await page.textContent("#gf-get"), "Vérifier dans Instagram");
  const before = (await sent(page)).length;
  await page.click("#gf-get");
  const after = (await sent(page)).slice(before).filter((m) => m.type === "meta");
  assert.equal(after.length, 1);
  assert.equal(after[0].mode, "request", "Instagram s'ouvre sur la liste : la coque reconnaît la demande déjà là");
  assert.doesNotMatch(await gfText(page), /Zieuton en haut/, "pas d'écran intermédiaire");
  await page.close();
});

test("la coque reconnaît ensuite la demande : « Demande à vérifier » disparaît", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  await page.click("#gf-get");
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: true, today: true }));
  const txt = await gfText(page);
  assert.doesNotMatch(txt, /Demande à vérifier/);
  assert.match(txt, /Une demande d'aujourd'hui est en cours/);
  const p = await prefsOf(page);
  assert.equal(p.requestUnsure, undefined);
  assert.equal(p.requestUnsureToday, undefined);
  assert.equal(p.requestToday, true);
  await page.close();
});

test("une demande déjà prouvée n'est jamais rétrogradée en « à vérifier »", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  assert.doesNotMatch(await gfText(page), /Demande à vérifier/);
  assert.equal((await prefsOf(page)).requestUnsure, undefined);
  await page.close();
});

test("« Refaire la demande » efface aussi « à vérifier »", async () => {
  const page = await open();
  await toInstagram(page);
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: false }));
  await page.click("#gf-back");
  await page.click("#gf-redo-yes");
  const p = await prefsOf(page);
  assert.equal(p.requestUnsure, undefined);
  assert.equal(p.requestedAt, undefined);
  await page.close();
});

test("ancienne coque (aucun évènement « unsure ») : comportement inchangé, aucune erreur", async () => {
  for (const version of [9, 10]) {
    const page = await open({ version });
    await toInstagram(page);
    // Instagram fermé : une ancienne coque n'envoie rien. La page reste où elle était, sans attente inventée.
    await page.evaluate(() => renderGuided());
    assert.match(await gfText(page), /Zieuton en haut/, `coque ${version} : même écran qu'avant`);
    assert.equal((await prefsOf(page)).requestedAt, undefined, `coque ${version} : aucune demande notée sans signe de la coque`);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test("page de main (plus ancienne) : l'évènement « unsure » est ignoré sans erreur, la coque peut l'envoyer sans risque", async () => {
  // La page en ligne sur le canal stable ne connaît pas « unsure ». On la reprend telle quelle depuis main.
  let old;
  try { old = execSync("git show origin/main:index.html", { cwd: root, encoding: "utf8", maxBuffer: 64 << 20 }); }
  catch (e) { console.log("main introuvable (copie sans historique) : test sauté", e.message); return; }
  const dir = mkdtempSync(join(tmpdir(), "zieuton-main-"));
  writeFileSync(join(dir, "index.html"), old);
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 10, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true }));
  });
  await page.goto("file://" + join(dir, "index.html"));
  await page.waitForFunction(() => typeof window.zyeutoMeta === "function");
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")).requestedAt), undefined, "rien n'est noté");
  assert.deepEqual(errors, []);
  await page.close();
});
