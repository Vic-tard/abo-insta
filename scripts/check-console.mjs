// Ouvre la page dans un vrai navigateur (Chromium, via Playwright) et échoue s'il y a une erreur dans la console.
// Deux passages : comme dans l'app iPhone (window.ZYEUTO_APP = { version: 7 }), puis comme dans Safari.
// Lancer : npm run check:page   (il faut d'abord : npm ci && npx playwright install chromium)
import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { extname, join, normalize } from "node:path";
import { chromium } from "playwright";

const root = fileURLToPath(new URL("..", import.meta.url));
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".json": "application/json", ".webmanifest": "application/manifest+json", ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg" };

// Petit serveur local qui sert le dossier comme GitHub Pages.
const server = createServer(async (req, res) => {
  let path = normalize(decodeURIComponent(new URL(req.url, "http://x").pathname));
  if (path.endsWith("/")) path += "index.html";
  try {
    const body = await readFile(join(root, path));
    res.writeHead(200, { "content-type": TYPES[extname(path)] || "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404); res.end();
  }
});
await new Promise((r) => server.listen(0, "127.0.0.1", r));
const url = `http://127.0.0.1:${server.address().port}/`;

const runs = [
  { label: "dans l'app (ZYEUTO_APP version 7)", app: { version: 7 } },
  { label: "dans Safari (site)", app: null },
];
const browser = await chromium.launch();
let failed = false;
for (const run of runs) {
  const context = await browser.newContext({ viewport: { width: 393, height: 852 }, locale: "fr-FR" });
  const page = await context.newPage();
  const errors = [];
  page.on("console", (m) => { if (m.type() === "error") errors.push(`console : ${m.text()}`); });
  page.on("pageerror", (e) => errors.push(`erreur JavaScript : ${e.message}`));
  if (run.app) await page.addInitScript((app) => { window.ZYEUTO_APP = app; }, run.app);
  await page.goto(url, { waitUntil: "load" });
  await page.waitForTimeout(3000); // laisse le temps aux animations et au chargement de l'historique
  if (errors.length) {
    failed = true;
    console.error(`ÉCHEC ${run.label} : ${errors.length} erreur(s)`);
    for (const e of errors) console.error("  - " + e);
  } else {
    console.log(`OK ${run.label} : aucune erreur dans la console.`);
  }
  await context.close();
}
await browser.close();
server.close();
if (failed) process.exit(1);
