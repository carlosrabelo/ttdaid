#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY_NAME="${BINARY_NAME:-ttdaid}"
CMD_PATH="${CMD_PATH:-./ttdaid/cmd/ttdaid}"
VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)}"
LDFLAGS="${LDFLAGS:--s -w -X github.com/carlosrabelo/ttdaid/ttdaid/internal/version.Version=${VERSION}}"

mkdir -p "$ROOT_DIR/bin"
cd "$ROOT_DIR"
echo "Building $BINARY_NAME..."
CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$ROOT_DIR/bin/$BINARY_NAME" "$CMD_PATH"
echo "Done: $ROOT_DIR/bin/$BINARY_NAME"
