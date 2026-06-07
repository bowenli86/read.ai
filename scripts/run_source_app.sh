#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/ReadAI.app"
RESOURCES="$APP/Contents/Resources"

bash "$ROOT/scripts/build_app.sh" >/dev/null

READAI_APP_RESOURCES="$RESOURCES" exec /usr/bin/osascript \
  -l JavaScript "$RESOURCES/ReadAI.jxa.js" -- "$@"
