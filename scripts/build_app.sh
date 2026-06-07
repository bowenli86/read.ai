#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/ReadAI.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

cd "$ROOT"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

cp "$ROOT/Resources/ReadAI.jxa.js" "$RESOURCES/"
cp "$ROOT/Resources/epub_extract.py" "$RESOURCES/"
cp "$ROOT/Resources/launch.bash" "$RESOURCES/"
chmod +x "$RESOURCES/epub_extract.py" "$RESOURCES/launch.bash"
ln -s /bin/bash "$MACOS/bash"

python3 - "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist" "$RESOURCES/launch.bash" <<'PY'
import plistlib
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])
launcher = Path(sys.argv[3])

info = plistlib.loads(source.read_bytes())
info["CFBundleExecutable"] = "bash"
info["LSEnvironment"] = {"BASH_ENV": str(launcher)}

target.write_bytes(plistlib.dumps(info, sort_keys=False))
PY

echo "$APP"
