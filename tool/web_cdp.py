"""Runs the browser checks (tool/web_smoke.py, tool/web_dpad_check.py) in the
Chrome or Edge already installed on this PC, with no WebDriver to download.

    python tool/web_cdp.py --check dpad  --url http://127.0.0.1:8080/ --out build/web_dpad
    python tool/web_cdp.py --check smoke --url http://127.0.0.1:8080/ --out build/web_smoke
    python tool/web_cdp.py --check speech --url http://127.0.0.1:8080/ --out build/web_speech
    python tool/web_cdp.py --check gamepad --url http://127.0.0.1:8080/ --out build/web_gamepad
    python tool/web_cdp.py --check mouse --url http://127.0.0.1:8080/ --out build/web_mouse

Both checks talk W3C WebDriver. This stands in for their `WebDriver` class
over the Chrome DevTools Protocol, which the browser itself serves when
started with --remote-debugging-port: keys, taps and typed text go in as real
input events, and the page is read with the same scripts the WebDriver runs
use. Serve the offline test build first (WEB_TEST=1 WEB_BASE_HREF=/ bash
tool/build_web.sh), e.g. `python -m http.server 8080 --bind 127.0.0.1
--directory build/web-test`.

Standard library only: the WebSocket is a minimal client (handshake, masked
text frames out, reassembled frames in) that only ever consumes complete
frames, so a timeout can never desynchronise the stream.
"""
import argparse
import base64
import json
import os
import socket
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

# WebDriver key code points -> (key, code, Windows virtual-key code).
_KEYS = {
    "\ue015": ("ArrowDown", "ArrowDown", 40),
    "\ue013": ("ArrowUp", "ArrowUp", 38),
    "\ue012": ("ArrowLeft", "ArrowLeft", 37),
    "\ue014": ("ArrowRight", "ArrowRight", 39),
    "\ue007": ("Enter", "Enter", 13),
    "\ue00c": ("Escape", "Escape", 27),
    "\ue004": ("Tab", "Tab", 9),
}


class _Socket:
    """A WebSocket client: enough of RFC 6455 for the DevTools Protocol."""

    def __init__(self, url):
        assert url.startswith("ws://"), url
        hostport, path = url[5:].split("/", 1)
        host, port = hostport.rsplit(":", 1)
        self.sock = socket.create_connection((host, int(port)), timeout=30)
        key = base64.b64encode(os.urandom(16)).decode()
        self.sock.sendall((
            f"GET /{path} HTTP/1.1\r\nHost: {hostport}\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        ).encode())
        reply = b""
        while b"\r\n\r\n" not in reply:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("the browser closed the connection")
            reply += chunk
        head, _, self.buf = reply.partition(b"\r\n\r\n")
        if b" 101 " not in head.split(b"\r\n", 1)[0]:
            raise RuntimeError(f"no WebSocket: {head[:200]!r}")

    def _write(self, opcode, data):
        header = bytearray([0x80 | opcode])
        n = len(data)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header += struct.pack(">H", n)
        else:
            header.append(0x80 | 127)
            header += struct.pack(">Q", n)
        mask = os.urandom(4)
        header += mask
        masked = bytes(b ^ mask[i & 3] for i, b in enumerate(data))
        self.sock.sendall(bytes(header) + masked)

    def send(self, text):
        self._write(0x1, text.encode())

    def _frame(self):
        """One complete frame off the buffer, or None (nothing consumed)."""
        b = self.buf
        if len(b) < 2:
            return None
        fin, opcode, n, at = b[0] & 0x80, b[0] & 0x0F, b[1] & 0x7F, 2
        if n == 126:
            if len(b) < 4:
                return None
            n, at = struct.unpack(">H", b[2:4])[0], 4
        elif n == 127:
            if len(b) < 10:
                return None
            n, at = struct.unpack(">Q", b[2:10])[0], 10
        if b[1] & 0x80:
            at += 4  # a masked server frame: not sent by browsers
        if len(b) < at + n:
            return None
        self.buf = b[at + n:]
        return fin, opcode, b[at:at + n]

    def recv(self, timeout):
        """The next whole text message, or None after [timeout] seconds."""
        end = time.time() + timeout
        parts = []
        while True:
            frame = self._frame()
            if frame is None:
                left = end - time.time()
                if left <= 0:
                    return None
                self.sock.settimeout(left)
                try:
                    chunk = self.sock.recv(1 << 20)
                except socket.timeout:
                    return None
                if not chunk:
                    raise RuntimeError("the browser closed the connection")
                self.buf += chunk
                continue
            fin, opcode, payload = frame
            if opcode == 0x9:
                self._write(0xA, payload)
                continue
            if opcode == 0x8:
                raise RuntimeError("the browser closed the connection")
            if opcode in (0x1, 0x0):
                parts.append(payload)
                if fin:
                    return b"".join(parts).decode("utf-8", "replace")


class Cdp:
    def __init__(self, ws_url):
        self.ws = _Socket(ws_url)
        self.next_id = 0
        self.events = []

    def call(self, method, params=None, timeout=60):
        self.next_id += 1
        mid = self.next_id
        self.ws.send(json.dumps({"id": mid, "method": method, "params": params or {}}))
        end = time.time() + timeout
        while time.time() < end:
            msg = self.ws.recv(max(0.05, end - time.time()))
            if msg is None:
                continue
            data = json.loads(msg)
            if data.get("id") == mid:
                if "error" in data:
                    raise RuntimeError(f"{method}: {data['error']}")
                return data.get("result", {})
            if "method" in data:
                self.events.append(data)
        raise RuntimeError(f"{method}: no answer in {timeout} s")


class CdpDriver:
    """The subset of web_smoke.WebDriver the checks use, over DevTools."""

    def __init__(self, browser=CHROME, port=9333, width=1280, height=900, headless=True):
        # A short, fresh profile: a long path breaks the service worker's
        # cache silently, and a reused one keeps the last run's app data.
        self.profile = tempfile.mkdtemp(prefix="cdpfl", dir=os.environ.get("TEMP"))
        args = [browser, f"--remote-debugging-port={port}",
                f"--user-data-dir={self.profile}", "--no-first-run",
                "--no-default-browser-check", "--hide-scrollbars",
                f"--window-size={width},{height}", "about:blank"]
        if headless:
            args.insert(1, "--headless=new")
        self.proc = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        end = time.time() + 30
        target = None
        while time.time() < end and target is None:
            try:
                with urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=3) as r:
                    pages = [t for t in json.loads(r.read()) if t.get("type") == "page"]
                    target = pages[0] if pages else None
            except OSError:
                time.sleep(0.5)
        if target is None:
            raise RuntimeError("the browser did not open its DevTools port")
        self.cdp = Cdp(target["webSocketDebuggerUrl"])
        for method in ("Page.enable", "Runtime.enable", "Log.enable", "Network.enable"):
            self.cdp.call(method)
        self.cdp.call("Network.setCacheDisabled", {"cacheDisabled": True})
        self.cdp.call("Network.setBypassServiceWorker", {"bypass": True})
        self.window(width, height)

    # -- what the checks call ------------------------------------------------
    def go(self, url):
        self.cdp.call("Page.navigate", {"url": url})
        end = time.time() + 60
        while time.time() < end:
            try:
                if self.js("return document.readyState;") == "complete":
                    return
            except RuntimeError:
                pass
            time.sleep(0.3)

    def js(self, script, *args):
        expression = f"(function(){{{script}\n}}).apply(null, {json.dumps(list(args))})"
        r = self.cdp.call("Runtime.evaluate", {
            "expression": expression, "returnByValue": True,
            "awaitPromise": True, "userGesture": True})
        if "exceptionDetails" in r:
            detail = r["exceptionDetails"]
            text = detail.get("exception", {}).get("description") or detail.get("text")
            raise RuntimeError(f"script failed: {str(text)[:300]}")
        return r.get("result", {}).get("value")

    def window(self, w, h):
        self.cdp.call("Emulation.setDeviceMetricsOverride", {
            "width": w, "height": h, "deviceScaleFactor": 1, "mobile": w < 600})

    def screenshot(self, path):
        data = self.cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
        with open(path, "wb") as f:
            f.write(base64.b64decode(data))

    def quit(self):
        try:
            self.cdp.call("Browser.close", timeout=5)
        except Exception:
            pass
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.proc.kill()

    def s(self, method, path, body=None):
        if path == "/actions":
            if method == "POST":
                for seq in body["actions"]:
                    if seq["type"] == "key":
                        self._keys(seq["actions"])
                    elif seq["type"] == "pointer":
                        self._pointer(seq["actions"])
            return None
        if path == "/element/active" and method == "GET":
            return {"element-6066-11e4-a932-00a07ad8a5d6": "active"}
        if path.startswith("/element/") and path.endswith("/value") and method == "POST":
            self.cdp.call("Input.insertText", {"text": body["text"]})
            return None
        if path == "/screenshot" and method == "GET":
            return self.cdp.call("Page.captureScreenshot", {"format": "png"})["data"]
        raise RuntimeError(f"{method} {path}: not supported over DevTools")

    # -- input -----------------------------------------------------------------
    def _keys(self, actions):
        for a in actions:
            if a["type"] == "pause":
                time.sleep(a.get("duration", 0) / 1000)
                continue
            key, code, vk = _KEYS[a["value"]]
            event = {"key": key, "code": code,
                     "windowsVirtualKeyCode": vk, "nativeVirtualKeyCode": vk}
            if a["type"] == "keyDown":
                if key == "Enter":
                    self.cdp.call("Input.dispatchKeyEvent", {**event, "type": "keyDown", "text": "\r"})
                else:
                    self.cdp.call("Input.dispatchKeyEvent", {**event, "type": "rawKeyDown"})
            else:
                self.cdp.call("Input.dispatchKeyEvent", {**event, "type": "keyUp"})

    def _pointer(self, actions):
        x = y = 0
        for a in actions:
            kind = a["type"]
            if kind == "pointerMove":
                x, y = a["x"], a["y"]
                self.cdp.call("Input.dispatchMouseEvent", {"type": "mouseMoved", "x": x, "y": y})
            elif kind == "pointerDown":
                self.cdp.call("Input.dispatchMouseEvent", {
                    "type": "mousePressed", "x": x, "y": y, "button": "left", "clickCount": 1})
            elif kind == "pointerUp":
                self.cdp.call("Input.dispatchMouseEvent", {
                    "type": "mouseReleased", "x": x, "y": y, "button": "left", "clickCount": 1})
            elif kind == "pause":
                time.sleep(a.get("duration", 0) / 1000)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", choices=["smoke", "dpad", "speech", "gamepad", "mouse"], required=True)
    ap.add_argument("--url", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--browser", choices=["chrome", "edge"], default="chrome")
    ap.add_argument("--mobile", action="store_true")
    ap.add_argument("--port", type=int, default=9333)
    args = ap.parse_args()

    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import web_dpad_check
    import web_gamepad_check
    import web_mouse_lang_check
    import web_smoke
    import web_speech_check

    driver = CdpDriver(CHROME if args.browser == "chrome" else EDGE, port=args.port)

    def factory(_base, _capabilities):
        return driver

    web_smoke.WebDriver = factory
    web_dpad_check.WebDriver = factory
    web_gamepad_check.WebDriver = factory
    web_mouse_lang_check.WebDriver = factory
    web_speech_check.WebDriver = factory
    argv = [sys.argv[0], "--driver", "devtools", "--browser", "chrome",
            "--url", args.url, "--out", args.out]
    if args.mobile and args.check == "smoke":
        argv.append("--mobile")
    sys.argv = argv
    {"dpad": web_dpad_check, "smoke": web_smoke, "speech": web_speech_check,
     "gamepad": web_gamepad_check, "mouse": web_mouse_lang_check}[args.check].main()


if __name__ == "__main__":
    main()
