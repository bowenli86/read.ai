#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="$ROOT/scripts/run_e2e_swift.sh"
PDF="$ROOT/Tests/Fixtures/readai-e2e.pdf"
EPUB="$ROOT/Tests/Fixtures/readai-e2e.epub"
STATUS_DIR="$ROOT/.build/e2e"

python3 "$ROOT/scripts/make_fixtures.py" >/dev/null
mkdir -p "$STATUS_DIR"

run_app() {
  READAI_STATE_PATH="$READAI_PROGRESS_STATE" python3 "$ROOT/scripts/run_with_timeout.py" \
    /bin/bash \
    "$RUNNER" "$@" >/dev/null
}

run_case() {
  local name="$1"
  local file="$2"
  local saved="$STATUS_DIR/progress-$name-saved.json"
  local restored="$STATUS_DIR/progress-$name-restored.json"
  local last="$STATUS_DIR/progress-$name-last.json"
  local state="$STATUS_DIR/progress-$name-state.json"

  rm -f "$saved" "$restored" "$last" "$state"
  export READAI_PROGRESS_STATE="$state"
  run_app \
    --e2e-status-path "$saved" \
    --e2e-reading-style page \
    --e2e-clear-position \
    --e2e-turn-pages \
    --e2e-exit-after-open \
    "$file"

  run_app \
    --e2e-status-path "$restored" \
    --e2e-reading-style page \
    --e2e-exit-after-open \
    "$file"

  run_app \
    --e2e-status-path "$last" \
    --e2e-open-last \
    --e2e-exit-after-open

  python3 "$ROOT/scripts/wait_for_status.py" "$saved"
  python3 "$ROOT/scripts/wait_for_status.py" "$restored"
  python3 "$ROOT/scripts/wait_for_status.py" "$last"
  python3 "$ROOT/scripts/verify_e2e_progress.py" "$saved" "$restored" "$last" "$name"
}

run_case pdf "$PDF"
run_case epub "$EPUB"

echo "Reading progress E2E passed."
