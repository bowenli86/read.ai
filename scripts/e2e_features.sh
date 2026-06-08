#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/scripts/run_e2e_swift.sh"
PDF="$ROOT/Tests/Fixtures/readai-e2e.pdf"
EPUB="$ROOT/Tests/Fixtures/readai-e2e.epub"
STATUS_DIR="$ROOT/.build/e2e"

python3 "$ROOT/scripts/make_fixtures.py" >/dev/null
mkdir -p "$STATUS_DIR"

run_case() {
  local name="$1"
  local file="$2"
  local query="$3"
  local theme="$4"
  local status="$STATUS_DIR/features-$name.json"
  local state="$STATUS_DIR/features-$name-state.json"

  rm -f "$status" "$state"
  READAI_STATE_PATH="$state" python3 "$ROOT/scripts/run_with_timeout.py" \
    /bin/bash \
    "$RUNNER" \
    --e2e-status-path "$status" \
    --e2e-reading-style page \
    --e2e-search "$query" \
    --e2e-theme "$theme" \
    --e2e-add-bookmark \
    --e2e-add-highlight \
    --e2e-add-note \
    --e2e-toggle-settings \
    --e2e-keyboard \
    --e2e-exit-after-open \
    "$file" >/dev/null

  python3 "$ROOT/scripts/wait_for_status.py" "$status"
  python3 "$ROOT/scripts/verify_e2e_features.py" "$status" "$name" "$theme"
}

run_case pdf "$PDF" Sample light
run_case epub "$EPUB" segment sepia

echo "Reader feature E2E passed."
