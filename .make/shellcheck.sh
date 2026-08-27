#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck not installed — skipping"
  exit 0
fi

echo "Running shellcheck..."
shellcheck -e SC1091 -e SC2155 -e SC2232 -e SC2016 -e SC2059 \
  .make/*.sh ttdaid/distros/*/*/scripts/*.sh
echo "shellcheck OK"
