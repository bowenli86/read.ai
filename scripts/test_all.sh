#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

bash "$ROOT/scripts/e2e_book_core.sh"
bash "$ROOT/scripts/e2e_books.sh"
bash "$ROOT/scripts/e2e_features.sh"
bash "$ROOT/scripts/e2e_progress.sh"

echo "All ReadAI tests passed."
