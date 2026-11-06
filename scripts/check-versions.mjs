// Vérification de CI (FOU-44) : une PR qui change la page doit faire avancer BUILD,
// une PR qui change la coque iPhone doit augmenter CURRENT_PROJECT_VERSION.
//   node scripts/check-versions.mjs origin/main
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { readBuild, readProjectVersion, checkVersions } from "./versions.mjs";

const baseRef = process.argv[2];
if (!baseRef) {
  console.error("Usage : node scripts/check-versions.mjs <branche de base, ex. origin/main>");
  process.exit(2);
}
const root = new URL("..", import.meta.url);
const git = (...args) => execFileSync("git", args, { cwd: root, encoding: "utf8" });
const PBX = "ios/Zieuton.xcodeproj/project.pbxproj";

const mergeBase = git("merge-base", baseRef, "HEAD").trim();
const changed = git("diff", "--name-only", mergeBase, "HEAD").split("\n").filter(Boolean);
const base = { build: readBuild(git("show", `${mergeBase}:index.html`)), projectVersion: readProjectVersion(git("show", `${mergeBase}:${PBX}`)) };
const head = { build: readBuild(readFileSync(new URL("index.html", root), "utf8")), projectVersion: readProjectVersion(readFileSync(new URL(PBX, root), "utf8")) };

const errors = checkVersions({ changed, base, head });
console.log(`Fichiers changés : ${changed.length}. BUILD ${base.build} → ${head.build}. CURRENT_PROJECT_VERSION ${base.projectVersion} → ${head.projectVersion}.`);
for (const e of errors) console.error(`::error::${e}`);
process.exit(errors.length ? 1 : 0);
