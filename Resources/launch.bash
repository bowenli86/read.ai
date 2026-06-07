#!/bin/bash
set -euo pipefail

APP_RESOURCES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export READAI_APP_RESOURCES="$APP_RESOURCES"

if [ "$#" -eq 0 ]; then
  COMMAND_LINE="$(ps -p "$$" -o command= 2>/dev/null || true)"
  if [ -n "${READAI_LAUNCH_DEBUG-}" ]; then
    printf '%s\n' "$COMMAND_LINE" > "$READAI_LAUNCH_DEBUG"
  fi
  case "$COMMAND_LINE" in
    *"$APP_RESOURCES/launch.bash"*)
      REST="${COMMAND_LINE#*"$APP_RESOURCES/launch.bash"}"
      # Arguments come from local E2E fixtures and contain no shell metacharacters.
      eval "set -- $REST"
      ;;
  esac
fi

case "${1-}" in
  "$APP_RESOURCES/launch.bash"|*/Contents/Resources/launch.bash)
    shift
    ;;
esac

exec /usr/bin/osascript -l JavaScript "$APP_RESOURCES/ReadAI.jxa.js" -- "$@"
