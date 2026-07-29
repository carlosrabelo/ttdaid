#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v go >/dev/null 2>&1; then
  echo "Go toolchain not found — install golang-go (or languages-golang via TTDAID)" >&2
  exit 1
fi

echo "Downloading module dependencies..."
go mod download
go mod tidy
echo "Setup complete."
