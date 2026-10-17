#!/usr/bin/env bash
# Builds the web app (the same app, in a browser) from the current tree:
#
#   build/web-v<version>/   the files to publish as app/ on the project site,
#                           https://jpaestedstu-prog.github.io/pwd_flashcard_app/app/
#
#   bash tool/build_web.sh
#
# WEB_BASE_HREF serves it from another path (it must start and end with "/"),
# WEB_DIR writes it elsewhere. WEB_TEST=1 makes the offline test build the
# browser checks use (FLASHLEARN_OFFLINE: nothing reaches the cloud; errors
# printed to the console): never publish that one.
#
# What the browser version cannot do, because it needs the phone or tablet
# itself, says so where it is offered (AndroidAppNotice, with a link to the
# download page): Word Hunt (on-device recognition), Gaze Control (on-device
# face tracking), TV Cast (a local server), reminders and the My Day lock
# (system alarms), backup files, game controllers, and adding photos or
# videos to cards, messages, My Day steps and tests (no file system; a
# pasted link still works). Exports download instead of opening a share
# sheet (ShareFile). Sign videos stream the website's light copies; pictures
# load straight from their host. The site's service worker leaves app/ alone
# (website/sw.js).
#
# After a build: check it with tool/web_smoke.py (see .github/workflows/web.yml),
# then publish only with the owner's go-ahead (docs: release flow).
set -euo pipefail
cd "$(dirname "$0")/.."
for d in /c/src/flutter/bin "/c/Program Files/Git/cmd" /c/Windows/System32 /c/Windows \
         /c/Windows/System32/WindowsPowerShell/v1.0; do
  [ -d "$d" ] && PATH="$PATH:$d"
done
export PATH
# Git Bash would turn "--base-href /pwd_flashcard_app/app/" into a Windows
# path ("C:/Program Files/Git/pwd_flashcard_app/app/") on its way to flutter.
export MSYS_NO_PATHCONV=1

V=$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)
[ -n "$V" ] || { echo "no version in pubspec.yaml"; exit 1; }
BASE=${WEB_BASE_HREF:-/pwd_flashcard_app/app/}
case "$BASE" in /*/) ;; /) ;; *) echo "WEB_BASE_HREF must start and end with /"; exit 1;; esac
if [ "${WEB_TEST:-0}" = 1 ]; then
  OUT=${WEB_DIR:-build/web-test}
  DEFINES=(--profile --dart-define=FLASHLEARN_OFFLINE=true --dart-define=FLASHLEARN_LOG_ERRORS=true)
else
  OUT=${WEB_DIR:-build/web-v$V}
  DEFINES=(--release)
fi

echo "== $(date +%H:%M:%S) flutter build web ${DEFINES[0]} -> $OUT (base $BASE)"
flutter build web "${DEFINES[@]}" --no-wasm-dry-run --base-href "$BASE" --output "$OUT"

# The page must load the app from the base it was built for.
grep -q "<base href=\"$BASE\">" "$OUT/index.html" \
  || { echo "index.html does not carry <base href=\"$BASE\">"; exit 1; }
for f in index.html flutter_bootstrap.js main.dart.js manifest.json version.json \
         icons/Icon-192.png assets/AssetManifest.bin; do
  [ -s "$OUT/$f" ] || { echo "missing $OUT/$f"; exit 1; }
done
echo "== $(date +%H:%M:%S) built $OUT ($(du -sh "$OUT" | cut -f1)), version $V"
