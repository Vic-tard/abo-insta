// Recopie js/zieuton-core.js dans index.html, entre les repères ZIEUTON-CORE.
//   node scripts/sync-core.mjs          → met index.html à jour
//   node scripts/sync-core.mjs --check  → vérifie seulement que les deux sont identiques (utilisé par la vérification automatique)
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("..", import.meta.url));
const START = "// ===== ZIEUTON-CORE : début =====";
const NOTE = "// Copie de js/zieuton-core.js. Ne modifie pas ce bloc ici : modifie js/zieuton-core.js, puis lance « node scripts/sync-core.mjs ».";
const END = "// ===== ZIEUTON-CORE : fin =====";

export function coreBlock(html) {
  const a = html.indexOf(START + "\n" + NOTE + "\n"), b = html.indexOf("\n" + END);
  if (a < 0 || b < 0 || b < a) throw new Error("Repères ZIEUTON-CORE introuvables dans index.html.");
  return { start: a + START.length + NOTE.length + 2, end: b + 1 };
}

const htmlPath = root + "index.html";
const html = readFileSync(htmlPath, "utf8");
const core = readFileSync(root + "js/zieuton-core.js", "utf8");
const { start, end } = coreBlock(html);
const current = html.slice(start, end);

if (current === core) {
  console.log("OK : index.html contient bien la même copie que js/zieuton-core.js.");
} else if (process.argv.includes("--check")) {
  console.error("ERREUR : le bloc ZIEUTON-CORE de index.html ne correspond plus à js/zieuton-core.js.");
  console.error("Fais la modification dans js/zieuton-core.js, puis lance : node scripts/sync-core.mjs");
  process.exit(1);
} else {
  writeFileSync(htmlPath, html.slice(0, start) + core + html.slice(end));
  console.log("index.html mis à jour avec js/zieuton-core.js.");
}
