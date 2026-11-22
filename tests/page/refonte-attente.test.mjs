// Refonte FOU-131 (validée par Victor le 23 nov.) : attente B (lilas) et vérification D (ambre), « Plus d'infos »,
// visite en 4 étapes (Départs, Arrivées, Pas en retour, Fans), aller-retour D → Découvrir → Mon export, petit iPhone.
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

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
async function open({ viewport = { width: 393, height: 852 }, colorScheme = "light", prefs = { requestedAt: ago(5) } } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion: "reduce", colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.addInitScript((p) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: 11, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, prefs);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(() => { window.zyeutoNotif({ status: "authorized" }); renderGuided(); });
  page.errors = errors;
  return page;
}
const unsure = { requestedAt: ago(3), requestUnsure: true, requestUnsureToday: true };
const gfText = (page) => page.evaluate(() => document.getElementById("gf").innerText);
const metaSent = (page) => page.evaluate(() => window.__sent.filter((m) => m.type === "meta"));

test("D : texte validé, ambre et point d'interrogation, jamais de coche ni « confirmée »", async () => {
  const page = await open({ prefs: unsure });
  assert.equal(await page.textContent("#gf-title"), "Vérifions ta demande");
  assert.equal(await page.textContent("#guide-say"), "Vérifie si ta demande apparaît dans Instagram. Tu n'as pas besoin de la refaire pour vérifier.");
  assert.match(await page.getAttribute("#gw-chip", "class"), /warn/);
  assert.equal(await page.textContent("#gw-chip i"), "?");
  const txt = await gfText(page);
  assert.doesNotMatch(txt, /✓|confirmée|Instagram a peut-être déjà/);
  assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll("#gw-fr li")].map((l) => l.className)), ["warn", "", ""]);
  // La vérification est l'action principale ; la découverte reste visible, en second.
  assert.match(await page.getAttribute("#gf-get", "class"), /cheer/);
  assert.equal(await page.textContent("#gf-get"), "Vérifier dans Instagram");
  assert.doesNotMatch(await page.getAttribute("#gf-wait-demo", "class"), /cheer/);
  assert.match(await page.textContent("#gf-wait-demo"), /Découvrir Zieuton en attendant/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("B : lilas avec la coche, « Découvrir Zieuton » en avant, « Compte fictif » au-dessus des 4 chiffres", async () => {
  const page = await open({ prefs: { requestedAt: ago(12) } });
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.equal(await page.textContent("#gw-chip i"), "✓");
  assert.match(await page.getAttribute("#gf-wait-demo", "class"), /cheer/);
  assert.doesNotMatch(await page.getAttribute("#gf-get", "class"), /cheer/);
  const fict = await page.locator(".gw-fict").boundingBox(), mini = await page.locator(".gw-mini").boundingBox();
  assert.equal(await page.textContent(".gw-fict"), "Compte fictif");
  assert.ok(fict.y + fict.height <= mini.y + 1, "« Compte fictif » au-dessus des chiffres");
  assert.match(await page.textContent(".gw-disc"), /compte fictif/);
  // Orange plus foncé derrière le texte blanc.
  assert.match(await page.evaluate(() => getComputedStyle(document.getElementById("gf-wait-demo")).backgroundImage), /rgb\(196, 73, 59\)/);
  await page.close();
});

test("« Plus d'infos » : « Rappel programmé » seulement si la coque dit qu'un rappel est vraiment prévu", async () => {
  const req = ago(12);
  const page = await open({ prefs: { requestedAt: req } });
  assert.equal(await page.isVisible("#gw-info"), false);
  await page.click("#gw-more");
  assert.equal(await page.isVisible("#gw-info"), true);
  let txt = await page.textContent("#gw-info");
  assert.doesNotMatch(txt, /Rappel programmé/);
  assert.match(txt, /Notifications autorisées/);
  assert.match(txt, /Un rappel ne veut pas dire que ton fichier est prêt/);
  await page.evaluate(() => window.zyeutoWatchInfo({ waiting: true, ready: false, reminders: 0 }));
  assert.doesNotMatch(await page.textContent("#gw-info"), /Rappel programmé/);
  await page.evaluate((r) => window.zyeutoWatchInfo({ waiting: true, ready: false, reminders: 2, requestedAt: r }), req);
  assert.equal(await page.isVisible("#gw-info"), true, "reste ouvert quand l'écran se redessine");
  txt = await page.textContent("#gw-info");
  assert.match(txt, /Rappel programmé/);
  // « Refaire la demande » est là, avec sa confirmation.
  await page.click("#gf-back");
  assert.match(await page.textContent("#gf-redo"), /doublon/);
  await page.click("#gf-redo-no");
  assert.ok(await page.evaluate(() => !!prefs.requestedAt));
  await page.click("#gw-info-x");
  assert.equal(await page.isVisible("#gw-info"), false);
  await page.close();
});

test("aller-retour D → Découvrir → visite → Mon export : on retrouve D, la demande à vérifier intacte, Instagram jamais ouvert", async () => {
  const page = await open({ prefs: unsure });
  const before0 = await page.evaluate(() => JSON.stringify({ r: prefs.requestedAt, u: prefs.requestUnsure }));
  await page.click("#gf-wait-demo");
  await page.waitForFunction(() => DEMO === true);
  assert.equal((await page.textContent("#demo-bar span:not(.demo-tag)")).trim(), "Compte fictif");
  assert.equal((await page.textContent("#demo-quit")).trim(), "Mon export");
  await page.waitForSelector("#dt", { timeout: 3000 });
  await page.click("#dt-next");
  await page.click("#dt-x");                                         // « Passer » : démo libre
  assert.equal(await page.locator("#dt").count(), 0);
  assert.equal(await page.evaluate(() => DEMO), true);
  await page.click("#demo-quit");                                    // « Mon export »
  await page.waitForFunction(() => DEMO === false);
  assert.equal(await page.textContent("#gf-title"), "Vérifions ta demande");
  assert.equal(await page.evaluate(() => JSON.stringify({ r: prefs.requestedAt, u: prefs.requestUnsure })), before0);
  assert.equal(await page.evaluate(() => reqPending()), true);
  assert.deepEqual(await metaSent(page), [], "Instagram ne s'ouvre jamais tout seul");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("visite : 4 étapes Départs → Arrivées → Pas en retour → Fans, « depuis l'import précédent », toucher la case = Suivant", async () => {
  const page = await open();
  await page.click("#gf-wait-demo");
  await page.waitForSelector("#dt", { timeout: 3000 });
  const want = [
    ["unfollow", "Les Départs", /depuis l'import précédent/],
    ["follow", "Les Arrivées", /depuis l'import précédent/],
    ["notback", "Les Pas en retour", /Tu les suis, mais eux ne te suivent pas/],
    ["fans", "Les Fans", /Ils te suivent, mais toi tu ne les suis pas/],
  ];
  for (let i = 0; i < 4; i++) {
    assert.equal(await page.textContent("#dt-tt"), want[i][1]);
    assert.match(await page.textContent("#dt-say"), want[i][2]);
    assert.equal(await page.textContent("#dt-n"), `Visite · ${i + 1} sur 4`);
    assert.equal(await page.locator(".dt-bars i.on").count(), i + 1);
    // L'exemple reprend les pseudos de la démo (ceux de la case).
    assert.match(await page.textContent("#dt-ex"), /Exemple fictif/);
    // La bulle ne cache pas la case entourée.
    const tile = await page.locator(`.hm-tile[data-list="${want[i][0]}"]`).boundingBox(), bub = await page.locator("#dt-bub").boundingBox();
    assert.ok(bub.y >= tile.y + tile.height - 1 || bub.y + bub.height <= tile.y + 1, `bulle ${i + 1} à côté de la case`);
    if (i < 3) await page.click(i % 2 ? "#dt-ring" : "#dt-next");
  }
  assert.equal(await page.textContent("#dt-next"), "Explorer la démo");
  assert.match(await page.textContent("#dt-end"), /^Retrouve le suivi de ta demande dans «\s?Mon export\s?»\.$/);
  assert.doesNotMatch(await page.textContent("#dt-bub"), /t'attend|est prêt/);
  await page.click("#dt-next");
  assert.equal(await page.locator("#dt").count(), 0);
  assert.equal(await page.evaluate(() => DEMO), true, "démo libre");
  assert.deepEqual(page.errors, []);
  await page.close();
});

// Petit iPhone (320 × 568, zoom d'affichage) et texte agrandi : rien de caché, tout s'atteint en défilant. La page a des
// tailles fixes (la « Taille du texte » d'iOS ne les change pas) : le texte agrandi revient à un écran 1,3 fois plus petit
// pour la même page, soit environ 246 × 437 points.
for (const [name, vp] of [["petit iPhone", { width: 320, height: 568 }], ["petit iPhone, texte agrandi", { width: 246, height: 437 }]]) {
  test(`${name} : actions principales, « Plus d'infos » et fin de visite atteignables`, async () => {
    const reach = async (page, sel) => {
      await page.locator(sel).scrollIntoViewIfNeeded();
      const b = await page.locator(sel).boundingBox();
      assert.ok(b && b.y >= 0 && b.y + b.height <= vp.height + 1 && b.x >= 0 && b.x + b.width <= vp.width + 1, `${sel} atteignable (${JSON.stringify(b)})`);
    };
    for (const prefs of [{ requestedAt: ago(5) }, unsure]) {
      const page = await open({ viewport: vp, prefs });
      for (const sel of ["#gf-get", "#gf-wait-demo", "#gw-more"]) await reach(page, sel);
      assert.ok(await page.evaluate(() => document.getElementById("gf").scrollWidth <= document.getElementById("gf").clientWidth), "pas de défilement de côté");
      await page.click("#gw-more");
      await reach(page, "#gf-back");
      await reach(page, "#gw-info-x");
      await page.close();
    }
    const page = await open({ viewport: vp });
    await page.click("#gf-wait-demo");
    await page.waitForSelector("#dt", { timeout: 3000 });
    for (let i = 0; i < 3; i++) await page.click("#dt-next");
    await reach(page, "#dt-next");
    await reach(page, "#dt-x");
    assert.equal(await page.textContent("#dt-next"), "Explorer la démo");
    await reach(page, "#demo-quit");
    assert.deepEqual(page.errors, []);
    await page.close();
  });
}
