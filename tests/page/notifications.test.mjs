// FOU-126 : notifications pendant l'attente de l'export, côté page. Autorisation demandée avant Instagram (« Je te préviens ? »),
// état réel des rappels et de la dernière vérification sur l'écran d'attente, replis pour une coque plus ancienne (build 15),
// et une demande attachée à son compte. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

// Ouvre la page comme dans l'app. prefs : réglages enregistrés ; version : celle de la coque ; status : réponse de la coque.
async function open({ version = 10, prefs = {}, status = null, waitMins = null } = {}) {
  const page = await browser.newPage({ viewport: { width: 393, height: 852 }, locale: "fr-FR", reducedMotion: "reduce" });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(([v, p, w]) => {
    window.__sent = [];
    window.ZYEUTO_APP = { version: v, embedded: true };
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (m) => window.__sent.push(m) } } };
    const x = { welcomed: true, ...p };
    if (w !== null) x.requestedAt = new Date(Date.now() - w * 60000).toISOString();
    localStorage.setItem("abo-prefs", JSON.stringify(x));
  }, [version, prefs, waitMins]);
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function");
  if (status) await page.evaluate((s) => window.zyeutoNotif({ status: s }), status);
  await page.evaluate(() => renderGuided());
  page.errors = errors;
  return page;
}
const sent = (page) => page.evaluate(() => window.__sent);
const gfText = (page) => page.evaluate(() => document.getElementById("gf").innerText);

test("coque version 9 (build 15) : textes de repli sans promesse, aucun nouveau message", async () => {
  const page = await open({ version: 9, waitMins: 5 });
  const txt = await gfText(page);
  assert.match(txt, /Ouvre Zieuton pour vérifier/);
  assert.match(txt, /Instagram t'envoie aussi un e-mail/);
  assert.doesNotMatch(txt, /Rappel activé|Je t'envoie un rappel|coupées/);
  assert.equal((await sent(page)).filter((m) => m.type === "notif").length, 0, "rien de nouveau envoyé à une coque 9");
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("coque version 10 : la page demande l'état de l'autorisation au démarrage", async () => {
  const page = await open({ waitMins: 5 });
  assert.ok((await sent(page)).some((m) => m.type === "notif" && m.action === "status"));
  await page.close();
});

test("notifications autorisées : « Rappel activé »", async () => {
  const page = await open({ waitMins: 5, status: "authorized" });
  const txt = await gfText(page);
  assert.match(txt, /Rappel activé/);
  assert.match(txt, /30 min après ta demande/);
  await page.close();
});

test("notifications refusées : on le dit, avec « Ouvrir les Réglages »", async () => {
  const page = await open({ waitMins: 5, status: "denied" });
  const txt = await gfText(page);
  assert.match(txt, /Tes notifications sont coupées/);
  assert.match(txt, /Je ne pourrai pas te prévenir/);
  assert.doesNotMatch(txt, /Rappel activé/);
  await page.click("#gw-notif-set");
  assert.ok((await sent(page)).some((m) => m.type === "notif" && m.action === "settings"));
  await page.close();
});

test("jamais demandées (« Plus tard ») : carte « Activer les notifications »", async () => {
  const page = await open({ waitMins: 5, status: "notDetermined" });
  assert.match(await gfText(page), /Recevoir les nouvelles de ton export/);
  await page.click("#gw-notif-ask");
  assert.ok((await sent(page)).some((m) => m.type === "notif" && m.action === "ask"));
  await page.close();
});

test("dernière vérification de l'app : chaque état a son texte, jamais « prêt » sans l'écran « prête »", async () => {
  const cases = [
    ["pending", /✓ Vérifié à \d\d:\d\d\s:\spas encore prêt/],
    ["toCheck", /peut-être prêt.*vérifie sa date/],
    ["offline", /Pas de connexion internet/],
    ["login", /Reconnecte-toi à Instagram/],
    ["unknown", /Je n'ai pas pu regarder chez Instagram/],
  ];
  for (const [state, re] of cases) {
    const page = await open({ waitMins: 5, status: "authorized" });
    await page.evaluate((s) => window.zyeutoWatch({ state: s, at: new Date().toISOString() }), state);
    const txt = await gfText(page);
    assert.match(txt, re, state);
    assert.equal(await page.textContent("#gf-title"), "Instagram prépare ta liste", state);
    assert.deepEqual(page.errors, []);
    await page.close();
  }
});

test("une vérification plus ancienne que la demande est ignorée", async () => {
  const page = await open({ waitMins: 5, status: "authorized" });
  await page.evaluate(() => window.zyeutoWatch({ state: "offline", at: new Date(Date.now() - 3600e3).toISOString() }));
  assert.doesNotMatch(await gfText(page), /Pas de connexion/);
  await page.close();
});

test("aucune promesse de surveillance sur l'écran d'attente", async () => {
  for (const status of ["authorized", "denied", "notDetermined"]) {
    const page = await open({ waitMins: 5, status });
    const txt = await gfText(page);
    assert.doesNotMatch(txt, /je guette|dès que je (le|la) vois|en permanence|en continu|expire/i, status);
    await page.close();
  }
});

// Ouvre Instagram en mode demande (premier export) et rend ce qui a été envoyé à la coque.
const metaSent = async (page) => (await sent(page)).filter((m) => m.type === "meta" && m.mode === "request").length;

test("« Je te préviens ? » avant Instagram, puis Instagram s'ouvre avec « Plus tard »", async () => {
  const page = await open({ status: "notDetermined" });
  await page.evaluate(() => wkGo("request"));
  assert.ok(await page.isVisible("#nq"));
  assert.match(await page.textContent("#nq"), /Je te préviens/);
  assert.equal(await metaSent(page), 0, "Instagram attend la réponse");
  await page.click("#nq-later");
  assert.equal(await metaSent(page), 1, "« Plus tard » : Instagram s'ouvre quand même");
  assert.ok(await page.evaluate(() => !!JSON.parse(localStorage.getItem("abo-prefs")).notifLaterAt));
  // Pas de nouvelle question pendant 7 jours.
  await page.evaluate(() => wkGo("request"));
  assert.equal(await page.locator("#nq").count(), 0);
  assert.equal(await metaSent(page), 2);
  await page.close();
});

test("« Activer les notifications » : vraie demande iOS, puis Instagram s'ouvre quelle que soit la réponse", async () => {
  for (const answer of ["authorized", "denied"]) {
    const page = await open({ status: "notDetermined" });
    await page.evaluate(() => wkGo("request"));
    await page.click("#nq-yes");
    assert.ok((await sent(page)).some((m) => m.type === "notif" && m.action === "ask"));
    assert.equal(await metaSent(page), 0);
    await page.evaluate((a) => window.zyeutoNotif({ status: a }), answer);
    assert.equal(await metaSent(page), 1, answer);
    await page.close();
  }
});

test("déjà autorisée, déjà refusée, ou « Plus tard » il y a moins de 7 jours : pas d'écran, Instagram s'ouvre", async () => {
  for (const [status, prefs] of [["authorized", {}], ["denied", {}], ["notDetermined", { notifLaterAt: new Date(Date.now() - 2 * 864e5).toISOString() }]]) {
    const page = await open({ status, prefs });
    await page.evaluate(() => wkGo("request"));
    assert.equal(await page.locator("#nq").count(), 0, status);
    assert.equal(await metaSent(page), 1, status);
    await page.close();
  }
  const old = await open({ status: "notDetermined", prefs: { notifLaterAt: new Date(Date.now() - 8 * 864e5).toISOString() } });
  await old.evaluate(() => wkGo("request"));
  assert.ok(await old.isVisible("#nq"), "après 7 jours, la question revient");
  await old.close();
});

test("coque version 9 : pas d'écran « Je te préviens ? »", async () => {
  const page = await open({ version: 9 });
  await page.evaluate(() => { window.zyeutoNotif({ status: "notDetermined" }); wkGo("request"); });
  assert.equal(await page.locator("#nq").count(), 0);
  assert.equal(await metaSent(page), 1);
  await page.close();
});

test("plusieurs comptes : la demande garde son compte, passer sur l'autre ne l'annule pas", async () => {
  const accts = [{ id: "a1", slot: 1, h: [], n: 0 }, { id: "a2", slot: 2, h: [], n: 0 }];
  // Sur le compte de la demande : « en attente » envoyé avec le compte.
  const p1 = await open({ waitMins: 5, prefs: { accts, acctCur: "a1", requestAcct: "a1" } });
  await p1.evaluate(() => renderWeekly());
  const s1 = (await sent(p1)).filter((m) => m.type === "exportState");
  assert.ok(s1.length && s1.every((m) => m.pending === true && m.acct === "a1"));
  await p1.close();
  // Sur l'autre compte : jamais « plus en attente » (la coque annulerait les rappels à tort).
  const p2 = await open({ waitMins: 5, prefs: { accts, acctCur: "a2", requestAcct: "a1" } });
  await p2.evaluate(() => renderWeekly());
  assert.equal((await sent(p2)).filter((m) => m.type === "exportState").length, 0);
  assert.equal(await p2.evaluate(() => reqPending()), false);
  assert.ok(await p2.evaluate(() => !!JSON.parse(localStorage.getItem("abo-prefs")).requestedAt), "la demande est gardée");
  await p2.close();
});

test("demande prouvée : elle note le compte affiché", async () => {
  const accts = [{ id: "a1", slot: 1, h: [], n: 0 }, { id: "a2", slot: 2, h: [], n: 0 }];
  const page = await open({ prefs: { accts, acctCur: "a2" } });
  await page.evaluate(() => window.zyeutoMeta("requested", { existing: false }));
  assert.equal(await page.evaluate(() => JSON.parse(localStorage.getItem("abo-prefs")).requestAcct), "a2");
  await page.close();
});

test("aucune promesse de surveillance dans le texte de la page", async () => {
  const { readFileSync } = await import("node:fs");
  const src = readFileSync(root + "index.html", "utf8");
  assert.doesNotMatch(src, /je guette|je te dis dès que|dès que je (le|la) vois|je regarderai quand/i);
});
