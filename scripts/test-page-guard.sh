#!/bin/sh
# Teste les règles de sécurité des mises à jour de la page (PageGuard, FOU-28) sans lancer l'app.
# Recopie le bloc PAGE-GUARD de ios/Zieuton/WebViewController.swift (Foundation seulement),
# le compile avec tests/ios/PageGuardTests.swift et lance les tests. Il faut un Mac (swiftc).
# Lancer : npm run test:ios
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
src="$root/ios/Zieuton/WebViewController.swift"
grep -q '^// PAGE-GUARD:BEGIN' "$src" && grep -q '^// PAGE-GUARD:END' "$src" || {
  echo "ÉCHEC : repères PAGE-GUARD introuvables dans $src"; exit 1; }
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
{ echo "import Foundation"; sed -n '/^\/\/ PAGE-GUARD:BEGIN/,/^\/\/ PAGE-GUARD:END/p' "$src"; } > "$dir/PageGuard.swift"
cp "$root/tests/ios/PageGuardTests.swift" "$dir/main.swift"
swiftc -o "$dir/page-guard-tests" "$dir/PageGuard.swift" "$dir/main.swift"
cd "$root" && "$dir/page-guard-tests"
