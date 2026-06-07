#!/usr/bin/env python3
import json
import sys
from pathlib import Path


status_path = Path(sys.argv[1])
expected_kind = sys.argv[2]
expected_style = sys.argv[3] if len(sys.argv) > 3 else None
require_pages = expected_style == "page"

if not status_path.exists():
    raise SystemExit(f"missing status: {status_path}")

status = json.loads(status_path.read_text())

if not status.get("ok"):
    raise SystemExit(status)

if status.get("kind") != expected_kind:
    raise SystemExit(f"expected {expected_kind}, got {status.get('kind')}")

if int(status.get("textLength", 0)) <= 0:
    raise SystemExit(f"missing extracted text: {status}")

if expected_kind == "epub" and int(status.get("chapterCount", 0)) <= 0:
    raise SystemExit(f"missing epub chapters: {status}")

if require_pages and int(status.get("pageCount", 0)) <= 0:
    raise SystemExit(f"missing page count: {status}")

if require_pages and status.get("turnPageWorked") is not True:
    raise SystemExit(f"page turn failed: {status}")

if expected_style and status.get("readingStyle") != expected_style:
    raise SystemExit(f"expected {expected_style} style: {status}")

if expected_style and int(status.get("fontSize", 0)) != 22:
    raise SystemExit(f"font size not applied: {status}")

if expected_style and int(status.get("lineSpacing", -1)) != 14:
    raise SystemExit(f"line spacing not applied: {status}")

print(f"{expected_kind}: ok")
