// Zieuton : lecture de l'export Instagram et comparaison des imports.
// Ce fichier est recopié tel quel dans index.html (entre les repères ZIEUTON-CORE) : la page reste un seul fichier,
// qui marche sans étape de construction, sur GitHub Pages comme dans l'app.
// Après une modification ici : « node scripts/sync-core.mjs » (recopie dans index.html), puis « npm test ».
//
// Fourni par le reste de la page (et simulé par les tests) : state, nf, fmtDate, accts, curAcct, acctLockOn, otherAccountError, logError.

// ---------- Lecture de l'export Instagram ----------
function cleanName(s) {
  if (!s || typeof s !== "string") return null;
  const n = s.trim().replace(/^@/, "").toLowerCase();
  return n || null;
}
function nameFromHref(href) {
  if (!href) return null;
  try {
    const parts = new URL(href).pathname.split("/").filter((p) => p && p !== "_u");
    return parts.length ? parts[parts.length - 1] : null;
  } catch { return null; }
}
// Gère l'ancienne variante (nom dans string_list_data[].value) et la récente (nom dans title).
// followers_1.json est une liste ; following.json est { relationships_following: [...] }.
function listKind(data) {
  if (Array.isArray(data)) return "followers";
  if (data && Array.isArray(data.relationships_followers)) return "followers";
  if (data && Array.isArray(data.relationships_following)) return "following";
  return null;
}
function parseAccounts(data) {
  if (data && !Array.isArray(data)) data = data.relationships_followers || data.relationships_following;
  if (!Array.isArray(data)) throw new Error("Aucune liste d'abonnés dans ce fichier.");
  const out = {};
  for (const entry of data) {
    if (!entry || typeof entry !== "object") continue;
    const items = Array.isArray(entry.string_list_data) && entry.string_list_data.length ? entry.string_list_data : [{}];
    for (const item of items) {
      const name = cleanName(item.value) || cleanName(entry.title) || cleanName(nameFromHref(item.href));
      if (!name) continue;
      out[name] = Number.isInteger(item.timestamp) ? item.timestamp : (out[name] ?? null);
    }
  }
  return out;
}
function parseJsonText(text, label) {
  const t = text.replace(/^﻿/, "").trimStart();
  if (t.startsWith("<")) throw new Error(`${label} est au format HTML. Refais l'export Instagram en choisissant le format JSON.`);
  try { return JSON.parse(t); } catch { throw new Error(`${label} n'est pas un fichier JSON valide.`); }
}
const FOLLOWERS_RE = /(^|\/)followers(_\d+)?\.json$/;
const FOLLOWING_RE = /(^|\/)following\.json$/;

// ---------- Lecteur de .zip minimal (sans bibliothèque externe) ----------
// Lit le répertoire central du .zip, puis décompresse seulement les fichiers utiles.
let zipNames = [];
async function bytesOf(file, start, end) { return new DataView(await file.slice(start, end).arrayBuffer()); }
async function listZip(file) {
  const tailLen = Math.min(file.size, 66000);
  const tail = await bytesOf(file, file.size - tailLen, file.size);
  let eocd = -1;
  for (let i = tail.byteLength - 22; i >= 0; i--) if (tail.getUint32(i, true) === 0x06054b50) { eocd = i; break; }
  if (eocd < 0) throw new Error(`${file.name} n'est pas un .zip valide.`);
  let count = tail.getUint16(eocd + 10, true), cdSize = tail.getUint32(eocd + 12, true), cdOffset = tail.getUint32(eocd + 16, true);
  if (cdOffset === 0xffffffff || count === 0xffff) {
    // Zip64 : le localisateur précède l'EOCD.
    const loc = eocd - 20;
    if (loc < 0 || tail.getUint32(loc, true) !== 0x07064b50) throw new Error(`${file.name} n'est pas un .zip valide.`);
    const z64 = await bytesOf(file, Number(tail.getBigUint64(loc + 8, true)), file.size);
    count = Number(z64.getBigUint64(32, true)); cdSize = Number(z64.getBigUint64(40, true)); cdOffset = Number(z64.getBigUint64(48, true));
  }
  const cd = await bytesOf(file, cdOffset, cdOffset + cdSize);
  const dec = new TextDecoder();
  const out = [];
  let p = 0;
  for (let n = 0; n < count && p + 46 <= cd.byteLength; n++) {
    if (cd.getUint32(p, true) !== 0x02014b50) break;
    const method = cd.getUint16(p + 10, true), time = cd.getUint16(p + 12, true), day = cd.getUint16(p + 14, true);
    let comp = cd.getUint32(p + 20, true), size = cd.getUint32(p + 24, true), local = cd.getUint32(p + 42, true);
    const nameLen = cd.getUint16(p + 28, true), extraLen = cd.getUint16(p + 30, true), commentLen = cd.getUint16(p + 32, true);
    const name = dec.decode(new Uint8Array(cd.buffer, cd.byteOffset + p + 46, nameLen));
    let q = p + 46 + nameLen;
    const extraEnd = q + extraLen;
    while (q + 4 <= extraEnd) {
      const id = cd.getUint16(q, true), len = cd.getUint16(q + 2, true);
      if (id === 0x0001) {
        let r = q + 4;
        if (size === 0xffffffff) { size = Number(cd.getBigUint64(r, true)); r += 8; }
        if (comp === 0xffffffff) { comp = Number(cd.getBigUint64(r, true)); r += 8; }
        if (local === 0xffffffff) { local = Number(cd.getBigUint64(r, true)); }
      }
      q += 4 + len;
    }
    const date = new Date(1980 + (day >> 9), ((day >> 5) & 15) - 1, day & 31, time >> 11, (time >> 5) & 63, (time & 31) * 2);
    out.push({ name, method, comp, size, local, date });
    p = extraEnd + commentLen;
  }
  zipNames = out.map((e) => e.name);
  return out;
}
async function readZipEntry(file, e) {
  const head = await bytesOf(file, e.local, e.local + 30);
  if (head.getUint32(0, true) !== 0x04034b50) throw new Error(`${e.name} est illisible dans le .zip.`);
  const start = e.local + 30 + head.getUint16(26, true) + head.getUint16(28, true);
  const blob = file.slice(start, start + e.comp);
  if (e.method === 0) return blob.text();
  if (e.method !== 8) throw new Error(`${e.name} utilise une compression non prise en charge.`);
  if (typeof DecompressionStream === "undefined") throw new Error("Ce navigateur ne sait pas ouvrir les .zip. Mets à jour iOS, ou décompresse l'export et choisis followers_1.json.");
  return new Response(blob.stream().pipeThrough(new DecompressionStream("deflate-raw"))).text();
}

async function readExport(files) {
  const followers = {};
  let following = null;   // comptes que TU suis, si l'export les contient
  let date = null;
  for (const file of files) {
    const head = new Uint8Array(await file.slice(0, 4).arrayBuffer());
    const isZip = head[0] === 0x50 && head[1] === 0x4b;
    if (isZip) {
      const all = await listZip(file);
      const entries = all.filter((e) => FOLLOWERS_RE.test(e.name));
      if (!entries.length) {
        if (zipNames.some((n) => /followers_1\.html$/.test(n))) throw new Error("Cet export est au format HTML. Refais-le en choisissant JSON.");
        throw new Error("Aucune liste d'abonnés dans ce .zip. Vérifie que tu as coché « Followers et suivi(e)s ».");
      }
      for (const e of entries) {
        Object.assign(followers, parseAccounts(parseJsonText(await readZipEntry(file, e), e.name)));
        if (!date || e.date > date) date = e.date;
      }
      for (const e of all.filter((e) => FOLLOWING_RE.test(e.name))) {
        following = Object.assign(following || {}, parseAccounts(parseJsonText(await readZipEntry(file, e), e.name)));
      }
    } else {
      const data = parseJsonText(await file.text(), file.name);
      if (listKind(data) === "following") { following = Object.assign(following || {}, parseAccounts(data)); continue; }
      Object.assign(followers, parseAccounts(data));
      const d = new Date(file.lastModified);
      if (file.lastModified && (!date || d > date)) date = d;
    }
  }
  if (!Object.keys(followers).length) {
    if (following) throw new Error("Ce fichier liste les comptes que TU suis (following.json). Choisis-le avec followers_1.json, ou importe le .zip complet.");
    throw new Error("L'export ne contient aucun abonné.");
  }
  return { followers, following, date: date || new Date(), source: files.map((f) => f.name).join(" + ") };
}

async function hashNames(names) {
  const text = names.slice().sort().join("\n");
  try {
    const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
    return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
  } catch {
    let h = 0; for (let i = 0; i < text.length; i++) h = (h * 31 + text.charCodeAt(i)) | 0;
    return "h" + h + ":" + names.length;
  }
}

// ---------- Un seul compte Instagram par téléphone ----------
// Sans ça, un seul Zieuton Plus servirait à suivre les comptes de toute une bande d'amis.
// L'export d'Instagram ne contient pas le pseudo : on reconnaît le compte à ses abonnés.
// prefs.acct garde une empreinte (les 512 plus petites valeurs de hachage des pseudos) : elle survit à « Tout effacer ».
const ACCT_K = 512, ACCT_SAME = 0.4;
function nameHash(s) {
  let h = 0x811c9dc5;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 0x01000193); }
  return h >>> 0;
}
const acctPrint = (names) => [...new Set(names.map(nameHash))].sort((a, b) => a - b).slice(0, ACCT_K);
// Part des abonnés en commun, de 0 (aucun) à 1 (les mêmes). Même compte d'un mois sur l'autre : 0,8 à 1.
// Deux amis qui ont beaucoup d'abonnés en commun restent bien en dessous de 0,4.
function acctLikeness(a, b) {
  const sa = new Set(a), sb = new Set(b);
  const union = [...new Set([...a, ...b])].sort((x, y) => x - y).slice(0, ACCT_K);
  return union.length ? union.filter((h) => sa.has(h) && sb.has(h)).length / union.length : 1;
}
const sameAcct = (a, print) => a.n >= 10 && acctLikeness(a.h, print) >= ACCT_SAME;
function isOtherAccount(names) {
  const cur = curAcct();
  if (!acctLockOn() || !(cur.n >= 10)) return false;
  return acctLikeness(cur.h, acctPrint(names)) < ACCT_SAME;
}
// Un autre compte déjà suivi sur ce téléphone qui correspond à cet export.
function knownAcct(names) {
  const print = acctPrint(names), cur = curAcct();
  return accts().find((a) => a !== cur && sameAcct(a, print)) || null;
}

// ---------- Comparaison ----------
async function recordSnapshot(followers, following, takenAt, source) {
  const names = Object.keys(followers);
  const hash = await hashNames(names);
  const last = state.snapshots[state.snapshots.length - 1];
  // Un autre compte déjà suivi sur ce téléphone : on le dit tout de suite.
  const other = isOtherAccount(names);
  if (other && knownAcct(names)) throw otherAccountError("Cet export", names);
  // Garde-fou : un export « programmé » d'Instagram ne contient que les nouveaux abonnés depuis l'export précédent.
  // Le comparer à la liste complète ferait croire que presque tout le monde est parti.
  if (last && last.count >= 20 && names.length < last.count * 0.5) {
    throw new Error(`Cet export ne contient que ${nf(names.length)} abonné${names.length > 1 ? "s" : ""}, contre ${nf(last.count)} au dernier import. C'est un export partiel : Instagram n'y met que les nouveaux abonnés depuis l'export précédent. Rien n'a été enregistré. Refais un export « Une fois », période « Depuis le début ».${acctLockOn() ? " Si c'est l'export d'un autre compte Instagram : Réglages → Mon compte → Ajouter un compte." : ""}`);
  }
  if (other) throw otherAccountError("Cet export", names);
  if (last && new Date(takenAt) < new Date(last.takenAt)) {
    throw new Error(`Cet export est daté du ${fmtDate(takenAt)}, avant ton dernier import (${fmtDate(last.takenAt)}). Importe tes exports dans l'ordre.`);
  }
  // La liste des comptes suivis n'a pas d'historique : on garde la plus récente.
  if (following) { state.following = following; state.followingAt = takenAt; }
  if (last && last.hash === hash) return { status: "same", withFollowing: !!following };
  const prev = new Set(Object.keys(state.followers));
  const cur = new Set(names);
  const unfollows = last ? [...prev].filter((u) => !cur.has(u)).sort() : [];
  const follows = last ? names.filter((u) => !prev.has(u)).sort() : [];
  const id = (last ? last.id : 0) + 1;
  state.snapshots.push({ id, takenAt, source, count: names.length, hash, unfollows: unfollows.length, follows: follows.length });
  // ts = date d'abonnement, gardée pour pouvoir annuler l'import plus tard.
  for (const u of unfollows) state.events.push({ u, kind: "unfollow", at: takenAt, since: last.takenAt, ts: state.followers[u] ?? null });
  for (const u of follows) state.events.push({ u, kind: "follow", at: takenAt, since: last.takenAt });
  state.followers = followers;
  return { status: last ? "ok" : "first", unfollows, follows, count: names.length };
}

// ---------- Version des données enregistrées (FOU-39) ----------
// L'historique (état par compte) et les réglages portent un numéro de version « v ». Sans numéro = version 1
// (tout ce qui a été enregistré avant ce numéro). Au chargement, migrateState / migratePrefs font passer
// les données à la version actuelle, une étape à la fois. Elles ne suppriment jamais rien :
// des données incomprises ou d'une version plus récente (ex. après un retour arrière de la page) sont
// signalées « keep » pour que la page en garde une copie à part avant toute écriture.
const STATE_V = 2, PREFS_V = 2;
const isPlainObj = (x) => !!x && typeof x === "object" && !Array.isArray(x);
const looksLikeState = (s) => isPlainObj(s) && Array.isArray(s.snapshots) && Array.isArray(s.events) && isPlainObj(s.followers);
// Étapes : STATE_STEPS[n] fait passer de la version n à n + 1. Une future étape s'ajoute ici, sans toucher aux autres.
const STATE_STEPS = {
  1: (s) => ({ ...s, v: 2 }), // version 2 : seulement le numéro (la forme des données ne change pas)
};
const PREFS_STEPS = {
  1: (p) => ({ ...p, v: 2 }),
};
function dataVersion(d) {
  if (!isPlainObj(d)) return null;
  if (d.v === undefined) return 1;
  return Number.isInteger(d.v) && d.v >= 1 ? d.v : null;
}
// Résultat : { data, ok, keep }. ok : data est utilisable telle quelle. keep : garder une copie de l'original à part.
function migrate(raw, { current, steps, valid, what }) {
  if (raw === null || raw === undefined) return { data: null, ok: false, keep: false };
  const v = dataVersion(raw);
  if (v === null) {
    logError("migrate-" + what, new Error(`données illisibles (${Array.isArray(raw) ? "liste" : typeof raw})`));
    return { data: raw, ok: false, keep: true };
  }
  if (v > current) {
    // Données d'une version plus récente de la page : on les lit si leur forme est connue, et on en garde une copie.
    logError("migrate-" + what, new Error(`version ${v} plus récente que ${current}`));
    return { data: raw, ok: valid(raw), keep: true };
  }
  let d = raw;
  for (let n = v; n < current; n++) {
    try { d = steps[n](d); }
    catch (e) { logError("migrate-" + what, e); return { data: raw, ok: false, keep: true }; }
  }
  if (!valid(d)) {
    logError("migrate-" + what, new Error(`forme inconnue (version ${v})`));
    return { data: raw, ok: false, keep: true };
  }
  return { data: d, ok: true, keep: false };
}
const migrateState = (raw) => migrate(raw, { current: STATE_V, steps: STATE_STEPS, valid: looksLikeState, what: "state" });
const migratePrefs = (raw) => migrate(raw, { current: PREFS_V, steps: PREFS_STEPS, valid: isPlainObj, what: "prefs" });

// ---------- Copie de secours dans localStorage (FOU-40) ----------
// IndexedDB est la copie principale. localStorage n'a qu'environ 5 Mo pour tout le site (réglages, photo, journal) :
// au-delà de LS_MAX caractères, on n'y met plus l'historique complet mais une copie légère (dernier import +
// listes actuelles), et si même celle-ci est trop grosse (très gros compte), rien du tout.
const LS_MAX = 1500000;
// Texte à écrire dans localStorage pour cet état, ou null s'il est trop gros même en copie légère.
function lsCopyText(s, max = LS_MAX) {
  const full = JSON.stringify(s);
  if (full.length <= max) return full;
  const last = s.snapshots[s.snapshots.length - 1];
  const lite = { v: s.v, lite: true, snapshots: last ? [last] : [], events: [], followers: s.followers };
  if (s.following) { lite.following = s.following; lite.followingAt = s.followingAt; }
  let t = JSON.stringify(lite);
  if (t.length <= max) return t;
  delete lite.following; delete lite.followingAt;
  t = JSON.stringify(lite);
  return t.length <= max ? t : null;
}
// Au chargement : la copie IndexedDB et celle de localStorage (déjà migrées). On garde celle qui a le plus d'imports ;
// à égalité, la complète. Une copie légère ne sert que si IndexedDB n'a rien (vidée par iOS, par exemple).
function pickState(idb, ls) {
  const all = [idb, ls].filter(Boolean);
  if (!all.length) return null;
  const best = all.sort((a, b) => (b.snapshots.length - a.snapshots.length) || ((a.lite ? 1 : 0) - (b.lite ? 1 : 0)))[0];
  if (!best.lite) return best;
  logError("start-lite", new Error(`seule la copie légère est disponible (${best.snapshots.length} import)`));
  const s = { ...best };
  delete s.lite;
  return s;
}
