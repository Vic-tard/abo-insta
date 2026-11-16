#!/bin/sh
# Teste la preuve de demande d'export (FOU-121) sans lancer l'app.
# Recopie le bloc EXPORT-PROOF de ios/Zieuton/WebViewController.swift, le compile avec
# tests/ios/ExportProofTests.swift et lance les tests. Il faut un Mac (swiftc).
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/ios/Zieuton/WebViewController.swift"
grep -q '^// EXPORT-PROOF:BEGIN' "$src" && grep -q '^// EXPORT-PROOF:END' "$src" || {
  echo "ÉCHEC : repères EXPORT-PROOF introuvables dans $src"; exit 1; }
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
{ echo "import Foundation"; sed -n '/^\/\/ EXPORT-PROOF:BEGIN/,/^\/\/ EXPORT-PROOF:END/p' "$src"; } > "$dir/ExportProof.swift"
cp "$root/tests/ios/ExportProofTests.swift" "$dir/main.swift"
swiftc -o "$dir/export-proof-tests" "$dir/ExportProof.swift" "$dir/main.swift"
"$dir/export-proof-tests"
