#!/usr/bin/env bash
# Runs the rules tests headless with gdUnit4.
# Usage: GODOT_BIN=/path/to/godot scripts/run_tests.sh [extra gdUnit4 args]
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -z "${GODOT_BIN:-}" ]; then
  echo "Set GODOT_BIN to the Godot 4 binary." >&2
  exit 1
fi

# Build the class cache so class_name scripts resolve.
"$GODOT_BIN" --headless --path . --import >/dev/null 2>&1 || true

"$GODOT_BIN" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests "$@"
