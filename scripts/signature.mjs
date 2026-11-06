// Signature des mises à jour de la page (FOU-29).
// La coque iPhone n'enregistre une page téléchargée que si elle est signée par la clé de Victor.
//
//   node scripts/signature.mjs signer <dossier>    → écrit index.html.sig et channel.json.sig dans le dossier
//                                                    (clé secrète lue dans PAGE_SIGNING_KEY, jamais dans le dépôt)
//   node scripts/signature.mjs verifier <dossier>  → vérifie les .sig avec la clé publique écrite dans la coque
//   node scripts/signature.mjs nouvelle-cle        → crée une paire de clés (Victor utilise plutôt scripts/creer-cle.swift)
//
// Format : Ed25519. Clés et signatures brutes (32 et 64 octets) écrites en base64, comme CryptoKit
// (Curve25519.Signing) côté iPhone. Lancé par .github/workflows/publier.yml à chaque mise en ligne.
import { createPrivateKey, createPublicKey, generateKeyPairSync, sign, verify } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

/** Les fichiers signés, à côté desquels on publie un « .sig ». */
export const SIGNED_FILES = ["index.html", "channel.json"];

// En-têtes DER fixes qui enveloppent une clé Ed25519 brute (RFC 8410).
const PKCS8 = Buffer.from("302e020100300506032b657004220420", "hex");
const SPKI = Buffer.from("302a300506032b6570032100", "hex");

/** Base64 strict d'exactement `size` octets (une faute de copier-coller est refusée). */
function rawKey(text, size, what) {
  const clean = String(text ?? "").trim();
  const raw = Buffer.from(clean, "base64");
  if (raw.length !== size || raw.toString("base64") !== clean) {
    throw new Error(`${what} mal recopiée : il faut ${size} octets en base64 (${clean.length} caractères reçus).`);
  }
  return raw;
}

export function privateKeyFromSecret(text) {
  return createPrivateKey({ key: Buffer.concat([PKCS8, rawKey(text, 32, "Clé secrète")]), format: "der", type: "pkcs8" });
}

export function publicKeyFromText(text) {
  return createPublicKey({ key: Buffer.concat([SPKI, rawKey(text, 32, "Clé publique")]), format: "der", type: "spki" });
}

/** La clé publique (base64) qui va avec une clé secrète. */
export function publicText(privateKey) {
  return createPublicKey(privateKey).export({ format: "der", type: "spki" }).subarray(SPKI.length).toString("base64");
}

/** Contenu d'un fichier .sig : la signature en base64 sur une ligne. */
export function signData(data, privateKey) {
  return sign(null, data, privateKey).toString("base64") + "\n";
}

export function isValid(data, sigText, publicKeyText) {
  const sig = Buffer.from(String(sigText ?? "").trim(), "base64");
  if (sig.length !== 64) return false;
  return verify(null, data, publicKeyFromText(publicKeyText), sig);
}

export function newKeyPair() {
  const { privateKey } = generateKeyPairSync("ed25519");
  const secret = privateKey.export({ format: "der", type: "pkcs8" }).subarray(PKCS8.length).toString("base64");
  return { secret, public: publicText(privateKey) };
}

/** La clé publique écrite dans la coque (`PageSignature.publicKey`). */
export function shellPublicKey(root = new URL("..", import.meta.url)) {
  const swift = readFileSync(new URL("ios/Zieuton/WebViewController.swift", root), "utf8");
  const m = swift.match(/static let publicKey = "([^"]*)"/);
  if (!m) throw new Error("PageSignature.publicKey introuvable dans ios/Zieuton/WebViewController.swift");
  return m[1];
}

function main([cmd, dir]) {
  if (cmd === "nouvelle-cle") {
    const pair = newKeyPair();
    console.log(`Clé SECRÈTE (secret GitHub PAGE_SIGNING_KEY, à ne montrer à personne) :\n${pair.secret}\n`);
    console.log(`Clé PUBLIQUE (à écrire dans la coque, pas secrète) :\n${pair.public}`);
    return;
  }
  if ((cmd !== "signer" && cmd !== "verifier") || !dir) {
    console.error("Usage : node scripts/signature.mjs signer <dossier> | verifier <dossier> | nouvelle-cle");
    process.exit(1);
  }
  const expected = shellPublicKey();
  if (cmd === "signer") {
    if (!process.env.PAGE_SIGNING_KEY) {
      console.error("ÉCHEC : le secret GitHub PAGE_SIGNING_KEY est vide. Voir docs/MISES-A-JOUR.md, partie 4.");
      process.exit(1);
    }
    const key = privateKeyFromSecret(process.env.PAGE_SIGNING_KEY);
    if (publicText(key) !== expected) {
      console.error("ÉCHEC : le secret PAGE_SIGNING_KEY ne correspond pas à la clé publique écrite dans la coque.\n" +
        "Les iPhones refuseraient la page. Voir docs/MISES-A-JOUR.md, partie 4.");
      process.exit(1);
    }
    for (const name of SIGNED_FILES) {
      writeFileSync(join(dir, name + ".sig"), signData(readFileSync(join(dir, name)), key));
    }
  }
  for (const name of SIGNED_FILES) {
    const ok = isValid(readFileSync(join(dir, name)), readFileSync(join(dir, name + ".sig"), "utf8"), expected);
    if (!ok) { console.error(`ÉCHEC : ${name}.sig ne correspond pas à ${name}`); process.exit(1); }
    console.log(`${name} : signature bonne`);
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main(process.argv.slice(2));
