// Vérifie la syntaxe JavaScript de chaque <script> des pages HTML (sans les exécuter).
// Une seule faute de frappe dans index.html et toute l'app reste blanche : ce contrôle l'attrape avant la mise en ligne.
import { readFileSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

const root = fileURLToPath(new URL("..", import.meta.url));
const pages = readdirSync(root).filter((f) => f.endsWith(".html"));
let bad = 0, count = 0;

for (const page of pages) {
  const html = readFileSync(root + page, "utf8");
  const re = /<script(\s[^>]*)?>([\s\S]*?)<\/script>/gi;
  let m;
  while ((m = re.exec(html))) {
    const attrs = m[1] || "";
    if (/\ssrc=/i.test(attrs)) continue;                                        // script externe : rien à lire ici
    if (/type=["']?(application\/(ld\+)?json|text\/template)/i.test(attrs)) continue; // pas du JavaScript
    const line = html.slice(0, m.index).split("\n").length;
    // Les lignes vides devant gardent les mêmes numéros de ligne que dans le fichier HTML.
    const code = "\n".repeat(line - 1) + m[2];
    count++;
    try {
      new vm.Script(code, { filename: page });
    } catch (e) {
      bad++;
      const where = (e.stack || "").split("\n")[0];
      console.error(`ERREUR de syntaxe dans ${page} (script qui commence ligne ${line}) : ${e.message}\n  → ${where}`);
    }
  }
}

if (bad) process.exit(1);
console.log(`OK : ${count} scripts relus dans ${pages.length} pages, aucune erreur de syntaxe.`);
