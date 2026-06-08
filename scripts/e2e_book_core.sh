#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PDF="$ROOT/Tests/Fixtures/readai-e2e.pdf"
EPUB="$ROOT/Tests/Fixtures/readai-e2e.epub"
STATUS_DIR="$ROOT/.build/e2e"

python3 "$ROOT/scripts/make_fixtures.py" >/dev/null
mkdir -p "$STATUS_DIR"

run_case() {
  local name="$1"
  local file="$2"
  local status="$STATUS_DIR/core-$name.json"

  rm -f "$status"
  /bin/bash "$ROOT/scripts/run_e2e_swift.sh" --e2e-status-path "$status" "$file"

  python3 "$ROOT/scripts/verify_e2e_status.py" "$status" "$name"
}

run_case pdf "$PDF"
run_case epub "$EPUB"

echo "PDF and EPUB core E2E passed."
