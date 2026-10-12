#!/usr/bin/env bash
# Builds every Android release file from the current tree, then checks them:
#
#   build/release-v<version>/  the website APKs (arm64, arm32, universal) and
#                              SHA256SUMS.txt, signed with the original key
#   build/store-v<version>/    the Google Play APK and bundle (upload key)
#
# Checks: the manifests (.github/scripts/check_android_manifests.py), the
# signers, and tool/release_artifact_scan.py. Stops at the first problem.
# Needs the signing files in docs/signing.md (no key, no build).
#
#   bash tool/build_release.sh
#
# RELEASE_DIR and STORE_DIR choose other folders, for a trial build that must
# not touch files already published. (The APKs rebuild byte-identical from
# the same tree, which proves what a release was built from; the bundle
# records R8's build time, so it never does.) A folder that already holds a
# SHA256SUMS.txt is refused unless OVERWRITE=1. Next step for a release:
# python tools/release_page_build.py.
set -euo pipefail
cd "$(dirname "$0")/.."
# Git Bash on the project PC: Flutter, Git, attrib and the PowerShell that
# Flutter's launcher needs may be missing from PATH.
for d in /c/src/flutter/bin "/c/Program Files/Git/cmd" /c/Windows/System32 /c/Windows \
         /c/Windows/System32/WindowsPowerShell/v1.0; do
  [ -d "$d" ] && PATH="$PATH:$d"
done
export PATH

V=$(sed -n 's/^version: *\([0-9.]*\)+.*/\1/p' pubspec.yaml)
[ -n "$V" ] || { echo "no version in pubspec.yaml"; exit 1; }
REL=${RELEASE_DIR:-build/release-v$V}
STORE=${STORE_DIR:-build/store-v$V}
if [ -f "$REL/SHA256SUMS.txt" ] && [ "${OVERWRITE:-0}" != 1 ]; then
  echo "$REL already holds a build. Choose RELEASE_DIR/STORE_DIR, or set"
  echo "OVERWRITE=1 if those files were never published."
  exit 1
fi
mkdir -p "$REL" "$STORE"
OUT=build/app/outputs/flutter-apk
stamp() { echo "== $(date +%H:%M:%S) $*"; }
winpath() { if command -v cygpath > /dev/null; then cygpath -w "$1"; else echo "$1"; fi; }

# A debug-mode `pub get` (an editor, a test run) writes the test-only
# IntegrationTestPlugin into the generated registrant, and a release build
# then fails to compile it. Before each build the registrant is regenerated
# in release mode, the build runs with --no-pub, and the clean file stays
# read-only until the step ends (Gradle only reads it): twice on 12-13
# October 2026 the editor's automatic `pub get` rewrote it seconds into a
# build.
REG=android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java
lock_registrant() {
  if command -v attrib > /dev/null; then attrib +R "$(winpath "$REG")" > /dev/null; else chmod a-w "$REG"; fi
}
unlock_registrant() {
  [ -f "$REG" ] || return 0
  if command -v attrib > /dev/null; then attrib -R "$(winpath "$REG")" > /dev/null 2>&1 || true; else chmod u+w "$REG"; fi
}
trap unlock_registrant EXIT
build() {  # build "<what>" <flutter build arguments>
  stamp "$1"; shift
  unlock_registrant
  if [ ! -f "$REG" ] || grep -q IntegrationTestPlugin "$REG"; then
    rm -f "$REG"
    flutter build apk --release --config-only > /dev/null
  fi
  if grep -q IntegrationTestPlugin "$REG"; then echo "the registrant still has the test plugin"; exit 1; fi
  lock_registrant
  flutter build "$@" --release --no-pub
  if grep -q IntegrationTestPlugin "$REG"; then echo "the registrant changed during the build"; exit 1; fi
  unlock_registrant
}

build "split APKs (website)" apk --split-per-abi
cp "$OUT/app-arm64-v8a-release.apk" "$REL/FlashLearnPWD-v$V-arm64.apk"
cp "$OUT/app-armeabi-v7a-release.apk" "$REL/FlashLearnPWD-v$V-arm32.apk"
build "universal APK (website)" apk
cp "$OUT/app-release.apk" "$REL/FlashLearnPWD-v$V-universal.apk"
build "Google Play APK" apk --dart-define=FLASHLEARN_DISTRIBUTION=play
cp "$OUT/app-release.apk" "$STORE/FlashLearnPWD-v$V-play.apk"
build "Google Play bundle" appbundle --dart-define=FLASHLEARN_DISTRIBUTION=play
cp build/app/outputs/bundle/release/app-release.aab "$STORE/FlashLearnPWD-v$V-play.aab"

stamp "checksums"
(cd "$REL" && sha256sum --binary "FlashLearnPWD-v$V-arm64.apk" "FlashLearnPWD-v$V-arm32.apk" \
  "FlashLearnPWD-v$V-universal.apk" > SHA256SUMS.txt && cat SHA256SUMS.txt)
(cd "$STORE" && sha256sum --binary "FlashLearnPWD-v$V-play.apk" "FlashLearnPWD-v$V-play.aab")

SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/c/Android/Sdk}}
command -v cygpath > /dev/null && SDK=$(cygpath -u "$SDK")
stamp "manifests"
ANDROID_HOME="$(winpath "$SDK")" python .github/scripts/check_android_manifests.py \
  "$REL/FlashLearnPWD-v$V-universal.apk" "$STORE/FlashLearnPWD-v$V-play.apk"

stamp "signers"
BT=$(ls -d "$SDK"/build-tools/*/ | sort -V | tail -1)
APKSIGNER="${BT}apksigner"
[ -f "$APKSIGNER.bat" ] && APKSIGNER="$APKSIGNER.bat"
KEYTOOL=${KEYTOOL:-$(command -v keytool || echo "/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe")}
# The original key's certificate. A website APK signed with anything else
# cannot update an installed copy: Android would make the owner uninstall
# it first, deleting every profile on the tablet. (No `grep -q` after a
# pipe: with pipefail, grep stopping early can fail a good check.)
WEBSITE_CERT=afd730b90fabc11a2dcd07d19858764c4c68a4e33f0e5f59b3f868bb373f2ba8
for f in "$REL/FlashLearnPWD-v$V-arm64.apk" "$REL/FlashLearnPWD-v$V-arm32.apk" "$REL/FlashLearnPWD-v$V-universal.apk"; do
  "$APKSIGNER" verify --print-certs "$f" | grep "$WEBSITE_CERT" > /dev/null \
    || { echo "$(basename "$f") is NOT signed with the original key"; exit 1; }
  echo "$(basename "$f"): original key"
done
"$APKSIGNER" verify --print-certs "$STORE/FlashLearnPWD-v$V-play.apk" | grep "CN=FlashLearn PWD" > /dev/null \
  || { echo "the Play APK is NOT signed with the upload key"; exit 1; }
"$KEYTOOL" -printcert -jarfile "$(winpath "$STORE/FlashLearnPWD-v$V-play.aab")" | grep "CN=FlashLearn PWD" > /dev/null \
  || { echo "the Play bundle is NOT signed with the upload key"; exit 1; }
echo "Play APK and bundle: upload key"

stamp "release-file scan"
python tool/release_artifact_scan.py "$REL"/*.apk "$STORE"/*.apk "$STORE"/*.aab

stamp "done"
ls -l "$REL" "$STORE"
