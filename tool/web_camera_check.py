"""Sign It's recording in a real browser with a REAL camera (not run in CI:
it needs one). Serves the offline test build (build/web-test), signs in as a
new Player, opens Sign It, records a few seconds of the camera, stops, and
checks the take replays: the replay pane says "Your take", a video playing
from the browser's own recording (a blob: address) has a picture and moves
on, and "Re-record" is offered. No screenshot is taken while the camera is
on, so nobody in front of it is pictured.

  python tool/web_camera_check.py --driver <chromedriver.exe> --out <dir>
      [--android SERIAL]

With --android the same walk runs in Chrome on that Android device (its own
camera): chromedriver drives it over adb (adb on PATH), and the device
reaches this PC's server through `adb reverse tcp:<port> tcp:<port>`.
Chrome there asks "use your camera?" as it would anyone: answer it on the
device ("Only this time" leaves nothing behind). Granting it through
DevTools instead (Browser.grantPermissions) stalls Chrome on Android: the
next tap never returns.
"""
import argparse
import importlib.util
import os
import subprocess
import sys
import time

# Screen text holds emoji; a Windows console's default code page has none.
sys.stdout.reconfigure(encoding="utf-8", errors="replace")

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location(
    "web_exports_check", os.path.join(HERE, "web_exports_check.py"))
wx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wx)
ws = wx.ws

# Every <video> on the page: the camera's live picture has a stream, the
# replay plays a blob: address (the browser's recording).
VIDEOS_JS = """
return [...document.querySelectorAll('video')].map(v => ({
  src: (v.currentSrc || v.src || '').slice(0, 40), stream: !!v.srcObject,
  w: v.videoWidth, h: v.videoHeight, t: v.currentTime,
  ready: v.readyState, paused: v.paused}));
"""

# When the camera does not start: what the browser itself says (its camera
# permission for the page, the cameras it lists, and a direct request).
DIAGNOSE_JS = """
const done = arguments[arguments.length - 1];
const within = (p, ms) => Promise.race([p, new Promise(
  r => setTimeout(() => r('no answer after ' + ms / 1000 + ' s'), ms))]);
(async () => {
  const out = {secure: window.isSecureContext, visible: document.visibilityState,
               focused: document.hasFocus()};
  out.permission = await within(navigator.permissions.query({name: 'camera'})
    .then(s => s.state, e => 'query failed: ' + e.name), 4000);
  out.devices = await within(navigator.mediaDevices.enumerateDevices()
    .then(ds => ds.map(d => d.kind + (d.label ? ' (named)' : '')),
          e => 'failed: ' + e.name), 4000);
  out.request = await within(navigator.mediaDevices.getUserMedia({video: true}).then(
    s => { s.getTracks().forEach(t => t.stop()); return 'granted'; },
    e => 'refused: ' + e.name + ' ' + e.message), 12000);
  done(out);
})();
"""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--driver", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--build", default=os.path.join(wx.REPO, "build", "web-test"))
    ap.add_argument("--port", type=int, default=8772)
    ap.add_argument("--android", metavar="SERIAL",
                    help="drive Chrome on this Android device")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    httpd = wx.serve(os.path.abspath(args.build), args.port)
    drv = subprocess.Popen([args.driver, "--port=9519"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    url = f"http://localhost:{args.port}{wx.BASE}"
    if args.android:
        # Attach to the Chrome already running and NEVER clear its data:
        # by default ChromeDriver may wipe the app's data directory first,
        # which on someone's own tablet is their history, tabs and logins.
        caps = {"browserName": "chrome", "goog:chromeOptions": {
            "androidPackage": "com.android.chrome",
            "androidDeviceSerial": args.android,
            "androidUseRunningApp": True,
            "androidKeepAppDataDir": True}}
    else:
        caps = ws.capabilities("chrome")
        # A real camera: the permission prompt is answered yes, and the
        # device is the real one (no --use-fake-device-for-media-stream).
        caps["goog:chromeOptions"]["args"] += ["--use-fake-ui-for-media-stream",
                                               "--disable-component-update"]
    caps["goog:loggingPrefs"] = {"browser": "ALL"}
    wd = ws.WebDriver("http://127.0.0.1:9519", caps)
    smoke = ws.Smoke(wd, url, args.out)
    results = []

    def record(name, ok, detail=""):
        results.append((name, ok, detail))
        print(("PASS  " if ok else "FAIL  ") + name + (f": {detail}" if detail else ""))

    own_tab = None
    try:
        if args.android:
            # A tab of the test's own, in front: the tab ChromeDriver attaches
            # to may be one of the person's, or one behind the others, and a
            # tab out of sight draws nothing, so every tap waits forever.
            own_tab = wd.s("POST", "/window/new", {"type": "tab"})["handle"]
            wd.s("POST", "/window", {"handle": own_tab})
            wd._call("POST", f"/session/{wd.sid}/goog/cdp/execute",
                     {"cmd": "Page.bringToFront", "params": {}}, timeout=20)
        else:
            wd.window(1280, 900)
        ok = smoke.onboard()
        record("sign in (a new Player)", ok, "" if ok else smoke.text()[:200])
        wd.js("location.hash = arguments[0];", "/games/fsl-practice/sign-it")
        time.sleep(6)
        ready = smoke.wait("Record", 60)
        record("the camera starts (a real one)", bool(ready),
               "" if ready else smoke.text()[:240])
        if not ready:
            try:
                print("  browser says:", wd.s("POST", "/execute/async",
                                             {"script": DIAGNOSE_JS, "args": []}))
            except (RuntimeError, OSError) as e:
                print("  browser says: (no answer)", str(e)[:160])
        if ready:
            live = wd.js(VIDEOS_JS) or []
            record("the live picture is the camera's",
                   any(v["stream"] and v["w"] > 0 for v in live), str(live))
            smoke.click("Record")
            time.sleep(4)
            stop = smoke.wait("Stop", 10)
            record("recording", bool(stop))
            smoke.click("Stop")
            take = smoke.wait("Your take", 20)
            time.sleep(3)
            blobs = [v for v in (wd.js(VIDEOS_JS) or []) if v["src"].startswith("blob:")]
            moving = False
            if blobs:
                first = blobs[0]["t"]
                time.sleep(2)
                again = [v for v in (wd.js(VIDEOS_JS) or []) if v["src"].startswith("blob:")]
                moving = bool(again) and (again[0]["t"] != first or not again[0]["paused"])
            record('the take replays ("Your take", a blob: video with a picture, playing)',
                   bool(take) and bool(blobs) and blobs[0]["w"] > 0 and moving,
                   str(blobs))
            record("Re-record is offered", bool(smoke.find("Re-record")))
            smoke.click("Re-record")
            time.sleep(3)
            record("Re-record goes back to the camera",
                   bool(smoke.wait("Stop", 10)
                        or smoke.wait("Record", 10)))
        errs = smoke.page_errors()
        bad = [b for b in ws.BAD_TEXT if b in smoke.text()]
        record("no app errors", not errs and not bad, "; ".join(map(str, errs))[:300])
    finally:
        # Leaves Sign It (and the camera) before the one screenshot.
        try:
            wd.js("location.hash = arguments[0];", "/home")
            time.sleep(3)
            smoke.shot("after_camera")
        except Exception:
            pass
        if args.android:
            # Takes the test's own site data off the tablet's Chrome (its
            # profile, its storage) and closes the test's tab.
            try:
                wd._call("POST", f"/session/{wd.sid}/goog/cdp/execute", {
                    "cmd": "Storage.clearDataForOrigin",
                    "params": {"origin": f"http://localhost:{args.port}",
                               "storageTypes": "all"}}, timeout=30)
                if own_tab:
                    wd.s("DELETE", "/window")
            except Exception as e:
                print("  cleanup:", str(e)[:120])
        wd.quit()
        drv.kill()
        httpd.shutdown()

    failed = [r for r in results if not r[1]]
    print(f"WEB CAMERA: {len(results) - len(failed)} of {len(results)} passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
