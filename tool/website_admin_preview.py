"""Try the website and its admin dashboard together on this computer, with the
LOCAL Firebase emulators: nothing real is read or written, and it works offline.

    cd website_admin
    firebase emulators:start --only firestore,auth --project demo-flashlearn-site
    python tool/website_admin_preview.py            (in another terminal, from the repository root)

Then, in one browser:
  1. open the address it prints for the WEBSITE: it marks that browser so the local
     website counts its visits and sends its messages to the emulator (the published
     website never does this), then shows Home;
  2. open the DASHBOARD address in another tab and sign in with the email and
     password it prints (an administrator it creates in the emulator).
Every page you open, Download you press, sign you play and message you send on the
local website appears in the dashboard as it happens. The emulator starts empty;
stopping it forgets everything. Press Ctrl+C here to stop serving.
"""
import functools, http.server, json, os, socket, sys, threading, urllib.error, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import website_admin_e2e_check as h  # noqa: E402  (its servers and the dashboard's headers)

PROJECT = h.PROJECT
EMAIL, PASSWORD = "preview@example.com", "preview-password-123"
MARK = ("<!doctype html><meta charset=utf-8><title>Preview</title><script>"
        "localStorage.setItem('flp-stats-test', JSON.stringify({base: 'http://127.0.0.1:8080/v1', project: '" + PROJECT + "'}));"
        "localStorage.removeItem('flp-nocount'); location.replace('index.html');</script>")


class Site(h.Quiet):
    def do_GET(self):
        if self.path.split("?")[0] == "/__preview":
            body = MARK.encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def up(port):
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", port)) == 0


def main():
    for port in (8080, 9099):
        if not up(port):
            sys.exit("Start the emulators first (port %d is closed): see this file's docstring." % port)
    # An administrator for the preview (created again if the emulator was restarted).
    st, d = h.rest("POST", f"{h.AUTH}/accounts:signUp?key=demo-key", {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True}, token=None)
    if st != 200:
        st, d = h.rest("POST", f"{h.AUTH}/accounts:signInWithPassword?key=demo-key", {"email": EMAIL, "password": PASSWORD, "returnSecureToken": True}, token=None)
    if st != 200:
        sys.exit("Could not create the preview administrator: " + str(d))
    h.rest("PATCH", f"{h.FS}/admins/{d['localId']}", {"fields": {"name": {"stringValue": "Preview administrator"}}})
    h.serve(8899, os.path.join(h.ROOT, "website"), Site)
    h.serve(8898, os.path.join(h.ROOT, "website_admin", "public"), h.AdminHandler)
    print("WEBSITE    http://127.0.0.1:8899/__preview   (marks this browser, then opens Home)")
    print("DASHBOARD  http://127.0.0.1:8898/?emulator")
    print(f"           sign in with {EMAIL} / {PASSWORD}  (\"Use an email and password instead\")")
    print("Serving until Ctrl+C.", flush=True)
    try:
        threading.Event().wait()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
