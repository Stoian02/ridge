#!/usr/bin/env bash
# Debug builds for the phone.
# Usage: tools/android.sh [build|install|run|logs|all]   (default: all = build + install + run)
set -euo pipefail
cd "$(dirname "$0")/.."

PKG="com.ridge.game"
APK="build/ridge-debug.apk"

build() {
  mkdir -p build
  godot --headless --export-debug "Android" "$APK"
  ls -lh "$APK"
}

install() {
  adb install -r "$APK"
}

run() {
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null
}

logs() {
  adb logcat -s godot:V
}

case "${1:-all}" in
  build) build ;;
  install) install ;;
  run) run ;;
  logs) logs ;;
  all) build; install; run ;;
  *) echo "Usage: $0 [build|install|run|logs|all]"; exit 2 ;;
esac
