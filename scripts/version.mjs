// npm run version : met `const BUILD` de index.html à l'heure actuelle (heure de Paris). FOU-44.
// À lancer dans toute PR qui change la page, juste avant le dernier commit.
import { readFileSync, writeFileSync } from "node:fs";
import { BUILD_RE, readBuild, nextBuild } from "./versions.mjs";

const file = new URL("../index.html", import.meta.url);
const html = readFileSync(file, "utf8");
const before = readBuild(html);
const after = nextBuild(before);
writeFileSync(file, html.replace(BUILD_RE, `const BUILD = "${after}";`));
console.log(`BUILD : ${before} → ${after}`);
