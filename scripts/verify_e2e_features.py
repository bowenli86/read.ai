#!/usr/bin/env python3
import json
import sys
from pathlib import Path


status_path = Path(sys.argv[1])
expected_kind = sys.argv[2]
expected_theme = sys.argv[3]

status = json.loads(status_path.read_text())

if not status.get("ok"):
    raise SystemExit(status)

if status.get("kind") != expected_kind:
    raise SystemExit(f"expected {expected_kind}, got {status.get('kind')}: {status}")

if status.get("theme") != expected_theme:
    raise SystemExit(f"theme not applied: {status}")

if int(status.get("searchResultCount", 0)) <= 0:
    raise SystemExit(f"search failed: {status}")

if int(status.get("bookmarkCount", 0)) <= 0:
    raise SystemExit(f"bookmark missing: {status}")

if int(status.get("highlightCount", 0)) <= 0:
    raise SystemExit(f"highlight missing: {status}")

if int(status.get("noteCount", 0)) <= 0:
    raise SystemExit(f"note missing: {status}")

if status.get("keyboardShortcuts") is not True:
    raise SystemExit(f"keyboard shortcuts not enabled: {status}")

if status.get("compactToolbar") is not True:
    raise SystemExit(f"compact toolbar not enabled: {status}")

if status.get("settingsButton") is not True:
    raise SystemExit(f"settings button missing: {status}")

if status.get("settingsPanelVisible") is not True:
    raise SystemExit(f"settings panel did not open: {status}")

if int(status.get("pageCount", 0)) > 1 and status.get("keyboardTurnWorked") is not True:
    raise SystemExit(f"keyboard page turn failed: {status}")

print(f"{expected_kind} features: ok")
