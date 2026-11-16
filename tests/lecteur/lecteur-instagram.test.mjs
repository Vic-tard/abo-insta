// FOU-121 : teste le script qui lit les écrans d'Instagram (bloc LECTEUR-INSTAGRAM de WebViewController.swift)
// sur des pages reconstituées (tests/lecteur/pages). Il faut Playwright et Chromium : npm run test:lecteur.
// Ces pages imitent les textes d'Instagram ; elles ne prouvent pas que les vrais écrans sont reconnus (test sur iPhone obligatoire).
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
const swift = readFileSync(root + "ios/Zieuton/WebViewController.swift", "utf8");
const m = swift.match(/static let readerJS = #"""\n([\s\S]*?)\n\s*"""#/);
if (!m) throw new Error("bloc readerJS introuvable dans WebViewController.swift");
const COUNT = swift.match(/static let countScript = """\n([\s\S]*?)\n\s*"""/)[1].replace(/\\\n/g, "\n");
const READER = m[1]
  .replace("__START__", JSON.stringify(["commencer l'exportation", "start export"]))
  .replace("__CREATE__", JSON.stringify(["créer une exportation", "create export"]))
  .replace("__DL__", COUNT);

let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

// Ouvre une page reconstituée, pose le script comme l'app, et rend le dernier état envoyé.
async function stateOf(name) {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.addInitScript(() => {
    window.__sent = [];
    const h = (n) => ({ postMessage: (b) => window.__sent.push({ n, b }) });
    window.webkit = { messageHandlers: { zyeutoState: h("state"), zyeutoTap: h("tap"), zyeutoRing: h("ring") } };
  });
  await page.goto("file://" + root + "tests/lecteur/pages/" + name);
  await page.evaluate(READER);
  await page.waitForFunction(() => window.__sent.some((x) => x.n === "state"), null, { timeout: 3000 });
  const st = await page.evaluate(() => window.__sent.filter((x) => x.n === "state").pop().b);
  await page.close();
  return st;
}

test("accueil vide : aucune ligne en attente, pas de verrou", async () => {
  const s = await stateOf("accueil-vide.html");
  assert.equal(s.create, true);
  assert.deepEqual(s.rows, []);
  assert.equal(s.locked, "");
  assert.equal(s.screen, "home");
});

test("accueil avec une demande en attente et un ancien export prêt : une seule ligne en attente", async () => {
  const s = await stateOf("accueil-en-attente.html");
  assert.equal(s.rows.length, 1);
  assert.match(s.rows[0], /en attente/);
  // La date de la ligne part avec elle : c'est ce qui sépare une nouvelle demande d'une ancienne (ExportProof.isRecent).
  assert.match(s.rows[0], /16 novembre 2026/);
  assert.equal(s.dl, 1);
});

test("ancienne demande « En attente » qui s'affiche en retard : d'abord rien, puis la ligne avec SA date", async () => {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.addInitScript(() => {
    window.__sent = [];
    const h = (n) => ({ postMessage: (b) => window.__sent.push({ n, b }) });
    window.webkit = { messageHandlers: { zyeutoState: h("state"), zyeutoTap: h("tap"), zyeutoRing: h("ring") } };
  });
  await page.goto("file://" + root + "tests/lecteur/pages/accueil-ancienne-en-retard.html");
  await page.evaluate(READER);
  await page.waitForFunction(() => window.__sent.some((x) => x.n === "state"), null, { timeout: 3000 });
  const first = await page.evaluate(() => window.__sent.filter((x) => x.n === "state")[0].b);
  assert.deepEqual(first.rows, []);
  await page.waitForFunction(() => window.__sent.some((x) => x.n === "state" && x.b.rows && x.b.rows.length === 1), null, { timeout: 4000 });
  const late = await page.evaluate(() => window.__sent.filter((x) => x.n === "state").pop().b);
  await page.close();
  assert.equal(late.rows.length, 1);
  // Swift ne la prend pas pour la nouvelle demande : elle est datée du 2 novembre (voir tests/ios/ExportProofTests.swift, cas 3).
  assert.match(late.rows[0], /2 novembre 2026/);
});

test("deux demandes en attente le même jour : deux lignes (même texte)", async () => {
  const s = await stateOf("accueil-deux-en-attente.html");
  assert.equal(s.rows.length, 2);
});

test("résumé : la liste n'est lue que sur l'accueil", async () => {
  const s = await stateOf("resume-bon.html");
  assert.equal(s.rows, null);
  assert.equal(s.screen, "summary:start");
});

test("résumé avec « Année dernière » : reconnu comme mauvaise période", async () => {
  const s = await stateOf("resume-annee-derniere.html");
  assert.equal(s.screen, "summary:period");
});

test("compte verrouillé (capture d'un testeur) : verrou reconnu", async () => {
  const s = await stateOf("compte-verrouille.html");
  assert.equal(s.locked, "locked");
  assert.equal(s.code, "", "pas de case de code sur cet écran");
});

test("compte suspendu : reconnu comme suspendu", async () => {
  const s = await stateOf("compte-suspendu.html");
  assert.equal(s.locked, "suspended");
});

test("code de sécurité par WhatsApp : JAMAIS pris pour un compte verrouillé", async () => {
  const s = await stateOf("code-whatsapp.html");
  assert.equal(s.locked, "");
  assert.equal(s.code, "whatsapp");
});

test("« Choisir un moyen de récupération » sans phrase de verrou : pas de verrou", async () => {
  const s = await stateOf("recuperation-sans-verrou.html");
  assert.equal(s.locked, "");
});

test("phrase de verrou cachée dans la page : ignorée", async () => {
  const s = await stateOf("verrou-cache.html");
  assert.equal(s.locked, "");
});

test("mot de passe faux : connexion + erreur reconnues", async () => {
  const s = await stateOf("mot-de-passe-faux.html");
  assert.equal(s.login, true);
  assert.equal(s.badpw, true);
  assert.equal(s.locked, "");
});

// FOU-121 P2 : connexion à Instagram, seulement sur des phrases claires d'Instagram.
test("identifiant inconnu : connexion + compte introuvable, pas « mot de passe faux »", async () => {
  const s = await stateOf("identifiant-inconnu.html");
  assert.equal(s.login, true);
  assert.equal(s.nouser, true);
  assert.equal(s.badpw, false);
});

test("mot de passe faux : pas pris pour un compte introuvable", async () => {
  const s = await stateOf("mot-de-passe-faux.html");
  assert.equal(s.nouser, false);
});

test("code refusé : case du code + erreur reconnues", async () => {
  const s = await stateOf("code-incorrect.html");
  assert.equal(s.code, "sms");
  assert.equal(s.codebad, true);
});

test("écran du code normal (« si le code a expiré… ») : pas d'erreur inventée", async () => {
  const s = await stateOf("code-aide-expire.html");
  assert.equal(s.code, "sms");
  assert.equal(s.codebad, false);
  const w = await stateOf("code-whatsapp.html");
  assert.equal(w.codebad, false);
});

test("validation sur un autre appareil : reconnue, sans case ni mot de passe", async () => {
  const s = await stateOf("validation-autre-appareil.html");
  assert.equal(s.code, "approve");
  assert.equal(s.login, false);
  assert.equal(s.pending, false);
});

test("page sans champ de connexion : pas de demande de mot de passe", async () => {
  const s = await stateOf("adresse-login-sans-champ.html");
  assert.equal(s.login, false);
  assert.equal(s.code, "");
});
