#!/usr/bin/env bash
# Runs the GUT test suites headless.
# Usage: ./run_tests.sh [unit|scenarios|all]   (default: all)
# Exits non-zero if any test fails OR any script fails to load. GUT itself exits 0
# when a test file has a parse error, so the log is checked for script errors too.
set -uo pipefail
cd "$(dirname "$0")"

suite="${1:-all}"
case "$suite" in
  unit) dirs="res://tests/unit" ;;
  scenarios) dirs="res://tests/scenarios" ;;
  all) dirs="res://tests/unit,res://tests/scenarios" ;;
  *) echo "Unknown suite: $suite (use unit, scenarios or all)"; exit 2 ;;
esac

# Import first so newly added class_name scripts are registered.
godot --headless --import >/dev/null 2>&1

log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# --fixed-fps 120 runs physics as fast as the CPU allows instead of in real time.
# --max-fps 0 lifts the project's 60 FPS cap for the test run.
godot --headless --fixed-fps 120 --max-fps 0 \
  -s addons/gut/gut_cmdln.gd -gdir="$dirs" -ginclude_subdirs -gexit 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

if grep -q "SCRIPT ERROR" "$log"; then
  echo "run_tests.sh: script errors found (see above) - failing the run."
  exit 1
fi
exit "$status"
