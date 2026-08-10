#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BINARY_NAME="${BINARY_NAME:-ttdaid}"
CMD_PATH="${CMD_PATH:-./ttdaid/cmd/ttdaid}"
VERSION="${VERSION:-$(git -C "$ROOT_DIR" describe --tags --always --dirty 2>/dev/null || echo dev)}"
LDFLAGS="${LDFLAGS:--s -w -X github.com/carlosrabelo/ttdaid/ttdaid/internal/version.Version=${VERSION}}"

# Never leave root-owned artifacts under bin/ (breaks later user builds).
if [ "$(id -u)" -eq 0 ]; then
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    exec sudo -u "$SUDO_USER" -H -- env \
      BINARY_NAME="$BINARY_NAME" \
      CMD_PATH="$CMD_PATH" \
      VERSION="$VERSION" \
      LDFLAGS="$LDFLAGS" \
      "$0"
  fi
  echo "error: do not build as root (bin/ would be root-owned)" >&2
  echo "hint:  make build && sudo make install-system" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/bin"
cd "$ROOT_DIR"
echo "Building $BINARY_NAME..."
CGO_ENABLED=0 go build -ldflags="$LDFLAGS" -o "$ROOT_DIR/bin/$BINARY_NAME" "$CMD_PATH"
echo "Done: $ROOT_DIR/bin/$BINARY_NAME"
