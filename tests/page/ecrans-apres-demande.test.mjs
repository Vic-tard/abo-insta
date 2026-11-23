// FOU-131 : écrans après la demande d'export (A « C'est parti ! », B « Ton export se prépare », D « Vérifions ta demande »,
// E « Ton export est prêt »). Relecture ChatGPT du 21 nov. : A vraiment visible au retour d'Instagram, jamais rejoué ;
// B lisible sans défiler (titre, frise, « Découvrir Zieuton », « Vérifier mon export »), petit iPhone et mode sombre compris.
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

async function open({ viewport = { width: 393, height: 852 }, colorScheme = "light", prefs = {}, status = "authorized" } = {}) {
  const page = await browser.newPage({ viewport, locale: "fr-FR", reducedMotion: "reduce", colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  page.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
  await page.addInitScript(([p, st]) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: 10, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => {
      window.__sent.push(m);
      if (m.type === "notif" && m.action === "status" && st) setTimeout(() => window.zyeutoNotif && window.zyeutoNotif({ status: st }), 0);
    } } } };
    // Visibilité pilotable : comme quand Instagram est affiché par-dessus Zieuton dans l'app.
    let vis = "visible";
    Object.defineProperty(document, "visibilityState", { configurable: true, get: () => vis });
    window.__setVisible = (v) => { vis = v ? "visible" : "hidden"; document.dispatchEvent(new Event("visibilitychange")); };
    if (!localStorage.getItem("abo-prefs")) localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, ...p }));
  }, [prefs, status]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
const askedShown = (page) => page.evaluate(() => !document.getElementById("asked").hidden);
const prefsOf = (page) => page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));

test("A : demande prouvée pendant qu'Instagram est par-dessus → A s'affiche au retour dans Zieuton, une seule fois", async () => {
  const page = await open();
  await page.click("#gf-meta");                                   // « Continuer » (écran des 3 étapes)
  await page.click("#gf-meta");                                   // « Ouvrir Instagram » (écran Zieuton en haut) : Instagram s'ouvre par-dessus
  await page.evaluate(() => window.__setVisible(false));
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  assert.equal(await askedShown(page), false, "pas de fête derrière Instagram");
  // Retour dans Zieuton (‹ Zieuton ou « Revenir dans Zieuton »).
  await page.evaluate(() => window.__setVisible(true));
  assert.equal(await askedShown(page), true, "A est visible au retour");
  const a = await page.evaluate(() => document.getElementById("asked").innerText);
  assert.match(a, /Demande confirmée ✓/);
  assert.match(a, /Bien joué\s! Instagram prépare ta liste d'abonnés\./);
  assert.match(a, /Tu as terminé les étapes chez Instagram\. Je t'explique la suite\s!/);
  assert.equal(await page.locator("#asked button").count(), 1, "un seul bouton");
  assert.equal(await page.textContent("#asked-go"), "Continuer dans Zieuton");
  // Instagram rouvert puis refermé (« Vérifier mon export ») : A n'est pas rejoué.
  await page.click("#asked-go");
  assert.equal(await askedShown(page), false);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.deepEqual(await page.evaluate(() => [...document.querySelectorAll("#gw-fr li")].map((l) => l.className)), ["ok", "now", ""]);
  await page.evaluate(() => { window.__setVisible(false); window.__setVisible(true); });
  assert.equal(await askedShown(page), false, "pas de double confirmation");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("A : si iOS ne cache pas la page derrière Instagram, A est déjà là au retour et y reste jusqu'au bouton", async () => {
  const page = await open();
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  assert.equal(await askedShown(page), true);
  // Notification « C'est demandé » touchée pendant ce temps : A reste ouvert.
  await page.evaluate(() => window.zyeutoMeta("home"));
  assert.equal(await askedShown(page), true);
  await page.close();
});

test("A n'est jamais rejoué à la réouverture de l'app : on retrouve B", async () => {
  let page = await open();
  await page.evaluate(() => window.__setVisible(false));
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  // App fermée avant le retour : la demande est notée, A ne l'est pas. On relance l'app avec les réglages enregistrés
  // (une nouvelle page plutôt que page.reload() : en file://, Chromium chargé rend parfois un stockage vide au rechargement).
  const saved = await prefsOf(page);
  await page.close();
  page = await open({ prefs: saved });
  assert.equal(await askedShown(page), false);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.ok((await prefsOf(page)).requestedAt);
  await page.close();
});

test("A seulement sur une demande prouvée : ni demande déjà en cours, ni « à vérifier », ni fichier déjà vu prêt", async () => {
  for (const [ev, info, title] of [
    ["requested", { existing: true, today: true }, "Ton export se prépare"],
    ["requested", { existing: true, today: false }, "Ton export se prépare"],
    ["unsure", { today: true }, "Vérifions ta demande"],
  ]) {
    const page = await open();
    await page.evaluate(([e, i]) => window.zyeutoMeta(e, i), [ev, info]);
    assert.equal(await askedShown(page), false, `${ev} ${JSON.stringify(info)}`);
    assert.equal(await page.textContent("#gf-title"), title);
    await page.close();
  }
  // Demande déjà en cours : étape 1 « Demande trouvée chez Instagram », jamais « Demande confirmée ».
  const page = await open();
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: true, today: true }));
  const fr = await page.textContent("#gw-fr");
  assert.match(fr, /Demande trouvée chez Instagram/);
  assert.doesNotMatch(fr, /Demande confirmée/);
  await page.close();
});

test("D puis vérification réussie : B sans A, avec « Demande trouvée chez Instagram »", async () => {
  const page = await open();
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  assert.equal(await page.textContent("#gf-get"), "Vérifier dans Instagram");
  await page.click("#gf-get");
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: true, today: true }));
  assert.equal(await askedShown(page), false);
  assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
  assert.match(await page.textContent("#gw-fr"), /Demande trouvée chez Instagram/);
  assert.match(await page.textContent("#guide-say"), /Une demande d'aujourd'hui est en cours chez Instagram/);
  await page.close();
});

test("fichier vu prêt pendant que A attend : E passe devant, A est refermé", async () => {
  const page = await open();
  await page.evaluate(() => window.__setVisible(false));
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  await page.evaluate(() => window.zyeutoMeta("ready"));
  await page.evaluate(() => window.__setVisible(true));
  assert.equal(await askedShown(page), false);
  assert.equal(await page.textContent("#gf-title"), "Ton export est prêt ! 🎉");
  await page.close();
});

test("B : rappels honnêtes, aucun délai ni pourcentage", async () => {
  const page = await open({ prefs: { requestedAt: new Date(Date.now() - 12 * 60000).toISOString() } });
  await page.click("#gw-more");                                   // refonte FOU-131 : les rappels sont dans « Plus d'infos »
  const txt = await page.evaluate(() => document.getElementById("gf").innerText);
  assert.match(txt, /Instagram prépare ton fichier\. Demandé il y a 12 min\./);
  assert.match(txt, /Un rappel ne veut pas dire que ton fichier est prêt/);
  assert.match(txt, /Demandé il y a 12 min/);
  assert.doesNotMatch(txt, /\d+\s?%|il reste|prêt dans|quelques minutes|en permanence|en continu/i);
  await page.close();
});

// Point 3 de la relecture : sans défiler, titre + frise + les deux boutons. Petit iPhone (SE), iPhone 15, mode sombre,
// et l'iPhone en « Zoom d'affichage » (écran vu comme un 320 points de large). La page utilise des tailles fixes :
// la « taille du texte » d'iOS ne change pas ses polices (comportement actuel, pas changé par FOU-131).
for (const [name, viewport] of [["iPhone SE (2e/3e gén.)", { width: 375, height: 667 }], ["iPhone 15", { width: 393, height: 852 }], ["petit iPhone / zoom d'affichage", { width: 320, height: 568 }]]) {
  for (const colorScheme of ["light", "dark"]) {
    test(`B sans défiler : ${name}, ${colorScheme === "dark" ? "sombre" : "clair"}`, async () => {
      const page = await open({ viewport, colorScheme, prefs: { requestedAt: new Date(Date.now() - 5 * 60000).toISOString() } });
      const vh = viewport.height;
      for (const sel of ["#gf-title", "#gw-fr", "#gf-wait-demo", "#gf-get"]) {
        const b = await page.locator(sel).boundingBox();
        assert.ok(b, sel);
        assert.ok(b.y >= 0 && b.y + b.height <= vh, `${sel} visible sans défiler (bas à ${Math.round(b.y + b.height)} pour ${vh})`);
      }
      // Rien ne déborde sur le côté.
      assert.equal(await page.evaluate(() => document.getElementById("gf").scrollWidth <= document.getElementById("gf").clientWidth), true);
      // Les rappels et « Refaire la demande » restent atteignables : « Plus d'infos » en défilant, puis dans la feuille.
      await page.locator("#gw-more").scrollIntoViewIfNeeded();
      await page.click("#gw-more");
      await page.locator("#gf-back").scrollIntoViewIfNeeded();
      assert.ok(await page.isVisible("#gf-back"));
      assert.deepEqual(page.errors, []);
      await page.close();
    });
  }
}

test("D sans défiler sur petit iPhone : titre, frise et « Vérifier dans Instagram »", async () => {
  const page = await open({ viewport: { width: 320, height: 568 } });
  await page.evaluate(() => window.zyeutoMeta("unsure", { today: true }));
  for (const sel of ["#gf-title", "#gw-fr", "#gf-get"]) {
    const b = await page.locator(sel).boundingBox();
    assert.ok(b.y >= 0 && b.y + b.height <= 568, `${sel} (bas à ${Math.round(b.y + b.height)})`);
  }
  await page.close();
});

test("A sur petit iPhone, en sombre : tout le texte et le bouton tiennent dans l'écran", async () => {
  const page = await open({ viewport: { width: 320, height: 568 }, colorScheme: "dark" });
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false, today: false }));
  const b = await page.locator("#asked-go").boundingBox();
  assert.ok(b.y + b.height <= 568, `bouton (bas à ${Math.round(b.y + b.height)})`);
  const t = await page.locator("#asked-t").boundingBox();
  assert.ok(t.y >= 0);
  assert.deepEqual(page.errors, []);
  await page.close();
});
