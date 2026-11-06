// Fabrique les deux exports d'exemple pour le testeur Apple (FOU-32) : exemple/zieuton-exemple-1.zip et -2.zip.
// Comptes inventés (tous en « .sample »), même forme qu'un vrai export Instagram en JSON.
// Lancer : node scripts/make-review-exports.mjs   (les fichiers sont gardés dans le dépôt, à refaire seulement si on change la liste)
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { makeZip, followersJson, followingJson, DIR } from "../tests/helpers.mjs";

const root = fileURLToPath(new URL("..", import.meta.url));
const FIRST = ["alex", "jade", "louis", "emma", "hugo", "lina", "noah", "rose", "adam", "mila", "leo", "zoe", "jules", "ines", "tom",
  "lea", "sacha", "nina", "paul", "lou", "theo", "ambre", "nathan", "eva", "victor", "alice", "gabin", "julia", "arthur", "clara",
  "maxime", "sarah", "ethan", "anna", "liam", "manon", "robin", "chloe", "noe", "camille"];
const acct = (n) => `${n}.sample`;
export const EXPORT_1 = FIRST.map(acct);                                                   // 40 abonnés
export const GONE = ["jade", "noah", "theo", "clara"].map(acct);                            // partis entre les deux
export const NEW = ["lucie", "oscar", "maya"].map(acct);                                    // arrivés entre les deux
export const EXPORT_2 = [...EXPORT_1.filter((n) => !GONE.includes(n)), ...NEW];            // 39 abonnés
export const FOLLOWING = [...FIRST.slice(0, 30).map(acct), "studio.sample", "cafe.sample", "club.sample"]; // dont 3 qui ne suivent pas

const zip = (followers, date, name) => makeZip([
  { name: DIR + "followers_1.json", text: followersJson(followers) },
  { name: DIR + "following.json", text: followingJson(FOLLOWING) },
], { date, name });

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  mkdirSync(root + "exemple", { recursive: true });
  for (const [list, date, name] of [[EXPORT_1, new Date("2026-10-01T12:00:00"), "zieuton-exemple-1.zip"], [EXPORT_2, new Date("2026-11-01T12:00:00"), "zieuton-exemple-2.zip"]]) {
    writeFileSync(root + "exemple/" + name, Buffer.from(await zip(list, date, name).arrayBuffer()));
    console.log("OK : exemple/" + name + " (" + list.length + " abonnés)");
  }
}
