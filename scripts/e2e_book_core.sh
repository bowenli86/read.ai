#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/e2e-core"
CACHE="$BUILD/module-cache"
COMBINED="$BUILD/ReadAIE2E.swift"
PDF="$ROOT/Tests/Fixtures/readai-e2e.pdf"
EPUB="$ROOT/Tests/Fixtures/readai-e2e.epub"
STATUS_DIR="$ROOT/.build/e2e"

python3 "$ROOT/scripts/make_fixtures.py" >/dev/null
mkdir -p "$BUILD" "$CACHE" "$STATUS_DIR"
: > "$COMBINED"

for file in \
  BookModels.swift \
  E2EOptions.swift \
  EPUBLoader.swift \
  E2ERunner.swift
do
  printf '\n// MARK: %s\n' "$file" >> "$COMBINED"
  cat "$ROOT/Sources/ReadAI/$file" >> "$COMBINED"
done

cat "$ROOT/Tests/E2E/main.swift" >> "$COMBINED"

run_case() {
  local name="$1"
  local file="$2"
  local status="$STATUS_DIR/core-$name.json"

  rm -f "$status"
  swift \
    -target "$(uname -m)-apple-macosx14.0" \
    -module-cache-path "$CACHE" \
    "$COMBINED" \
    -- --e2e-status-path "$status" "$file"

  python3 "$ROOT/scripts/verify_e2e_status.py" "$status" "$name"
}

run_case pdf "$PDF"
run_case epub "$EPUB"

echo "PDF and EPUB core E2E passed."
