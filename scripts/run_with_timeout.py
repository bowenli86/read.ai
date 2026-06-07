#!/usr/bin/env python3
import subprocess
import sys


TIMEOUT_SECONDS = 20

try:
    completed = subprocess.run(sys.argv[1:], timeout=TIMEOUT_SECONDS)
    raise SystemExit(completed.returncode)
except subprocess.TimeoutExpired:
    print(f"timed out after {TIMEOUT_SECONDS}s: {' '.join(sys.argv[1:])}", file=sys.stderr)
    raise SystemExit(124)
