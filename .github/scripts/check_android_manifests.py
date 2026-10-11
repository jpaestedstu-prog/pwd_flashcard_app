"""Checks what matters in the CI-built release APKs.

    python3 .github/scripts/check_android_manifests.py WEBSITE.apk PLAY.apk

* The website APK keeps the original application id (installed tablets keep
  updating) and USE_EXACT_ALARM; the Play APK has the store id and no
  USE_EXACT_ALARM (Play allows it only for alarm-clock and calendar apps).
* Neither declares the advertising id (an app for children).
* Both carry the version in pubspec.yaml.
* Both are 16 KB page aligned (Google Play's rule for Android 15+ devices).
"""
import os
import re
import subprocess
import sys
from pathlib import Path


def build_tool(name):
    root = Path(os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"]) / "build-tools"
    def key(p):
        return [int(x) if x.isdigit() else 0 for x in re.split(r"[.-]", p.name)]
    newest = sorted((p for p in root.iterdir() if p.is_dir()), key=key)[-1]
    return str(newest / name)


def aapt2(what, apk):
    return subprocess.run([build_tool("aapt2"), "dump", what, apk],
                          capture_output=True, text=True, check=True).stdout


def main():
    website, play = sys.argv[1:3]
    pubspec = Path("pubspec.yaml").read_text(encoding="utf-8")
    version = re.search(r"^version:\s*([^+\s]+)\+(\d+)", pubspec, re.M)
    problems = []

    def expect(ok, message):
        print(("ok    " if ok else "FAIL  ") + message)
        if not ok:
            problems.append(message)

    for label, apk, package, exact in (
        ("website", website, "com.example.pwdpwdpwd", True),
        ("play", play, "io.github.jpaestedstuprog.flashlearnpwd", False),
    ):
        badging = aapt2("badging", apk)
        permissions = aapt2("permissions", apk)
        print(f"-- {label}: {badging.splitlines()[0]}")
        expect(f"package: name='{package}'" in badging, f"{label}: application id {package}")
        expect(f"versionName='{version.group(1)}'" in badging,
               f"{label}: versionName {version.group(1)} (pubspec)")
        expect(("android.permission.USE_EXACT_ALARM" in permissions) == exact,
               f"{label}: USE_EXACT_ALARM {'declared' if exact else 'absent'}")
        expect("android.permission.SCHEDULE_EXACT_ALARM" in permissions,
               f"{label}: SCHEDULE_EXACT_ALARM declared")
        expect("com.google.android.gms.permission.AD_ID" not in permissions,
               f"{label}: no advertising id")
        aligned = subprocess.run([build_tool("zipalign"), "-c", "-P", "16", "4", apk],
                                 capture_output=True, text=True)
        expect(aligned.returncode == 0, f"{label}: 16 KB page aligned")

    if problems:
        print(f"\n{len(problems)} problem(s)")
        sys.exit(1)
    print("\nall good")


if __name__ == "__main__":
    main()
