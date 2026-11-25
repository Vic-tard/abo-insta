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
  assert.match(await page.textContent("#guide-say"), /^Regarde si elle apparaît dans Instagram\./);
  assert.match(await page.getAttribute("#gw-chip", "class"), /warn/);
  assert.equal(await page.textContent("#gw-chip i"), "?");
  const txt = await gfText(page);
  assert.doesNotMatch(txt, /✓|confirmée|Instagram a peut-être déjà/);
  assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll("#gw-fr li")].map((l) => l.className)), ["warn", "", ""]);
  // La vérification est l'action principale ; la découverte reste visible, en second.
  assert.match(await page.getAttribute("#gf-get", "class"), /bb-go/);
  assert.equal(await page.textContent("#gf-get"), "Vérifier dans Instagram");
  assert.doesNotMatch(await page.getAttribute("#gf-wait-demo", "class"), /bb-go/);
  assert.match(await page.textContent("#gf-wait-demo"), /Découvrir Zieuton en attendant/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("B : lilas avec la coche, « Découvrir Zieuton » en avant, allégé (25 nov.)", async () => {
  const page = await open({ prefs: { requestedAt: ago(12) } });
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.equal(await page.textContent("#gw-chip i"), "✓");
  assert.match(await page.getAttribute("#gf-wait-demo", "class"), /bb-go/);
  assert.doesNotMatch(await page.getAttribute("#gf-get", "class"), /bb-go/);
  // Allégé à la demande de Victor : plus d'aperçu « Compte fictif » ni de ligne d'info sous les boutons (elle est dans « Plus d'infos »).
  assert.equal(await page.locator(".gw-mini, .gw-disc, .gw-line").count(), 0);
  assert.match(await page.textContent("#guide-say"), /Tu n'as plus rien à faire/);
  // Texte crème sur prune : bien lisible.
  assert.equal(await page.evaluate(() => getComputedStyle(document.getElementById("gf-wait-demo")).backgroundColor), "rgb(69, 28, 49)");
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

test("visite : 4 étapes Départs → Arrivées → Pas en retour → Fans, le grand chiffre cumule les imports, toucher la case = Suivant", async () => {
  const page = await open();
  await page.click("#gf-wait-demo");
  await page.waitForSelector("#dt", { timeout: 3000 });
  const want = [
    // Le grand chiffre (61, 130) cumule tous les imports ; la ligne dessous (−11, +17) résume la dernière comparaison.
    ["unfollow", "Les Départs", /Le grand chiffre cumule tous tes imports ; la ligne en dessous résume la dernière comparaison\./],
    ["follow", "Les Arrivées", /Le grand chiffre cumule tous tes imports ; la ligne en dessous résume la dernière comparaison\./],
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
    assert.doesNotMatch(await page.textContent("#dt-say"), /depuis l'import précédent/);
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

// Glisser verticalement pendant la visite : le fond ne bouge pas, le cadre reste sur sa case ; la bulle défile seule
// sur petit écran ; le défilement normal revient dès la fin de la visite.
async function drag(page, x, y, dy) {
  // Molette (le vrai défilement de Chromium) + geste tactile : sur le voile, le geste est refusé (preventDefault).
  await page.mouse.move(x, y);
  await page.mouse.wheel(0, dy);
  await page.waitForTimeout(150);
  return page.evaluate(([x, y, dy]) => {
    const t = document.elementFromPoint(x, y), mk = (yy) => new Touch({ identifier: 1, target: t, clientX: x, clientY: yy });
    t.dispatchEvent(new TouchEvent("touchstart", { bubbles: true, cancelable: true, touches: [mk(y)], changedTouches: [mk(y)] }));
    const ev = new TouchEvent("touchmove", { bubbles: true, cancelable: true, touches: [mk(y - dy)], changedTouches: [mk(y - dy)] });
    t.dispatchEvent(ev);
    t.dispatchEvent(new TouchEvent("touchend", { bubbles: true, cancelable: true, touches: [], changedTouches: [mk(y - dy)] }));
    return ev.defaultPrevented;
  }, [x, y, dy]);
}
const aligned = async (page, list) => {
  const tile = await page.locator(`.hm-tile[data-list="${list}"]`).boundingBox(), ring = await page.locator("#dt-ring").boundingBox();
  return Math.abs(ring.x + 6 - tile.x) < 2 && Math.abs(ring.y + 6 - tile.y) < 2 && Math.abs(ring.height - 12 - tile.height) < 2;
};
for (const [name, vp] of [["iPhone 15", { width: 393, height: 852 }], ["petit iPhone, texte agrandi", { width: 246, height: 437 }]]) {
  test(`visite, ${name} : glisser sur le voile ne fait pas bouger le fond, le cadre reste aligné`, async () => {
    const page = await open({ viewport: vp });
    await page.click("#gf-wait-demo");
    await page.waitForSelector("#dt", { timeout: 3000 });
    const lists = ["unfollow", "follow", "notback", "fans"];
    for (let i = 0; i < 4; i++) {
      const y0 = await page.evaluate(() => scrollY);
      const bub = await page.locator("#dt-bub").boundingBox(), ring = await page.locator("#dt-ring").boundingBox();
      // Un point du voile, hors de la bulle et du cadre.
      const vy = bub.y > ring.y ? Math.min(vp.height - 4, bub.y + bub.height + 4) : Math.max(60, ring.y + ring.height + 4);
      const veilY = vy < vp.height - 2 && !(vy >= bub.y && vy <= bub.y + bub.height) ? vy : Math.max(bub.y + bub.height + 2, ring.y + ring.height + 2);
      for (const dy of [300, -300]) {
        const blocked = await drag(page, 4, Math.min(veilY, vp.height - 3), dy);
        assert.equal(blocked, true, "le geste sur le voile est bloqué");
        assert.equal(await page.evaluate(() => scrollY), y0, `étape ${i + 1} : le fond ne défile pas (${dy})`);
        assert.ok(await aligned(page, lists[i]), `étape ${i + 1} : le cadre reste sur sa case`);
      }
      // Bulle trop haute (petit écran) : elle défile, elle, sans entraîner la page.
      const tall = await page.evaluate(() => { const b = document.getElementById("dt-bub"); return b.scrollHeight > b.clientHeight + 1; });
      if (tall) {
        const b = await page.locator("#dt-bub").boundingBox();
        assert.equal(await drag(page, b.x + b.width / 2, b.y + b.height / 2, 200), false, "dans la bulle, le geste passe");
        assert.ok(await page.evaluate(() => document.getElementById("dt-bub").scrollTop) > 0, "la bulle défile");
        assert.equal(await page.evaluate(() => scrollY), y0, "la page, elle, ne bouge pas");
      }
      if (i < 3) await page.click("#dt-next");
    }
    if (vp.height < 500) assert.ok(true);
    await page.locator("#dt-next").scrollIntoViewIfNeeded();
    await page.click("#dt-next");
    assert.equal(await page.locator("#dt").count(), 0);
    // Fin de visite : la page défile de nouveau normalement.
    await page.evaluate(() => scrollTo(0, 0));
    await page.mouse.move(vp.width / 2, vp.height / 2);
    await page.mouse.wheel(0, 300);
    await page.waitForTimeout(200);
    assert.ok(await page.evaluate(() => scrollY) > 0, "défilement normal après la visite");
    assert.equal(await page.evaluate(() => document.documentElement.classList.contains("dt-lock") || document.body.classList.contains("dt-on")), false);
    assert.deepEqual(page.errors, []);
    await page.close();
  });
}
