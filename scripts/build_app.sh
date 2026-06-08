#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.app-build/ReadAI.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
COMBINED="$ROOT/.app-build/ReadAI.swift"
BUILD_CACHE="$ROOT/.app-build/module-cache"
TARGET_ARCH="$(uname -m)"
XCODE_DEVELOPER="/Applications/Xcode.app/Contents/Developer"
XCODE_SWIFTC="$XCODE_DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
XCODE_SDK="$XCODE_DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

cd "$ROOT"
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES" "$BUILD_CACHE"
if [ -f "$ROOT/Resources/ReadAI.icns" ]; then
  cp "$ROOT/Resources/ReadAI.icns" "$RESOURCES/ReadAI.icns"
fi

: > "$COMBINED"
for file in \
  BookModels.swift \
  E2EOptions.swift \
  EPUBLoader.swift \
  E2ERunner.swift \
  KeychainStore.swift \
  AIClient.swift \
  AppKitRuntime.swift
do
  printf '\n// MARK: %s\n' "$file" >> "$COMBINED"
  cat "$ROOT/Sources/ReadAI/$file" >> "$COMBINED"
done

cat >> "$COMBINED" <<'SWIFT'

// MARK: AppKit main
if E2EOptions.isRequested {
  E2ERunner.runIfRequested()
}

AppKitRuntime.main()
SWIFT

CLANG_MODULE_CACHE_PATH="$BUILD_CACHE" DEVELOPER_DIR="$XCODE_DEVELOPER" "$XCODE_SWIFTC" \
  -sdk "$XCODE_SDK" \
  -target "$TARGET_ARCH-apple-macosx14.0" \
  -module-cache-path "$BUILD_CACHE" \
  -framework AppKit \
  -framework PDFKit \
  -framework Security \
  -framework WebKit \
  -suppress-warnings \
  "$COMBINED" \
  -o "$MACOS/ReadAI"
chmod +x "$MACOS/ReadAI"

python3 - "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

source = Path(sys.argv[1])
target = Path(sys.argv[2])

source_info = plistlib.loads(source.read_bytes())
info = dict(source_info)
info["CFBundleExecutable"] = "ReadAI"

target.write_bytes(plistlib.dumps(info, sort_keys=False))
PY
printf 'APPL????' > "$CONTENTS/PkgInfo"
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "$APP"
