#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$(bash "$ROOT/scripts/build_app.sh")"
if [ "$#" -eq 0 ]; then
  exec open -n "$APP"
fi

exec open -n -a "$APP" "$@"
