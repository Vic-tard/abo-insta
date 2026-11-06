// Signature des mises à jour de la page (FOU-29) : ce que fait le robot de mise en ligne.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { execFileSync } from "node:child_process";
import {
  isValid, newKeyPair, privateKeyFromSecret, publicText, shellPublicKey, signData, SIGNED_FILES,
} from "../scripts/signature.mjs";

const root = new URL("..", import.meta.url);
const fixtures = new URL("fixtures/signature/", import.meta.url);

test("signature bonne, page modifiée, autre clé, signature absente", () => {
  const pair = newKeyPair();
  const key = privateKeyFromSecret(pair.secret);
  assert.equal(publicText(key), pair.public);
  const page = Buffer.from('<html>const BUILD = "2026-11-07-1000"</html>');
  const sig = signData(page, key);
  assert.ok(isValid(page, sig, pair.public), "signature bonne");
  assert.ok(!isValid(Buffer.from(page.toString() + " "), sig, pair.public), "page modifiée");
  assert.ok(!isValid(page, sig, newKeyPair().public), "autre clé");
  assert.ok(!isValid(page, "", pair.public), "signature absente");
  assert.ok(!isValid(page, "<html>404</html>", pair.public), "page d'erreur à la place");
});

test("une clé secrète mal recopiée est refusée avec un message clair", () => {
  const { secret } = newKeyPair();
  assert.throws(() => privateKeyFromSecret(secret.slice(0, -2)), /mal recopiée/);
  assert.throws(() => privateKeyFromSecret(""), /mal recopiée/);
  assert.doesNotThrow(() => privateKeyFromSecret(` ${secret}\n`), "espaces autour tolérés");
});

test("l'exemple signé (aussi vérifié par l'iPhone dans les tests Swift) est valide", () => {
  const page = readFileSync(new URL("page.html", fixtures));
  const sig = readFileSync(new URL("page.html.sig", fixtures), "utf8");
  const pub = readFileSync(new URL("cle-publique-de-test.txt", fixtures), "utf8").trim();
  assert.ok(isValid(page, sig, pub));
});

test("le robot signe index.html et channel.json, et refuse une clé qui n'est pas celle de l'app", () => {
  assert.deepEqual(SIGNED_FILES, ["index.html", "channel.json"]);
  const dir = mkdtempSync(join(tmpdir(), "zieuton-sig-"));
  for (const f of SIGNED_FILES) writeFileSync(join(dir, f), readFileSync(new URL(f, root)));
  const run = (secret) => execFileSync(process.execPath, ["scripts/signature.mjs", "signer", dir],
    { cwd: new URL(".", root), env: { ...process.env, PAGE_SIGNING_KEY: secret }, stdio: "pipe" });
  assert.throws(() => run(""), "secret vide : échec");
  assert.throws(() => run(newKeyPair().secret), "clé qui ne correspond pas à l'app : échec");
});

test("la mise en ligne passe par la signature", () => {
  const wf = readFileSync(new URL(".github/workflows/publier.yml", root), "utf8");
  assert.match(wf, /node scripts\/signature\.mjs signer/);
  assert.match(wf, /secrets\.PAGE_SIGNING_KEY/);
});

test("la clé publique de Victor est écrite dans l'app (PageSignature.publicKey)", () => {
  const pub = shellPublicKey();
  assert.ok(pub, "PageSignature.publicKey est encore vide : Victor doit créer la clé (docs/MISES-A-JOUR.md, partie 4)");
  assert.doesNotThrow(() => isValid(Buffer.from("x"), "", pub), "clé publique mal recopiée");
  // Première clé du 2026-11-06 : sa partie secrète a été montrée sur une capture, elle ne doit jamais servir.
  assert.notEqual(pub, "HfbycYnMdY1Yd9Gq+NjlYCcB47wZsdRdUfcWVKzUXV8=", "clé compromise : en créer une nouvelle");
});
