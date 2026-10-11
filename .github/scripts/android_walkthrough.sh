#!/usr/bin/env bash
# The Android walkthrough, run by reactivecircus/android-emulator-runner once
# the emulator has booted (the action runs its `script` line by line, so the
# steps live here). $1 = phone | tablet, $2 = portrait | landscape (together
# they name the output folder), $3 = true to also check the cameras and
# speech (WALK_DEVICE).
#
# `flutter drive` uninstalls the app when it finishes, which is fine on a CI
# emulator and NEVER fine on a tablet with real profiles. No screenshots
# here: on the runner's software GPU, turning the Flutter surface into an
# image for them took the whole emulator down within seconds.
set -euo pipefail

kind="${1:?phone or tablet}"
orientation="${2:-portrait}"
device="${3:-false}"
out="build/walkthrough/android-$kind-$orientation"
pkg=com.example.pwdpwdpwd
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

# The walk cannot tap Android's permission dialogs: grant camera and
# microphone the moment `flutter drive` has installed the app.
(
  for _ in $(seq 1 1200); do
    if adb -s "$serial" shell pm list packages 2>/dev/null | grep -q "package:$pkg"; then
      for p in CAMERA RECORD_AUDIO POST_NOTIFICATIONS; do
        adb -s "$serial" shell pm grant "$pkg" "android.permission.$p" 2>/dev/null || true
      done
      echo "granted permissions"
      exit 0
    fi
    sleep 1
  done
) &
grant_pid=$!
trap 'kill "$logcat_pid" "$grant_pid" 2>/dev/null || true' EXIT

WALKTHROUGH_DIR="$out" flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_walkthrough_test.dart \
  --dart-define=FLASHLEARN_OFFLINE=true \
  --dart-define=WALK_ORIENTATION="$orientation" \
  --dart-define=WALK_SCREENSHOTS=false \
  --dart-define=WALK_DEVICE="$device" \
  -d "$serial" 2>&1 | tee logs/walkthrough.log
