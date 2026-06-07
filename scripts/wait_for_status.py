#!/usr/bin/env python3
import sys
import time
from pathlib import Path


status = Path(sys.argv[1])
deadline = time.monotonic() + 20

while time.monotonic() < deadline:
    if status.exists() and status.stat().st_size > 0:
        raise SystemExit(0)
    time.sleep(0.1)

raise SystemExit(f"missing status: {status}")
