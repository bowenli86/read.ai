#!/usr/bin/env python3
import json
import sys
from pathlib import Path


saved = json.loads(Path(sys.argv[1]).read_text())
restored = json.loads(Path(sys.argv[2]).read_text())
last = json.loads(Path(sys.argv[3]).read_text())
expected_kind = sys.argv[4]

for name, status in (("saved", saved), ("restored", restored), ("last", last)):
    if not status.get("ok"):
        raise SystemExit(f"{name} failed: {status}")
    if status.get("kind") != expected_kind:
        raise SystemExit(f"{name} expected {expected_kind}: {status}")

saved_page = int(saved.get("currentPage", 0))
if saved_page < 2:
    raise SystemExit(f"position was not saved after page turn: {saved}")

if int(restored.get("currentPage", 0)) != saved_page:
    raise SystemExit(f"book did not restore saved page: saved={saved}, restored={restored}")

if last.get("openedLastBook") is not True:
    raise SystemExit(f"last book was not opened: {last}")

if int(last.get("currentPage", 0)) != saved_page:
    raise SystemExit(f"last book did not restore page: saved={saved}, last={last}")

print(f"{expected_kind} progress: ok")
