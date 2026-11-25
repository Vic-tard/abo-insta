// FOU-124 : écran d'attente après la demande d'export. Aucune estimation de délai, aucune promesse de surveillance
// quand l'app est fermée, « Découvrir Zieuton » mis en avant, « Refaire la demande » protégé contre les doublons.
// Ouvre index.html dans Chromium (Playwright) comme dans l'app iPhone. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

async function waiting(mins, extra = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(([m, x]) => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, requestedAt: new Date(Date.now() - m * 60000).toISOString(), ...x }));
  }, [mins, extra]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
// Refonte FOU-131 : rappels, e-mail et « Refaire la demande » sont dans « Plus d'infos » : on l'ouvre avant de lire l'écran.
const openInfo = async (page) => { if (await page.isVisible("#gw-more") && !(await page.isVisible("#gw-info"))) await page.click("#gw-more"); };
const gfText = async (page) => { await openInfo(page); return page.evaluate(() => document.getElementById("gf").innerText); };

test("attente : pas d'estimation de délai ni de progression fixe", async () => {
  for (const mins of [1, 15, 200]) {
    const page = await waiting(mins);
    assert.equal(await page.textContent("#gf-title"), "Ton export se prépare");
    const txt = await gfText(page);
    assert.doesNotMatch(txt, /quelques minutes|en général|1 à 3 min|devrait être prête|sûrement prête/i);
    // Aucune barre de progression ni pourcentage.
    assert.equal(await page.locator("#gf [aria-valuenow], #gf [role=progressbar]").count(), 0);
    // Trois petits points animés à la place d'une barre (rien qui ressemble à une progression), dans l'étape en cours (FOU-131).
    assert.equal(await page.locator("#gw-fr li.now .gw-dots i").count(), 3);
    assert.doesNotMatch(txt, /%|reste \d|encore \d+ min/);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test("attente : on peut fermer l'app, sans promesse de surveillance en arrière-plan", async () => {
  const page = await waiting(5);
  const txt = await gfText(page);
  assert.match(txt, /Tu peux fermer l'app/);
  // C'est l'info qui avait manqué au test : elle est mise en avant, en premier.
  assert.match(await page.textContent("#gf .gw-tips li:first-child.gw-key"), /Tu peux fermer l'app/);
  assert.match(txt, /[àÀ] chaque ouverture de Zieuton/);
  assert.match(txt, /Quand Zieuton est fermé, je ne peux pas regarder chez Instagram/);
  assert.doesNotMatch(txt, /je guette|en continu|toutes les \d+ secondes|en permanence/i);
  await page.close();
});

test("demande déjà en cours : pas de « je guette »", async () => {
  const page = await waiting(5, { requestExisting: true });
  const txt = await gfText(page);
  assert.match(txt, /déjà en cours/);
  assert.doesNotMatch(txt, /je guette/i);
  await page.close();
});

test("FOU-131 : « Découvrir Zieuton » est le bouton principal, « Vérifier mon export » juste dessous, « Refaire la demande » est discret", async () => {
  const page = await waiting(5);
  // Refonte du 23 nov. (style « Bonbon prune » du 25 nov.) : un seul gros bouton prune (« Découvrir Zieuton »), puis « Vérifier mon export ».
  assert.equal(await page.locator("#gf .bb-go").count(), 1);
  assert.equal((await page.textContent("#gf-wait-demo")).trim(), "Découvrir Zieuton");
  assert.match(await page.getAttribute("#gf-wait-demo", "class"), /bb-go/);
  assert.equal((await page.textContent("#gf-get")).trim(), "Vérifier mon export");
  assert.doesNotMatch(await page.getAttribute("#gf-get", "class"), /bb-go/, "un seul bouton principal");
  const a = await page.locator("#gf-wait-demo").boundingBox(), b = await page.locator("#gf-get").boundingBox();
  assert.ok(b.y > a.y, "« Vérifier mon export » juste dessous");
  // « Refaire la demande » : dans « Plus d'infos », en lien discret.
  assert.equal(await page.isVisible("#gf-back"), false);
  await openInfo(page);
  assert.match(await page.getAttribute("#gf-back", "class"), /\balt\b/);
  await page.close();
});

test("« Refaire la demande » demande une confirmation : rien n'est effacé sans elle", async () => {
  const page = await waiting(5);
  const other = await page.evaluate(() => Object.keys(localStorage).filter((k) => k !== "abo-prefs").map((k) => k + "=" + localStorage.getItem(k)).sort());
  await openInfo(page);
  await page.click("#gf-back");
  assert.match(await page.textContent("#gf-redo"), /doublon/);
  let p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.ok(p.requestedAt, "la demande est toujours notée");
  // Le rafraîchissement de l'écran ne referme pas la confirmation.
  await page.evaluate(() => { const g = document.getElementById("gf-redo"); if (!g) throw new Error("absente"); });
  await page.click("#gf-redo-no");
  assert.equal(await page.locator("#gf-redo").count(), 0);
  assert.ok(await page.isVisible("#gf-back"));
  p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.ok(p.requestedAt, "« Non, j'attends » ne change rien");
  await page.click("#gf-back");
  await page.click("#gf-redo-yes");
  p = await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")));
  assert.equal(p.requestedAt, undefined, "confirmé : on peut refaire la demande");
  assert.match(await page.textContent("#gf-title"), /Zieuton en haut|On va chercher/);
  // Les autres données (imports, comptes…) ne bougent pas.
  const after2 = await page.evaluate(() => Object.keys(localStorage).filter((k) => k !== "abo-prefs").map((k) => k + "=" + localStorage.getItem(k)).sort());
  assert.deepEqual(after2, other);
  await page.close();
});

test("fichier vu prêt : écran E « Ton export est prêt » (téléchargement et import inchangés)", async () => {
  const page = await waiting(5);
  await page.evaluate(() => window.zyeutoMeta("ready"));
  assert.equal(await page.textContent("#gf-title"), "Ton export est prêt\u00a0! 🎉");
  assert.match(await page.textContent("#gf-get"), /Récupérer mon export/);
  assert.match(await gfText(page), /Touche toi-même «\s?Télécharger\s?»/);
  // Ce qui se passe vraiment après « Télécharger » : le fichier revient dans Zieuton, qui l'importe et le vérifie (aucun bouton à chercher).
  assert.match(await gfText(page), /Zieuton importe ton fichier/);
  assert.match(await gfText(page), /Ta liste s'affiche une fois le fichier vérifié/);
  assert.doesNotMatch(await gfText(page), /Je m'occupe du reste|toute seule/);
  // Refonte du 25 nov. : la pastille « Prêt chez Instagram » remplace la frise.
  assert.match(await page.textContent("#gw-chip"), /Prêt chez Instagram/);
  await page.close();
});

test("petit iPhone : le bouton principal reste atteignable, pas de défilement de côté", async () => {
  const page = await browser.newPage({ viewport: { width: 320, height: 568 }, locale: "fr-FR", reducedMotion: "reduce" });
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 9, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: () => {} } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, requestedAt: new Date(Date.now() - 5 * 60000).toISOString() }));
  });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  await page.evaluate(() => renderGuided());
  await page.locator("#gf-wait-demo").scrollIntoViewIfNeeded();
  assert.ok(await page.locator("#gf-wait-demo").isVisible());
  assert.ok(await page.evaluate(() => document.getElementById("gf").scrollWidth <= window.innerWidth));
  await page.close();
});

// Relecture FOU-124 : aucune navigation ordinaire ne peut effacer une demande en cours sans confirmation.
const stillAsked = (page) => page.evaluate(() => !!JSON.parse(localStorage.getItem("abo-prefs")).requestedAt);

test("première demande : pas de « Retour » sur l'attente, la demande ne peut pas s'effacer par là", async () => {
  const page = await waiting(5);
  assert.equal(await page.locator("#gf-backbtn").count(), 0);
  assert.ok(await stillAsked(page));
  await page.close();
});

test("nouvelle demande (comptes déjà importés) : « Fermer » garde la demande en cours", async () => {
  const page = await waiting(5);
  await page.evaluate(() => { gfRepeat = true; renderGuided(); });
  assert.match(await page.textContent("#gf-backbtn"), /Fermer/);
  await page.click("#gf-backbtn");
  assert.ok(await stillAsked(page), "Fermer n'efface pas la demande");
  assert.equal(await page.locator("#gf-redo").count(), 0);
  await page.close();
});

test("parcours sans Instagram dans l'app (ancienne coque) : « Refaire la demande » demande aussi confirmation", async () => {
  const page = await waiting(5);
  await page.evaluate(() => { window.ZYEUTO_APP.version = 1; renderGuided(); });
  await page.click("#gf-back");
  assert.match(await page.textContent("#gf-redo"), /doublon/);
  assert.ok(await stillAsked(page));
  await page.click("#gf-redo-no");
  assert.ok(await stillAsked(page));
  await page.close();
});

test("carte de la semaine : « Recommencer la demande », « Un souci ? › Recommencer » et la pastille Demander confirment d'abord", async () => {
  const page = await waiting(5);
  for (const go of [
    () => document.getElementById("wk-redo").click(),
    () => document.getElementById("sos-redo").click(),
    () => document.querySelector('#wk-steps li[data-step="request"]').click(),
  ]) {
    await page.evaluate(go);
    assert.match(await page.textContent("#gf-redo"), /doublon/);
    assert.ok(await stillAsked(page), "rien n'est effacé avant la confirmation");
    await page.click("#gf-redo-no");
    assert.equal(await page.locator("#gf-redo").count(), 0);
    assert.ok(await stillAsked(page));
  }
  // Confirmé : la demande est bien effacée (le chemin volontaire existe toujours).
  await page.evaluate(() => document.getElementById("wk-redo").click());
  await page.click("#gf-redo-yes");
  assert.equal(await stillAsked(page), false);
  assert.deepEqual(page.errors, []);
  await page.close();
});
