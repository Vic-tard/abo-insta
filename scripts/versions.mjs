// Numéros de version de Zieuton (FOU-44).
//   - BUILD dans index.html : version de la page. Les iPhones ne prennent une page téléchargée que si BUILD a changé.
//   - CURRENT_PROJECT_VERSION dans ios/Zieuton.xcodeproj : numéro du build envoyé à TestFlight / l'App Store.
// Ce fichier contient les règles ; scripts/version.mjs et scripts/check-versions.mjs s'en servent.

export const BUILD_RE = /const BUILD = "(\d{4}-\d{2}-\d{2}-\d{4})";/;
const PROJECT_RE = /CURRENT_PROJECT_VERSION = ([^;]+);/g;

export function readBuild(html) {
  const m = html.match(BUILD_RE);
  if (!m) throw new Error('index.html : ligne `const BUILD = "AAAA-MM-JJ-HHMM";` introuvable');
  return m[1];
}

// Toutes les valeurs de CURRENT_PROJECT_VERSION (Debug et Release) doivent être identiques.
export function readProjectVersion(pbxproj) {
  const values = [...pbxproj.matchAll(PROJECT_RE)].map((m) => m[1].trim());
  if (!values.length) throw new Error("project.pbxproj : CURRENT_PROJECT_VERSION introuvable");
  if (new Set(values).size > 1) throw new Error(`project.pbxproj : CURRENT_PROJECT_VERSION différent selon les réglages (${values.join(", ")})`);
  return values[0];
}

// Heure de Paris au format AAAA-MM-JJ-HHMM.
export function buildFromDate(date) {
  const p = Object.fromEntries(
    new Intl.DateTimeFormat("fr-FR", {
      timeZone: "Europe/Paris", year: "numeric", month: "2-digit", day: "2-digit",
      hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(date).map((x) => [x.type, x.value]),
  );
  return `${p.year}-${p.month}-${p.day}-${p.hour}${p.minute}`;
}

// BUILD suivant : l'heure actuelle, ou une minute de plus que l'actuel s'il est déjà plus récent
// (BUILD ne doit jamais reculer, sinon des iPhones garderaient l'ancienne page).
export function nextBuild(current, now = new Date()) {
  const candidate = buildFromDate(now);
  if (!current || candidate > current) return candidate;
  const [y, mo, d, hm] = current.split("-");
  const t = new Date(Date.UTC(+y, +mo - 1, +d, +hm.slice(0, 2), +hm.slice(2) + 1));
  const pad = (n) => String(n).padStart(2, "0");
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}-${pad(t.getUTCHours())}${pad(t.getUTCMinutes())}`;
}

export function isPageFile(path) {
  return path === "index.html";
}

// La coque : le code Swift, les réglages et le projet Xcode. Le README du dossier ios n'en fait pas partie.
export function isShellFile(path) {
  return path.startsWith("ios/Zieuton/") || path.startsWith("ios/Zieuton.xcodeproj/");
}

// Renvoie la liste des problèmes (vide si tout va bien).
// changed : chemins modifiés par la PR ; base / head : { build, projectVersion } avant et après.
export function checkVersions({ changed, base, head }) {
  const errors = [];
  if (changed.some(isPageFile) && !(head.build > base.build)) {
    errors.push(
      `La page (index.html) change mais BUILD n'a pas avancé (avant ${base.build}, maintenant ${head.build}). ` +
      "Lance `npm run version` puis refais un commit.",
    );
  }
  if (changed.some(isShellFile)) {
    const before = Number(base.projectVersion), after = Number(head.projectVersion);
    if (!Number.isInteger(after) || !(after > before)) {
      errors.push(
        `La coque iPhone (dossier ios) change mais CURRENT_PROJECT_VERSION n'a pas augmenté (avant ${base.projectVersion}, maintenant ${head.projectVersion}). ` +
        "Augmente-le de 1 dans Xcode (Zieuton → General → Build) ou dans ios/Zieuton.xcodeproj/project.pbxproj (Debug et Release).",
      );
    }
  }
  return errors;
}
