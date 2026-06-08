#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build/e2e-core"
CACHE="$BUILD/module-cache"
COMBINED="$BUILD/ReadAIE2E.swift"
XCODE_DEVELOPER="/Applications/Xcode.app/Contents/Developer"
XCODE_SWIFT="$XCODE_DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
XCODE_SDK="$XCODE_DEVELOPER/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"

mkdir -p "$BUILD" "$CACHE"
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

exec env CLANG_MODULE_CACHE_PATH="$CACHE" DEVELOPER_DIR="$XCODE_DEVELOPER" "$XCODE_SWIFT" \
  -sdk "$XCODE_SDK" \
  -target "$(uname -m)-apple-macosx26.0" \
  -module-cache-path "$CACHE" \
  "$COMBINED" -- "$@"
