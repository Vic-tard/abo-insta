// Relecture ChatGPT (18 nov., 15 h 55) : le cercle sur « Télécharger » ne doit jamais tomber sur la carte d'un ancien export.
// Un bouton « Télécharger » ne dit pas à quelle carte il appartient : Zieuton ne l'entoure que s'il n'y en a qu'UN dans toute la liste.
// Lancer : npm run test:lecteur.
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

// Ouvre la liste du 18 nov. (fichier prêt), garde `keep` cartes prêtes, fait défiler, et rend le dernier message du cercle.
async function ring({ keep = 4, scroll = null, height = 844 } = {}) {
  const page = await browser.newPage({ viewport: { width: 390, height } });
  await page.addInitScript(() => {
    window.__sent = [];
    const h = (n) => ({ postMessage: (b) => window.__sent.push({ n, b }) });
    window.webkit = { messageHandlers: { zyeutoState: h("state"), zyeutoTap: h("tap"), zyeutoRing: h("ring") } };
  });
  await page.goto("file://" + root + "tests/lecteur/pages/liste-18nov.html?attente=0");
  await page.evaluate((k) => { [...document.querySelectorAll(".carte")].slice(k).forEach((c) => c.remove()); }, keep);
  await page.evaluate(READER);
  if (scroll !== null) await page.evaluate((i) => { const c = [...document.querySelectorAll(".carte")]; c[i < 0 ? c.length + i : i].scrollIntoView({ block: "end" }); }, scroll);
  await page.evaluate(() => window.__zyRing(["télécharger", "download"]));
  await page.waitForTimeout(700);
  const r = await page.evaluate(() => window.__sent.filter((x) => x.n === "ring").map((x) => x.b));
  const visible = await page.evaluate(() => [...document.querySelectorAll("button")].filter((b) => {
    const x = b.getBoundingClientRect(); return b.textContent === "Télécharger" && x.top >= 0 && x.bottom <= innerHeight;
  }).length);
  await page.close();
  return { last: r.at(-1), all: r, visible };
}

test("ancien export + nouveau fichier : jamais de cercle, même si un seul « Télécharger » est à l'écran", async () => {
  const a = await ring({ keep: 4 });
  assert.equal(a.last, "", "plusieurs fichiers dans la liste : aucun cercle");
  // L'utilisateur fait défiler : seul le bouton de l'ancien export (dernière carte) reste visible.
  const b = await ring({ keep: 4, scroll: -1, height: 260 });
  assert.equal(b.visible, 1, "un seul « Télécharger » visible : celui de l'ancien export");
  assert.ok(b.all.every((m) => m === ""), "aucun cercle à aucun moment");
  const c = await ring({ keep: 2, scroll: 1, height: 260 });
  assert.ok(c.all.every((m) => m === ""), "deux cartes prêtes, une seule visible : aucun cercle");
});

test("un seul fichier dans toute la liste : le cercle est permis (c'est forcément le fichier prouvé)", async () => {
  const a = await ring({ keep: 1 });
  assert.match(a.last, /^\d+,\d+,\d+,\d+,(0|1|-1)$/);
});
