// Les images du Zieuteur 3D (dossier guide/) sont lues sur zieuton.com puis GitHub Pages quand la page tourne « dans l'app ».
// Pendant les tests, on les sert depuis le dépôt : une image pas encore en ligne (PR pas encore fusionnée) ou un réseau
// coupé ne doivent pas faire échouer un test qui ne porte pas sur elles.
import { readFileSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../..", import.meta.url));
export async function serveGuide(page) {
  const serve = async (r) => {
    const f = root + "guide/" + r.request().url().split("/guide/")[1].split("?")[0];
    if (existsSync(f)) await r.fulfill({ contentType: "image/png", body: readFileSync(f) });
    else await r.abort();
  };
  await page.route("https://zieuton.com/guide/**", serve);
  await page.route("https://vic-tard.github.io/abo-insta/guide/**", serve);
}
