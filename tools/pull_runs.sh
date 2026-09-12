#!/usr/bin/env bash
# Copies recorded runs (CSV files) from the phone into ./runs/.
# Works with debug builds only (adb run-as needs a debuggable app).
set -euo pipefail
cd "$(dirname "$0")/.."

PKG="com.ridge.game"
REMOTE_DIR="files/runs"   # user://runs, relative to the app's data folder

mkdir -p runs
files=$(adb shell run-as "$PKG" ls "$REMOTE_DIR" 2>/dev/null | tr -d '\r' || true)
if [ -z "$files" ]; then
  echo "No runs found on the phone (record one with the Rec button first)."
  exit 0
fi
for f in $files; do
  adb exec-out run-as "$PKG" cat "$REMOTE_DIR/$f" > "runs/$f"
  echo "runs/$f"
done
