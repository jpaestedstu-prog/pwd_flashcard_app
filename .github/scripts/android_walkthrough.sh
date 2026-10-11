#!/usr/bin/env bash
# The Android walkthrough, run by reactivecircus/android-emulator-runner once
# the emulator has booted (the action runs its `script` line by line, so the
# steps live here). $1 = phone | tablet, $2 = portrait | landscape; together
# they name the screenshot folder.
#
# `flutter drive` uninstalls the app when it finishes, which is fine on a CI
# emulator and NEVER fine on a tablet with real profiles. No screenshots
# here: on the runner's software GPU, turning the Flutter surface into an
# image for them took the whole emulator down within seconds.
set -euo pipefail

kind="${1:?phone or tablet}"
orientation="${2:-portrait}"
out="build/walkthrough/android-$kind-$orientation"
mkdir -p logs "$out"

adb wait-for-device
serial=$(adb devices | awk 'NR > 1 && $2 == "device" { print $1; exit }')
echo "Emulator: $serial"

# The screen stays on for the whole run.
adb -s "$serial" shell svc power stayon true || true
adb -s "$serial" shell settings put system screen_off_timeout 2147483647 || true
{ adb -s "$serial" shell wm size; adb -s "$serial" shell wm density; } | tee logs/display.txt

adb -s "$serial" logcat -c || true
adb -s "$serial" logcat -v time > logs/logcat.txt 2>&1 &
logcat_pid=$!
trap 'kill "$logcat_pid" 2>/dev/null || true' EXIT

WALKTHROUGH_DIR="$out" flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_walkthrough_test.dart \
  --dart-define=FLASHLEARN_OFFLINE=true \
  --dart-define=WALK_ORIENTATION="$orientation" \
  --dart-define=WALK_SCREENSHOTS=false \
  -d "$serial" 2>&1 | tee logs/walkthrough.log
