// Outils des tests : charge js/zieuton-core.js comme dans la page, fabrique des exports d'exemple (JSON et .zip).
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { deflateRawSync } from "node:zlib";
import vm from "node:vm";

const root = fileURLToPath(new URL("..", import.meta.url));
export const fixture = (p) => root + "tests/fixtures/" + p;
const CORE = readFileSync(root + "js/zieuton-core.js", "utf8");

// Ce que le reste de index.html fournit au bloc ZIEUTON-CORE. nf et fmtDate sont les mêmes que dans la page ;
// les comptes sont réduits à l'essentiel (liste des comptes suivis, compte affiché, verrou « un compte par Plus »).
const HOST = `
"use strict";
let state = { snapshots: [], events: [], followers: {} };
const DF_LONG = new Intl.DateTimeFormat("fr-FR", { day: "numeric", month: "short", year: "numeric" });
const fmtDate = (iso) => DF_LONG.format(new Date(iso));
const nf = (n) => n.toLocaleString("fr-FR");
let __accts = [{ id: "a1", slot: 1, h: [], n: 0 }], __cur = "a1", __lock = false;
// Le journal d'erreurs de la page (FOU-30) : ici, les erreurs sont gardées pour que les tests les vérifient.
const __errors = [];
function logError(where, err) { __errors.push({ where, message: String(err && err.message || err) }); }
const accts = () => __accts;
const curAcct = () => __accts.find((a) => a.id === __cur) || __accts[0];
const acctLockOn = () => __lock;
function otherAccountError(what, names) {
  const known = names && knownAcct(names);
  const e = new Error(known ? what + " est celui d'un autre compte suivi ici." : what + " vient d'un autre compte Instagram. Rien n'a été enregistré.");
  e.otherAccount = known ? { known: known.id } : { add: true };
  return e;
}
`;

// Chaque appel donne une « page » neuve, avec son propre historique vide.
export function loadCore() {
  const ctx = vm.createContext({
    TextDecoder, TextEncoder, crypto: globalThis.crypto, DecompressionStream, Response, URL, console,
  });
  vm.runInContext(HOST, ctx, { filename: "page-simulee.js" });
  vm.runInContext('"use strict";\n' + CORE, ctx, { filename: "js/zieuton-core.js", lineOffset: -1 });
  return vm.runInContext(`({
    cleanName, nameFromHref, listKind, parseAccounts, parseJsonText, listZip, readZipEntry, readExport,
    hashNames, nameHash, acctPrint, acctLikeness, isOtherAccount, knownAcct, recordSnapshot,
    STATE_V, PREFS_V, migrateState, migratePrefs, LS_MAX, lsCopyText, pickState,
    get errors() { return __errors; },
    get state() { return state; },
    set state(v) { state = v; },
    // Verrou « un seul compte Instagram par Plus » : actif seulement dans l'app.
    lock(on) { __lock = on; },
    // Comme rememberAccount() dans la page : retient l'empreinte du compte affiché.
    remember(names, id = __cur) { const a = __accts.find((x) => x.id === id); a.h = acctPrint(names); a.n = names.length; },
    addAccount(id, slot) { __accts.push({ id, slot, h: [], n: 0 }); },
  })`, ctx);
}

// Objets venus de la page → objets ordinaires, pour les comparer avec assert.deepStrictEqual.
export const plain = (x) => JSON.parse(JSON.stringify(x));

// ---------- Exports d'exemple ----------
export const pseudo = (prefix, i) => `${prefix}${String(i).padStart(6, "0")}`;
export const names = (prefix, from, to) => Array.from({ length: to - from }, (_, k) => pseudo(prefix, from + k));

// followers_1.json au format récent d'Instagram (pseudo dans « title »).
export function followersJson(list, t0 = 1704067200) {
  return JSON.stringify(list.map((n, i) => ({
    title: n, media_list_data: [],
    string_list_data: [{ href: `https://www.instagram.com/_u/${n}`, timestamp: t0 + i * 60 }],
  })));
}
export function followingJson(list, t0 = 1704067200) {
  return JSON.stringify({ relationships_following: list.map((n, i) => ({
    title: n, string_list_data: [{ href: `https://www.instagram.com/_u/${n}`, timestamp: t0 + i * 60 }],
  })) });
}
export const jsonFile = (text, name, date = new Date("2026-01-10T12:00:00")) => new File([text], name, { lastModified: date.getTime() });

// ---------- Petit fabricant de .zip (sans bibliothèque) ----------
const CRC = (() => { const t = new Uint32Array(256); for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; } return t; })();
function crc32(buf) { let c = 0xffffffff; for (const b of buf) c = CRC[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }

// entries : [{ name, text }]. date : date des fichiers dans le .zip (c'est la date de l'export pour l'app).
export function makeZip(entries, { date = new Date("2026-01-10T12:00:00"), store = false, name = "instagram-export.zip" } = {}) {
  const dosTime = (date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1);
  const dosDate = ((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate();
  const locals = [], central = [];
  let offset = 0;
  for (const e of entries) {
    const raw = Buffer.from(e.text, "utf8"), data = store ? raw : deflateRawSync(raw), nameBuf = Buffer.from(e.name, "utf8");
    const crc = crc32(raw), method = store ? 0 : 8;
    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0); lh.writeUInt16LE(20, 4); lh.writeUInt16LE(0x0800, 6); lh.writeUInt16LE(method, 8);
    lh.writeUInt16LE(dosTime, 10); lh.writeUInt16LE(dosDate, 12); lh.writeUInt32LE(crc, 14);
    lh.writeUInt32LE(data.length, 18); lh.writeUInt32LE(raw.length, 22); lh.writeUInt16LE(nameBuf.length, 26);
    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0); ch.writeUInt16LE(20, 4); ch.writeUInt16LE(20, 6); ch.writeUInt16LE(0x0800, 8); ch.writeUInt16LE(method, 10);
    ch.writeUInt16LE(dosTime, 12); ch.writeUInt16LE(dosDate, 14); ch.writeUInt32LE(crc, 16);
    ch.writeUInt32LE(data.length, 20); ch.writeUInt32LE(raw.length, 24); ch.writeUInt16LE(nameBuf.length, 28); ch.writeUInt32LE(offset, 42);
    locals.push(lh, nameBuf, data); central.push(ch, nameBuf);
    offset += 30 + nameBuf.length + data.length;
  }
  const cd = Buffer.concat(central), end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0); end.writeUInt16LE(entries.length, 8); end.writeUInt16LE(entries.length, 10);
  end.writeUInt32LE(cd.length, 12); end.writeUInt32LE(offset, 16);
  return new File([Buffer.concat([...locals, cd, end])], name);
}

// Le chemin des listes dans un vrai export Instagram.
export const DIR = "connections/followers_and_following/";
