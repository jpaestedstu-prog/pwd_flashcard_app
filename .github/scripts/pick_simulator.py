"""Prints the UDID of an iOS simulator of the requested kind, creating one if
the runner has none.

Device names change with every Xcode ("iPhone SE (3rd generation)" became
"iPhone 16e"), so each kind is a list of name patterns, tried in order, on
the newest iOS runtime that can run an x86_64 app: Google ML Kit's simulator
slice is x86_64 only, and on Apple Silicon the default iOS 26 simulator runs
arm64 apps only (iOS 18 runtimes, or the universal iOS 26 one, run x86_64
under Rosetta).

    python3 pick_simulator.py iphone-small|iphone-large|ipad-mini|ipad-large
"""

import json
import re
import subprocess
import sys

KINDS = {
    # The smallest screen still sold: tightest layout.
    "iphone-small": [r"^iPhone SE", r"^iPhone 16e$", r"^iPhone 1\d mini$"],
    # 6.9" - the App Store's required iPhone screenshot size.
    "iphone-large": [r"^iPhone \d+ Pro Max$", r"^iPhone \d+ Plus$"],
    "ipad-mini": [r"^iPad mini"],
    # 13" - the App Store's required iPad screenshot size.
    "ipad-large": [r"^iPad Pro 13-inch", r"^iPad Pro \(12\.9-inch\)", r"^iPad Air 13-inch"],
}


def simctl(*args):
    out = subprocess.run(["xcrun", "simctl", *args, "-j"], check=True,
                         capture_output=True, text=True).stdout
    return json.loads(out)


def version_key(runtime):
    return [int(p) for p in re.findall(r"\d+", runtime.get("version", "0"))]


def runs_x86_64(runtime):
    archs = runtime.get("supportedArchitectures")
    if archs is None:  # metadata without the list: every runtime before iOS 26
        return version_key(runtime)[0] < 26
    return "x86_64" in archs


def main():
    kind = sys.argv[1]
    patterns = KINDS[kind]
    runtimes = [r for r in simctl("list", "runtimes")["runtimes"]
                if r.get("platform") == "iOS" and r.get("isAvailable")
                and runs_x86_64(r)]
    if not runtimes:
        sys.exit("no iOS simulator runtime that runs x86_64 apps (see the docstring)")
    runtime = max(runtimes, key=version_key)
    devices = simctl("list", "devices", "available")["devices"].get(runtime["identifier"], [])
    for pattern in patterns:
        matches = sorted((d for d in devices if re.search(pattern, d["name"])),
                         key=lambda d: d["name"], reverse=True)
        if matches:
            print(f"{matches[0]['udid']} {runtime['name']} {matches[0]['name']}", file=sys.stderr)
            print(matches[0]["udid"])
            return
    types = runtime.get("supportedDeviceTypes") or simctl("list", "devicetypes")["devicetypes"]
    for pattern in patterns:
        for device_type in sorted(types, key=lambda t: t["name"], reverse=True):
            if re.search(pattern, device_type["name"]):
                udid = subprocess.run(
                    ["xcrun", "simctl", "create", f"FL {device_type['name']}",
                     device_type["identifier"], runtime["identifier"]],
                    check=True, capture_output=True, text=True).stdout.strip()
                print(f"{udid} {runtime['name']} {device_type['name']} (created)", file=sys.stderr)
                print(udid)
                return
    sys.exit(f"no simulator matches {kind} on {runtime['name']}")


if __name__ == "__main__":
    main()
