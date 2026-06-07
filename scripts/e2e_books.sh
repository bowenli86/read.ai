#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/ReadAI.app"
RESOURCES="$APP/Contents/Resources"
PDF="$ROOT/Tests/Fixtures/readai-e2e.pdf"
EPUB="$ROOT/Tests/Fixtures/readai-e2e.epub"
STATUS_DIR="$ROOT/.build/e2e"

python3 "$ROOT/scripts/make_fixtures.py" >/dev/null
bash "$ROOT/scripts/build_app.sh" >/dev/null
mkdir -p "$STATUS_DIR"

run_case() {
  local name="$1"
  local file="$2"
  local style="$3"
  local status="$STATUS_DIR/$name-$style.json"

  rm -f "$status"
  if [ "$style" = "page" ]; then
    READAI_APP_RESOURCES="$RESOURCES" python3 "$ROOT/scripts/run_with_timeout.py" \
      /usr/bin/osascript -l JavaScript "$RESOURCES/ReadAI.jxa.js" -- \
      --e2e-status-path "$status" \
      --e2e-reading-style "$style" \
      --e2e-font-size 22 \
      --e2e-line-spacing 14 \
      --e2e-turn-pages \
      --e2e-exit-after-open \
      "$file" >/dev/null
  else
    READAI_APP_RESOURCES="$RESOURCES" python3 "$ROOT/scripts/run_with_timeout.py" \
      /usr/bin/osascript -l JavaScript "$RESOURCES/ReadAI.jxa.js" -- \
      --e2e-status-path "$status" \
      --e2e-reading-style "$style" \
      --e2e-font-size 22 \
      --e2e-line-spacing 14 \
      --e2e-exit-after-open \
      "$file" >/dev/null
  fi

  python3 "$ROOT/scripts/wait_for_status.py" "$status"
  python3 "$ROOT/scripts/verify_e2e_status.py" "$status" "$name" "$style"
}

run_case pdf "$PDF" page
run_case epub "$EPUB" page
run_case pdf "$PDF" scroll
run_case epub "$EPUB" scroll

cp "$STATUS_DIR/pdf-page.json" "$STATUS_DIR/pdf.json"
cp "$STATUS_DIR/epub-page.json" "$STATUS_DIR/epub.json"

echo "PDF and EPUB page/scroll E2E passed."
