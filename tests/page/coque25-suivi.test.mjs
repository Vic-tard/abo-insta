// Coque 25 (25 nov., Victor) : suivi des exports. « Je reçois un rappel sur mon iPhone verrouillé, je le touche et Zieuton me
// montre où en est ma demande. »
// - une demande « à vérifier » est suivie aussi par la coque (reprise possible, rappels annoncés), puis confirmée sans changer d'heure ;
// - notification touchée (zyeutoMeta('check')) : la demande s'ouvre, « Vérification en cours… », puis le résultat de la vérification
//   avec l'heure, la raison connue et l'action utile (« Se reconnecter à Instagram », « Réessayer »…) ;
// - fichier vu prêt : « Récupérer mon export ». Instagram ne s'ouvre jamais tout seul.
// La coque elle-même (rappels 15 min / 1 h / 4 h / 24 h, toucher à froid) est testée dans tests/coque-notifications.test.mjs et,
// sur Mac, dans tests/ios/ExportProofTests.swift (cas 24, 25, 41). Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
async function open(prefs, { version = 12, viewport = { width: 393, height: 852 }, colorScheme = "light" } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion: "reduce", colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.addInitScript(([p, v]) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: v, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    if (p) localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, [prefs, version]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(() => { window.zyeutoNotif({ status: "authorized" }); renderAll(); renderGuided(); });
  page.errors = errors;
  return page;
}
const of = (page, type) => page.evaluate((t) => window.__sent.filter((m) => m.type === t), type);
const text = (page, sel) => page.evaluate((s) => document.querySelector(s)?.innerText || "", sel);
// Victor a déjà des imports : la demande se suit sur la carte de l'accueil. Un import d'il y a 2 h, puis une demande il y a `mins` min.
async function withImports(page, mins = 20, extra = {}) {
  await page.evaluate(async ([m, x]) => {
    const followers = {};
    for (let i = 0; i < 300; i++) followers["ami" + i] = 1700000000 + i;
    pending = { followers, following: null, date: new Date(Date.now() - 120 * 60000), dated: true, exact: true, source: "export.zip" };
    await commit(pending.date.toISOString());
    document.getElementById("first").hidden = true;
    Object.assign(prefs, { requestedAt: new Date(Date.now() - m * 60000).toISOString(), lastImportAt: new Date(Date.now() - 119 * 60000).toISOString() }, x);
    savePrefs(); window.__sent.length = 0; renderAll();
  }, [mins, extra]);
}

test("toucher un rappel (accueil, déjà des imports) : « Vérification en cours… », puis l'heure de la vérification", async () => {
  const page = await open({});
  await withImports(page);
  assert.equal(await text(page, "#weekly-title"), "Instagram prépare ta liste");
  await page.evaluate(() => { window.zyeutoMeta("home"); window.zyeutoMeta("check"); });
  assert.equal(await page.evaluate(() => page), "home");
  assert.match(await text(page, "#wk-state"), /^Vérification en cours…/);
  assert.match(await page.getAttribute("#wk-state", "class"), /busy/);
  // La coque dit qu'elle vérifie, puis le résultat.
  await page.evaluate(() => window.zyeutoWatch({ state: "checking", at: new Date().toISOString() }));
  assert.match(await text(page, "#wk-state"), /Vérification en cours…/);
  await page.evaluate(() => window.zyeutoWatch({ state: "pending", at: new Date().toISOString() }));
  assert.match(await text(page, "#wk-state"), /^✓ Vérifié à \d\d:\d\d\s:\spas encore prêt, Instagram le prépare\.$/);
  assert.equal(await page.locator("#wk-state-go").count(), 0, "rien à faire pendant qu'Instagram prépare");
  // « checking » n'efface pas le dernier résultat gardé.
  assert.equal(await page.evaluate(() => prefs.watch.state), "pending");
  assert.deepEqual(await of(page, "meta"), [], "Instagram ne s'ouvre jamais tout seul");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("vérification qui échoue : la raison et l'action utile", async () => {
  const page = await open({});
  await withImports(page);
  const cases = [
    ["login", /Instagram te demande de te reconnecter/, "Se reconnecter à Instagram"],
    ["offline", /Pas de connexion internet/, "Réessayer"],
    ["unknown", /Je n'ai pas pu lire ta liste chez Instagram/, "Réessayer"],
    ["toCheck", /Un fichier est disponible chez Instagram \(vérifié à \d\d:\d\d\)\. Vérifie sa date/, "Vérifier dans Instagram"],
  ];
  for (const [state, line, btn] of cases) {
    await page.evaluate((s) => window.zyeutoWatch({ state: s, at: new Date().toISOString() }), state);
    assert.match(await text(page, "#wk-state"), line);
    assert.equal((await page.textContent("#wk-state-go")).trim(), btn);
    const box = await page.locator("#wk-state-go").boundingBox();
    assert.ok(box.height >= 44, "bouton facile à toucher");
  }
  // « Se reconnecter à Instagram » ouvre la liste d'Instagram dans Zieuton (connexion faite là, par la personne).
  await page.evaluate(() => window.zyeutoWatch({ state: "login", at: new Date().toISOString() }));
  await page.click("#wk-state-go");
  const meta = await of(page, "meta");
  assert.equal(meta.length, 1);
  assert.equal(meta[0].mode, "get");
  // « Réessayer » : une vérification tout de suite, et « Vérification en cours… » sans attendre.
  await page.evaluate(() => { window.__sent.length = 0; window.zyeutoWatch({ state: "offline", at: new Date().toISOString() }); });
  await page.click("#wk-state-go");
  assert.deepEqual(await of(page, "notif"), [{ type: "notif", action: "check" }]);
  assert.match(await text(page, "#wk-state"), /Vérification en cours…/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("toucher « Ton export est prêt » : la carte dit « Récupérer mon export », Instagram ne s'ouvre pas tout seul", async () => {
  const page = await open({});
  await withImports(page);
  await page.evaluate(() => { window.zyeutoMeta("home"); window.zyeutoMeta("ready"); window.zyeutoMeta("check"); });
  assert.equal(await text(page, "#weekly-title"), "Ton export est prêt");
  assert.equal(await text(page, "#wk-go-t"), "Récupérer mon export");
  assert.equal(await page.isVisible("#wk-state-slot"), false, "plus de « Vérification en cours… » : c'est prêt");
  assert.deepEqual(await of(page, "meta"), []);
  // C'est la personne qui touche le bouton.
  await page.click("#wk-go");
  assert.equal((await of(page, "meta")).length, 1);
  await page.close();
});

test("toucher un rappel pendant la démo : retour aux vraies données, sur la demande", async () => {
  const page = await open({});
  await withImports(page);
  await page.evaluate(() => enterDemo());
  await page.waitForFunction(() => DEMO === true);
  await page.evaluate(() => { window.zyeutoMeta("home"); window.zyeutoMeta("check"); });
  await page.waitForFunction(() => DEMO === false);
  assert.equal(await text(page, "#weekly-title"), "Instagram prépare ta liste");
  assert.match(await text(page, "#wk-state"), /Vérification en cours…/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("parcours (premier export) : « Vérification en cours… » sur l'écran de la demande", async () => {
  const page = await open({ requestedAt: ago(20) });
  await page.evaluate(() => window.zyeutoMeta("check"));
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.match(await text(page, "#gw-state"), /Vérification en cours…/);
  await page.evaluate(() => window.zyeutoWatch({ state: "pending", at: new Date().toISOString() }));
  assert.match(await text(page, "#gw-state"), /✓ Vérifié à \d\d:\d\d/);
  await page.close();
});

test("« Vérifions ta demande » : suivie par la coque, rappels annoncés, résultat affiché", async () => {
  const req = ago(3);
  const page = await open({ requestedAt: req, requestUnsure: true, requestUnsureToday: true });
  assert.equal(await page.textContent("#gf-title"), "Vérifions ta demande");
  // La coque ne la suit pas (demande d'avant la coque 25) : la page demande une reprise « à vérifier », jamais « prouvée ».
  await page.evaluate(() => window.zyeutoWatchInfo({ waiting: false, ready: false, reminders: 0 }));
  assert.deepEqual(await of(page, "exportResume"), [{ type: "exportResume", acct: "a1", requestedAt: req, existing: false, today: false, proven: false, unsure: true }]);
  // La coque la suit avec des rappels enregistrés : « Rappel programmé ». Plus de « Pas encore de rappel ».
  await page.evaluate((r) => window.zyeutoWatchInfo({ waiting: true, ready: false, reminders: 4, unsure: true, requestedAt: r }), req);
  await page.click("#gw-more");
  const info = await text(page, "#gw-info");
  assert.match(info, /Rappel programmé/);
  assert.doesNotMatch(info, /Pas encore de rappel/);
  await page.click("#gw-info-x");
  await page.evaluate(() => window.zyeutoWatch({ state: "unknown", at: new Date().toISOString() }));
  assert.match(await text(page, "#gw-state"), /Je n'ai pas pu lire ta liste/);
  // Toujours ambre, jamais de coche ni « prêt ».
  assert.equal(await page.textContent("#gw-chip i"), "?");
  assert.equal(await page.evaluate(() => exportSeenReady()), false);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("demande « à vérifier » confirmée par Instagram : passe sur « Ton export se prépare », même heure de demande", async () => {
  const req = ago(7);
  const page = await open({ requestedAt: req, requestUnsure: true });
  await page.evaluate(() => window.zyeutoMeta("confirmed"));
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.equal(await page.textContent("#gw-chip i"), "✓");
  const p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.equal(p.requestedAt, req, "mêmes échéances : l'heure de la demande ne change pas");
  assert.equal(p.requestUnsure, undefined);
  assert.equal(await page.locator("#asked:not([hidden])").count(), 0, "pas d'écran « C'est demandé » rejoué");
  // Une demande déjà prouvée n'est jamais touchée.
  await page.evaluate(() => window.zyeutoMeta("confirmed"));
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")).requestedAt), req);
  await page.close();
});

test("démo ouverte quand la demande est confirmée : noté sur les vraies données", async () => {
  const page = await open({ requestedAt: ago(7), requestUnsure: true });
  await page.click("#gf-wait-demo");
  await page.waitForFunction(() => DEMO === true);
  await page.evaluate(() => window.zyeutoMeta("confirmed"));
  assert.equal(await page.evaluate(() => DEMO), true, "on reste dans la démo");
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")).requestUnsure), undefined);
  await page.click("#demo-quit");
  await page.waitForFunction(() => DEMO === false);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  await page.close();
});

test("ancienne coque (11) : rien ne change (pas de reprise « à vérifier », anciens textes)", async () => {
  const page = await open({ requestedAt: ago(3), requestUnsure: true }, { version: 11 });
  await page.evaluate(() => window.zyeutoWatchInfo({ waiting: false, ready: false, reminders: 0 }));
  assert.deepEqual(await of(page, "exportResume"), []);
  await page.click("#gw-more");
  assert.match(await text(page, "#gw-info"), /Pas encore de rappel/);
  await page.close();
});

for (const colorScheme of ["light", "dark"]) {
  test(`petit iPhone, ${colorScheme === "dark" ? "sombre" : "clair"} : ligne d'état et bouton lisibles, pas de défilement de côté`, async () => {
    const page = await open({}, { viewport: { width: 320, height: 568 }, colorScheme });
    await withImports(page);
    await page.evaluate(() => window.zyeutoWatch({ state: "login", at: new Date().toISOString() }));
    await page.locator("#wk-state-go").scrollIntoViewIfNeeded();
    const b = await page.locator("#wk-state-go").boundingBox();
    assert.ok(b.x >= 0 && b.x + b.width <= 320, "bouton entier à l'écran");
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));
    // Contraste : le texte de la ligne n'a pas la couleur du fond.
    const c = await page.$eval("#wk-state", (el) => [getComputedStyle(el).color, getComputedStyle(document.getElementById("weekly")).backgroundColor]);
    assert.notEqual(c[0], c[1]);
    assert.deepEqual(page.errors, []);
    await page.close();
  });
}
