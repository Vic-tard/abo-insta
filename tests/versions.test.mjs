// Règles des numéros de version (FOU-44).
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { readBuild, readProjectVersion, buildFromDate, nextBuild, checkVersions } from "../scripts/versions.mjs";

const root = new URL("..", import.meta.url);
const base = { build: "2026-11-06-1500", projectVersion: "3" };

test("les numéros actuels se lisent", () => {
  assert.match(readBuild(readFileSync(new URL("index.html", root), "utf8")), /^\d{4}-\d{2}-\d{2}-\d{4}$/);
  assert.match(readProjectVersion(readFileSync(new URL("ios/Zieuton.xcodeproj/project.pbxproj", root), "utf8")), /^\d+$/);
});

test("BUILD est à l'heure de Paris", () => {
  assert.equal(buildFromDate(new Date("2026-11-06T13:27:00Z")), "2026-11-06-1427"); // hiver : UTC+1
  assert.equal(buildFromDate(new Date("2026-07-01T22:05:00Z")), "2026-07-02-0005"); // été : UTC+2
});

test("BUILD ne recule jamais", () => {
  assert.equal(nextBuild("2026-11-06-1500", new Date("2026-11-06T15:00:00Z")), "2026-11-06-1600");
  assert.equal(nextBuild("2026-11-06-1500", new Date("2026-11-06T13:00:00Z")), "2026-11-06-1501");
  assert.equal(nextBuild("2026-12-31-2359", new Date("2026-11-06T13:00:00Z")), "2027-01-01-0000");
});

test("page changée sans BUILD : refusé ; avec BUILD : accepté", () => {
  assert.equal(checkVersions({ changed: ["index.html"], base, head: base }).length, 1);
  assert.deepEqual(checkVersions({ changed: ["index.html"], base, head: { ...base, build: "2026-11-06-1600" } }), []);
  assert.equal(checkVersions({ changed: ["index.html"], base, head: { ...base, build: "2026-11-05-1600" } }).length, 1);
});

test("coque changée sans CURRENT_PROJECT_VERSION : refusé ; avec : accepté", () => {
  assert.equal(checkVersions({ changed: ["ios/Zieuton/WebViewController.swift"], base, head: base }).length, 1);
  assert.deepEqual(checkVersions({ changed: ["ios/Zieuton/WebViewController.swift"], base, head: { ...base, projectVersion: "4" } }), []);
  assert.equal(checkVersions({ changed: ["ios/Zieuton.xcodeproj/project.pbxproj"], base, head: base }).length, 1);
});

test("tests, doc, README iOS ou channel.json : aucun numéro exigé", () => {
  assert.deepEqual(checkVersions({ changed: ["tests/import.test.mjs", "docs/SPEC.md", "ios/README.md", "channel.json", "CLAUDE.md"], base, head: base }), []);
});
