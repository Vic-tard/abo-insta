// Relecture FOU-124 : le bandeau guide d'Instagram a un geste « toucher » global. Il ne doit pas avaler le toucher
// du bouton « Revenir dans Zieuton » (ni d'aucun autre bouton du bandeau). Vérifié dans le code Swift ; l'essai
// réel se fait sur iPhone. Lancer : npm run test:lecteur.
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const src = readFileSync(new URL("../../ios/Zieuton/WebViewController.swift", import.meta.url), "utf8");

test("le geste du bandeau a un délégué qui laisse passer les boutons (UIControl)", () => {
  const add = src.match(/let (\w+) = UITapGestureRecognizer\(target: self, action: #selector\(bannerTapped\)\)([\s\S]{0,200}?)banner\.addGestureRecognizer\(\1\)/);
  assert.ok(add, "geste du bandeau introuvable");
  assert.match(add[2], new RegExp(add[1] + "\\.delegate = self"));
  const ext = src.match(/extension MetaViewController: UIGestureRecognizerDelegate \{([\s\S]*?)\n\}/);
  assert.ok(ext, "délégué du geste absent");
  assert.match(ext[1], /shouldReceive touch: UITouch\) -> Bool/);
  assert.match(ext[1], /is UIControl \{ return false \}/);
});

test("le bouton « Revenir dans Zieuton » est bien dans le bandeau et ferme la fenêtre Instagram", () => {
  assert.match(src, /lower = UIStackView\(arrangedSubviews: \[replicaBox, tipLabel, homeButton\]\)/);
  assert.match(src, /homeButton\.addAction\(UIAction \{ \[weak self\] _ in self\?\.dismiss\(animated: true\) \}/);
});
