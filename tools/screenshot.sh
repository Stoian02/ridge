#!/usr/bin/env bash
# Renders a scene in a real window for a few seconds and saves the frames as PNG.
# Prints the path of the last frame.
# Usage: tools/screenshot.sh [scene] [seconds]
set -euo pipefail
cd "$(dirname "$0")/.."

scene="${1:-res://levels/test_ground/test_ground.tscn}"
seconds="${2:-3}"
out="build/screenshots"

mkdir -p "$out"
rm -f "$out"/frame*.png "$out"/frame.wav
godot --path . --fixed-fps 30 --write-movie "$out/frame.png" --quit-after $((seconds * 30)) "$scene" >/dev/null 2>&1
ls "$out"/frame*.png | tail -1
