// Change channel.json (canaux de mise à jour de la page dans l'app iPhone, FOU-28).
//   node scripts/channel.mjs valider      → la page actuelle (const BUILD de index.html) devient la version stable
//   node scripts/channel.mjs urgence on   → tous les iPhones reviennent à la page rangée dans l'app
//   node scripts/channel.mjs urgence off  → fin de l'urgence
// Ensuite : PR, puis fusion. L'app lit le fichier à chaque ouverture.
import { readFileSync, writeFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const file = new URL("channel.json", root);
const ch = JSON.parse(readFileSync(file, "utf8"));
const [cmd, arg] = process.argv.slice(2);
if (cmd === "valider") {
  ch.stable = readFileSync(new URL("index.html", root), "utf8").match(/const BUILD = "([^"]+)"/)[1];
} else if (cmd === "urgence" && (arg === "on" || arg === "off")) {
  ch.urgence = arg === "on";
} else {
  console.error("Usage : node scripts/channel.mjs valider | urgence on | urgence off");
  process.exit(1);
}
writeFileSync(file, JSON.stringify({ stable: ch.stable, urgence: ch.urgence }, null, 2) + "\n");
console.log(`channel.json : stable = ${ch.stable}, urgence = ${ch.urgence ? "ACTIVÉE" : "éteinte"}`);
