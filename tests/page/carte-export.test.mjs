// FOU-119 (Victor, 25 nov.) : la carte d'export de l'accueil dit seulement ce qui est connu.
// - après un import qui garde la demande : « Export à vérifier », la date de la demande dessous, « Vérifier mon export » ;
// - « Instagram prépare ta liste » seulement quand Instagram indique que l'export est en attente ;
// - étapes fidèles à l'état connu (« ? » là où il faut vérifier), sans pourcentage ni estimation ;
// - titre sur deux lignes au plus, sur petit iPhone, en clair et en sombre. Lancer : npm run test:lecteur.
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";
const { chromium } = createRequire(import.meta.url)("playwright");

const root = fileURLToPath(new URL("../..", import.meta.url));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });

const ago = (min) => new Date(Date.now() - min * 60000).toISOString();
// Un import d'il y a 2 jours, une demande d'il y a 26 h, puis `x` (état de la demande).
async function card(x, { width = 393, colorScheme = "light" } = {}) {
  const page = await browser.newPage({ viewport: { width, height: 700 }, locale: "fr-FR", reducedMotion: "reduce", colorScheme });
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.addInitScript(() => {
    window.ZYEUTO_APP = { version: 12, embedded: true };
    window.__sent = [];
    window.webkit = { messageHandlers: { zyeuto: { postMessage: (message) => window.__sent.push(message) } } };
    localStorage.setItem("abo-prefs", JSON.stringify({ welcomed: true, demoTourDone: true }));
  });
  await page.goto("file://" + root + "index.html");
  await page.waitForFunction(() => typeof renderGuided === "function" && !loading);
  await page.evaluate(async ([x, a2, a26, a120]) => {
    const followers = {};
    for (let i = 0; i < 300; i++) followers["ami" + i] = 1700000000 + i;
    pending = { followers, following: null, date: new Date(a2), dated: true, exact: true, source: "export.zip" };
    await commit(pending.date.toISOString());
    document.getElementById("first").hidden = true;
    Object.assign(prefs, { requestedAt: a26, lastImportAt: x.requestKept ? a120 : a2 }, x);
    if (x.requestKept) { prefs.requestKept = a26; prefs.importAnswer = { req: a26, a: "unknown" }; }
    delete prefs.importAsk; savePrefs(); renderAll(); document.getElementById("ia")?.remove();
  }, [x, ago(2 * 1440), ago(26 * 60), ago(120)]);
  page.errors = errors;
  return page;
}
const read = (page) => page.evaluate(() => ({
  title: document.getElementById("weekly-title").textContent,
  due: document.getElementById("due").textContent,
  go: document.getElementById("wk-go-t").textContent,
  steps: [...document.querySelectorAll("#wk-steps li")].map((li) => li.querySelector("i").textContent + (li.classList.contains("on") ? "*" : "")),
  card: document.getElementById("weekly").innerText,
}));

test("demande gardée après un import : « Export à vérifier », date dessous, « Vérifier mon export », étape 2 à vérifier", async () => {
  const page = await card({ requestKept: true });
  const c = await read(page);
  assert.equal(c.title, "Export à vérifier");
  assert.match(c.due, /^Demandé le \d{1,2} \S+ \d{4}$/);
  assert.equal(c.go, "Vérifier mon export");
  assert.deepEqual(c.steps, ["✓", "?*", "3"]);
  assert.doesNotMatch(c.card, /prépare ta liste|se prépare|%/);
  assert.deepEqual(page.errors, []);
  await page.close();
});

test("Instagram indique que l'export est en attente : « Instagram prépare ta liste »", async () => {
  for (const x of [{}, { watch: { state: "pending", at: ago(5) } }]) {
    const page = await card(x);
    const c = await read(page);
    assert.equal(c.title, "Instagram prépare ta liste");
    assert.match(c.due, /^Demandé il y a 26 h$/);
    assert.doesNotMatch(c.card, /%|devrait|environ/);
    await page.close();
  }
});

test("dernière vérification sans réponse claire : « Export à vérifier », jamais « prépare »", async () => {
  for (const state of ["toCheck", "offline", "login", "unknown"]) {
    const page = await card({ watch: { state, at: ago(5) } });
    const c = await read(page);
    assert.equal(c.title, "Export à vérifier", state);
    assert.match(c.due, /^Demandé le /, state);
    assert.equal(c.go, "Vérifier mon export", state);
    assert.match(await page.textContent("#wk-chip"), /À vérifier/, state);
    assert.doesNotMatch(c.card, /prépare ta liste/, state);
    await page.close();
  }
});

test("demande pas encore confirmée (à vérifier) : aucune coche sur « Demander »", async () => {
  const page = await card({ requestUnsure: true });
  const c = await read(page);
  assert.equal(c.title, "Demande à vérifier");
  assert.deepEqual(c.steps, ["?*", "2", "3"]);
  await page.close();
});

test("un import qui garde une demande non confirmée ne confirme ni la demande ni sa date", async () => {
  const page = await card({ requestKept: true, requestUnsure: true });
  const c = await read(page);
  assert.equal(c.title, "Demande à vérifier");
  assert.equal(c.due, "Demande à vérifier chez Instagram");
  assert.equal(c.go, "Vérifier dans Instagram");
  assert.deepEqual(c.steps, ["?*", "2", "3"]);
  await page.locator("#wk-steps li.on.ask").click();
  assert.equal(await page.locator("#gf-redo").count(), 0);
  assert.equal(await page.evaluate(() => window.__sent.findLast((message) => message.type === "meta")?.mode), "request");
  assert.equal(await page.evaluate(() => prefs.requestUnsure), true);
  await page.close();
});

test("une demande déjà repérée sans date de création n'affiche pas la date de début du suivi", async () => {
  for (const x of [{ requestKept: true }, { watch: { state: "offline", at: ago(5) } }]) {
    const page = await card({ requestExisting: true, ...x });
    const c = await read(page);
    assert.equal(c.title, "Export à vérifier");
    assert.equal(c.due, "Demande repérée chez Instagram");
    assert.equal(c.go, "Vérifier mon export");
    assert.deepEqual(c.steps, ["✓", "?*", "3"]);
    await page.close();
  }
});

test("export vu prêt : « Ton export est prêt », étapes 1 et 2 cochées", async () => {
  const page = await card({ readyAt: ago(3) });
  const c = await read(page);
  assert.equal(c.title, "Ton export est prêt");
  assert.deepEqual(c.steps, ["✓", "✓", "3*"]);
  await page.close();
});

test("petit iPhone (320), clair et sombre : titre en deux lignes au plus, rien ne dépasse de la carte", async () => {
  for (const colorScheme of ["light", "dark"]) {
    for (const x of [{ requestKept: true }, { requestUnsure: true }, {}, { readyAt: ago(3) }, { watch: { state: "toCheck", at: ago(5) } }]) {
      const page = await card(x, { width: 320, colorScheme });
      if (x.requestKept || x.requestUnsure || x.watch) {
        const step = page.locator("#wk-steps li.on.ask");
        assert.equal(await step.isVisible(), true, `${colorScheme} : l'étape à vérifier est visible`);
        assert.equal(await step.locator("i").textContent(), "?");
      }
      const m = await page.evaluate(() => {
        const t = document.getElementById("weekly-title"), r = t.getBoundingClientRect(), lh = parseFloat(getComputedStyle(t).lineHeight);
        const w = document.getElementById("weekly").getBoundingClientRect();
        const out = [...document.querySelectorAll("#weekly *")].filter((e) => e.offsetParent && (e.getBoundingClientRect().right > w.right + 0.5 || e.getBoundingClientRect().left < w.left - 0.5)).map((e) => e.id || e.className);
        return { lines: Math.round(r.height / lh), cut: t.scrollWidth > t.clientWidth + 1, out };
      });
      assert.ok(m.lines <= 2, `${colorScheme} ${JSON.stringify(x)} : ${m.lines} lignes`);
      assert.equal(m.cut, false);
      assert.deepEqual(m.out, [], `${colorScheme} ${JSON.stringify(x)}`);
      assert.deepEqual(page.errors, []);
      await page.close();
    }
  }
});
