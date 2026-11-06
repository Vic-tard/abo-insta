// channel.json (canaux de mise à jour, FOU-28) et signal « je suis bien démarrée » de la page.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const root = new URL("..", import.meta.url);
const html = readFileSync(new URL("index.html", root), "utf8");
const BUILD = html.match(/const BUILD = "([^"]+)"/)[1];

test("channel.json est bien écrit (sinon l'app l'ignore)", () => {
  const ch = JSON.parse(readFileSync(new URL("channel.json", root), "utf8"));
  assert.deepEqual(Object.keys(ch).sort(), ["stable", "urgence"]);
  assert.equal(typeof ch.urgence, "boolean", "urgence doit valoir true ou false (sans guillemets)");
  if (ch.stable !== null) {
    assert.match(ch.stable, /^\d{4}-\d{2}-\d{2}-\d{4}$/, "stable doit avoir la forme AAAA-MM-JJ-HHMM");
    assert.ok(ch.stable <= BUILD, `stable (${ch.stable}) ne peut pas être plus récent que la page en ligne (${BUILD})`);
  }
});

test("la page dit à l'app qu'elle a bien démarré", () => {
  assert.match(html, /nativePost\(\{ type: "started", build: BUILD \}\)/);
});
