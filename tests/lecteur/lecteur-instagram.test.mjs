// FOU-121 : teste le script qui lit les écrans d'Instagram (bloc LECTEUR-INSTAGRAM de WebViewController.swift)
// sur des pages reconstituées (tests/lecteur/pages). Il faut Playwright et Chromium : npm run test:lecteur.
// Ces pages imitent les textes d'Instagram ; elles ne prouvent pas que les vrais écrans sont reconnus (test sur iPhone obligatoire).
// Limites (relecture ChatGPT, 18 nov.) : la vraie structure HTML d'Instagram n'a jamais été observée, seulement des captures.
// Les pages « liste-fenetre-* » reprennent les textes et boutons visibles le 17 nov. ; les pages « liste-structure-inconnue » et
// « liste-date-autrement » vérifient le repli : sans carte reconnue, aucune date n'est rattachée à un bouton qui n'est pas le sien,
// et une ligne sans date lisible ne peut jamais prouver une demande ni un fichier prêt (ExportProof, ReadyProof).
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

// FOU-126 : lignes prêtes (vrai « Télécharger » visible) avec leur date, pour la preuve « prêt » (ReadyProof).
test("ancien export prêt + nouvelle demande en attente : la ligne prête garde SA date", async () => {
  const s = await stateOf("accueil-en-attente.html");
  assert.equal(s.ready.length, 1);
  assert.match(s.ready[0], /2 novembre 2026/);
  assert.match(s.ready[0], /télécharger/);
  assert.doesNotMatch(s.ready[0], /16 novembre/, "la ligne prête n'englobe pas la ligne en attente");
});

test("deux exports prêts le même jour + un ancien : trois lignes prêtes, chacune avec sa date", async () => {
  const s = await stateOf("accueil-deux-prets-meme-jour.html");
  assert.equal(s.ready.length, 3);
  assert.equal(s.ready.filter((r) => /16 novembre 2026/.test(r)).length, 2);
  assert.equal(s.ready.filter((r) => /2 novembre 2026/.test(r)).length, 1);
});

test("liste en cours de chargement : d'abord aucune ligne prête, puis la ligne avec sa date", async () => {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  await page.addInitScript(() => {
    window.__sent = [];
    const h = (n) => ({ postMessage: (b) => window.__sent.push({ n, b }) });
    window.webkit = { messageHandlers: { zyeutoState: h("state"), zyeutoTap: h("tap"), zyeutoRing: h("ring") } };
  });
  await page.goto("file://" + root + "tests/lecteur/pages/accueil-pret-en-chargement.html");
  await page.evaluate(READER);
  await page.waitForFunction(() => window.__sent.some((x) => x.n === "state"), null, { timeout: 3000 });
  const first = await page.evaluate(() => window.__sent.filter((x) => x.n === "state")[0].b);
  assert.deepEqual(first.ready, []);
  await page.waitForFunction(() => window.__sent.some((x) => x.n === "state" && x.b.ready && x.b.ready.length === 1), null, { timeout: 4000 });
  const late = await page.evaluate(() => window.__sent.filter((x) => x.n === "state").pop().b);
  await page.close();
  assert.match(late.ready[0], /16 novembre 2026/);
});

test("bouton « Télécharger » caché ou réduit à rien : pas une ligne prête", async () => {
  const s = await stateOf("accueil-telecharger-cache.html");
  assert.deepEqual(s.ready, []);
  assert.equal(s.rows.length, 1);
});

test("page en anglais : « Download » lu comme une ligne prête, « Pending » comme en attente", async () => {
  const s = await stateOf("accueil-anglais.html");
  assert.equal(s.create, true);
  assert.equal(s.rows.length, 1);
  assert.match(s.rows[0], /nov 16, 2026/);
  assert.equal(s.ready.length, 1);
  assert.match(s.ready[0], /nov 14, 2026/);
});

test("hors de l'accueil de l'export : aucune ligne prête lue", async () => {
  const s = await stateOf("resume-bon.html");
  assert.equal(s.ready, null);
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

// Relecture ChatGPT n° 3 : un texte caché, hors de l'écran ou une simple explication ne déclenchent jamais d'erreur.
test("erreurs de connexion cachées ou hors de l'écran : ignorées", async () => {
  const s = await stateOf("erreurs-cachees.html");
  assert.equal(s.login, true);
  assert.equal(s.badpw, false);
  assert.equal(s.nouser, false);
});

test("explications d'Instagram (« Si votre mot de passe est incorrect… ») : pas une erreur", async () => {
  const s = await stateOf("connexion-explications.html");
  assert.equal(s.login, true);
  assert.equal(s.badpw, false);
  assert.equal(s.nouser, false);
});

test("erreur de code cachée ou hors de l'écran : ignorée", async () => {
  const s = await stateOf("code-erreur-cachee.html");
  assert.equal(s.code, "sms");
  assert.equal(s.codebad, false);
});

// FOU-121 P5 (R3) : le résumé annonce plus que les abonnés.
test("résumé « 4 éléments » : signalé comme trop d'informations", async () => {
  const s = await stateOf("resume-quatre-elements.html");
  assert.equal(s.screen, "summary:info");
});

test("résumé « Followers et suivi(e)s, Messages » : signalé", async () => {
  const s = await stateOf("resume-followers-plus.html");
  assert.equal(s.screen, "summary:info");
});

test("résumé « Followers et suivi(e)s » seul, ou « 1 élément » : bons réglages", async () => {
  assert.equal((await stateOf("resume-followers-seul.html")).screen, "summary:start");
  assert.equal((await stateOf("resume-bon.html")).screen, "summary:start");
});

// FOU-121 P5 (R2) : chaque case présente part avec son nom et son état, pour que Zieuton s'en souvienne en défilant.
test("page des cases : chaque ligne avec son état", async () => {
  const s = await stateOf("cases-liste.html");
  assert.equal(s.screen, "pick");
  assert.equal(s.pick.n, 2);
  assert.equal(s.pick.f, true);
  const on = Object.fromEntries(s.pick.r);
  assert.equal(on["Followers et suivi(e)s"], true);
  assert.equal(on["Comptes masqués"], true);
  assert.equal(on["Messages"], false);
  assert.equal(s.pick.r.length, 6);
});

// Relecture ChatGPT de P5 : ce que dit la ligne « Personnaliser les informations » (preuve pour « ✓ Tout est bien réglé »).
test("résumé : « Followers et suivi(e)s » nommée, « 1 élément » seul, ou trop d'informations", async () => {
  assert.equal((await stateOf("resume-followers-seul.html")).info, "followers");
  assert.equal((await stateOf("resume-bon.html")).info, "one");
  assert.equal((await stateOf("resume-quatre-elements.html")).info, "");
  assert.equal((await stateOf("resume-followers-plus.html")).info, "");
});

// Tests iPhone du 17 nov. (build 17) : la vraie liste a des sections (« En attente » est un titre) et des cartes datées
// « Demandée le 17/11/2026 », dans une fenêtre par-dessus la page. Page reconstituée d'après la capture (textes et boutons seulement).
test("17 nov. : liste dans une fenêtre, « Créer une exportation » caché dessous : la liste est quand même lue", async () => {
  const s = await stateOf("liste-fenetre-17nov.html");
  assert.equal(s.create, false, "le bouton est sous la fenêtre");
  assert.ok(Array.isArray(s.rows), "la liste est lue malgré tout");
  assert.equal(s.screen, "home");
});

test("17 nov. : la demande « En attente » est lue avec SA date (titre de section + carte)", async () => {
  const s = await stateOf("liste-fenetre-17nov.html");
  assert.equal(s.rows.length, 1, "une seule demande en attente (le titre de section n'est pas une ligne)");
  assert.match(s.rows[0], /^en attente/);
  assert.match(s.rows[0], /demandée le 17\/11\/2026/);
  assert.doesNotMatch(s.rows[0], /télécharger/);
});

test("17 nov. : l'ancien export (Télécharger + Annuler) est une ligne prête à part, jamais la nouvelle demande", async () => {
  const s = await stateOf("liste-fenetre-17nov.html");
  assert.equal(s.ready.length, 1);
  assert.match(s.ready[0], /^expire le 20\/11\/2026/, "la carte prête porte sa date d'expiration (format vu le 18 nov.)");
  assert.match(s.ready[0], /télécharger/);
  assert.doesNotMatch(s.ready[0], /17\/11/, "la carte prête n'englobe pas la carte en attente");
});

test("17 nov. : ancien export prêt du MÊME jour : deux cartes séparées, une prête, une en attente", async () => {
  const s = await stateOf("liste-fenetre-17nov.html?ancien=21/11/2026");
  assert.equal(s.ready.length, 1);
  assert.equal(s.rows.length, 1);
  assert.match(s.ready[0], /télécharger/);
  assert.doesNotMatch(s.rows[0], /télécharger/);
});

test("17 nov. : fenêtre marquée comme dialogue : seule la fenêtre est lue, pas la page dessous", async () => {
  const s = await stateOf("liste-fenetre-dialogue.html");
  assert.equal(s.rows.length, 1);
  assert.equal(s.ready.length, 1, "la ligne prête de la page dessous (2/11) n'est pas comptée");
  assert.match(s.ready[0], /expire le 20\/11\/2026/);
});

// Vidéo iPhone du 21 nov. (build 22) : la carte prête réellement observée, seule dans « Téléchargements disponibles ».
for (const q of ["", "?fenetre=0"]) {
  test(`carte prête du 21 nov. (Expire le 25/11/2026), fenêtre${q ? " sans role=dialog" : ""} : lue comme prête, jamais en attente`, async () => {
    const s = await stateOf("liste-fenetre-21nov.html" + q);
    assert.deepEqual(s.rows, [], "aucune demande en attente");
    assert.equal(s.ready.length, 1, "une seule ligne prête");
    assert.match(s.ready[0], /^expire le 25\/11\/2026/);
    assert.match(s.ready[0], /followers et suivi\(e\)s/);
  });
}

test("carte du 21 nov., deux lignes grises dans un seul bloc : la date n'est pas lue, mais « Télécharger » est vu (bandeau « disponible »)", async () => {
  const s = await stateOf("liste-fenetre-21nov.html?lignes=1");
  assert.deepEqual(s.rows, [], "jamais lue comme une demande en attente");
  assert.equal(s.ready.length, 1, "le vrai « Télécharger » est vu : la coque peut dire « Un fichier est disponible »");
  for (const r of s.ready) assert.doesNotMatch(r, /[0-9]{1,2}\/[0-9]{1,2}\//, "aucune date rattachée : la preuve « prêt » ne peut pas le compter");
});

// Relecture ChatGPT (18 nov.) : les pages ci-dessus sont reconstituées ; si la vraie structure diffère, la lecture doit rester prudente.
test("structure inconnue (dates et boutons séparés) : aucune date n'est rattachée à « Télécharger »", async () => {
  const s = await stateOf("liste-structure-inconnue.html");
  for (const r of s.ready) assert.doesNotMatch(r, /1[67]\/11/, "un bouton sans carte n'emporte jamais une date");
  for (const r of s.rows) assert.doesNotMatch(r, /télécharger/);
});

test("date écrite autrement que « Demandée le » : pas de carte, l'ancienne lecture garde la date de SON bloc, sans inventer d'attente", async () => {
  const s = await stateOf("liste-date-autrement.html");
  assert.equal(s.ready.length, 1);
  assert.match(s.ready[0], /17 nov/, "un seul bouton dans le bloc : sa date part avec lui (la référence ReadyProof protège d'un ancien export du même jour)");
  assert.deepEqual(s.rows, [], "aucune demande « en attente » inventée");
});

// Vidéo iPhone du 18 nov. (14 h 30) : la vraie liste montre « Téléchargements disponibles » (cartes « Expire le … · Moins de 1 Mo »,
// Télécharger + Annuler) puis « En attente » (carte « Demandée le 18/11/2026 », Annuler). Page reconstituée : textes et boutons seulement.
test("18 nov. : trois fichiers prêts et une demande en attente, chacun sa carte, avec SA date", async () => {
  const s = await stateOf("liste-18nov.html");
  assert.equal(s.screen, "home");
  assert.equal(s.rows.length, 1, "une seule demande en attente");
  assert.match(s.rows[0], /^en attente · demandée le 18\/11\/2026/);
  assert.equal(s.ready.length, 3, "trois cartes prêtes");
  for (const r of s.ready) {
    assert.match(r, /^expire le 2[12]\/11\/2026/, "chaque carte prête commence par sa date d'expiration");
    assert.match(r, /télécharger/);
    assert.doesNotMatch(r, /demandée le 18/, "une carte prête n'englobe jamais la demande en attente");
  }
});

test("18 nov. : une carte « Expire le » n'est jamais comptée comme une demande en attente", async () => {
  const s = await stateOf("liste-18nov.html?attente=0");
  assert.deepEqual(s.rows, [], "plus de demande en attente");
  assert.equal(s.ready.length, 4, "la nouvelle carte prête s'ajoute aux trois autres");
  assert.equal(s.ready.filter((r) => /^expire le 22\/11\/2026/.test(r)).length, 2, "deux fichiers prêts le même jour, deux cartes");
});
