#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY_NAME="${BINARY_NAME:-ttdaid}"
cd "$ROOT_DIR"

go clean 2>/dev/null || true
rm -rf dist/ build/ "bin/$BINARY_NAME"
echo "Clean complete."
