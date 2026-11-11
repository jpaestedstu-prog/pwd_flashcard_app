"""Records every element the page focuses, for the browser checks.

A screen reader announces whatever the page focuses. When a new screen
opened, NVDA said "unknown" for a moment before the screen's first button:
the page had focused something with no role and no name, or something about
to be removed. Installed before the app starts (Page.addScriptToEvaluateOnNewDocument,
so the DevTools driver only), this keeps a log of each focus: the element's
tag, role and name, the screen it was on, and whether it was still in the
page and still focused 150 ms later. `unnamed_focus(log)` lists the focuses a
screen reader would call "unknown".
"""

SCRIPT = r"""
(() => {
  const log = [];
  window.__focusLog = log;
  const label = (el) => (el.getAttribute('aria-label')
      || el.getAttribute('aria-labelledby') && '(labelled)'
      || el.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 70);
  document.addEventListener('focusin', (e) => {
    const el = e.target;
    if (!el || el === document.body || el === document.documentElement) {
      log.push({tag: 'body', t: Math.round(performance.now()), hash: location.hash});
      return;
    }
    const entry = {
      tag: el.tagName.toLowerCase(),
      role: el.getAttribute('role'),
      label: label(el),
      // A text box or a slider is read by its value too, and may be named by
      // the element around it.
      value: el.value === undefined ? null : String(el.value).slice(0, 40),
      type: el.type || null,
      around: el.parentElement
          ? (el.parentElement.getAttribute('aria-label') || '').slice(0, 70) : '',
      inside: [...el.querySelectorAll('[aria-label]')].slice(0, 3)
          .map((n) => (n.getAttribute('aria-label') || '').slice(0, 40)),
      t: Math.round(performance.now()),
      hash: location.hash,
    };
    log.push(entry);
    setTimeout(() => {
      entry.stillThere = el.isConnected;
      entry.stillFocused = document.activeElement === el;
    }, 150);
  }, true);
})();
"""

# The app's own host element: the page falls back to it between screens, and
# a screen reader says the document's name ("FlashLearn PWD, document").
_HOST = {"flutter-view", "body"}


def install(wd):
    """Installs the logger for the next page load (DevTools driver only)."""
    if hasattr(wd, "cdp"):
        wd.cdp.call("Page.addScriptToEvaluateOnNewDocument", {"source": SCRIPT})
        return True
    return False


def read(wd):
    return wd.js("return window.__focusLog || [];") or []


def unnamed_focus(log):
    """The focuses a screen reader would read as "unknown": a control with
    nothing to say, or a field gone the moment it was focused.

    A button that goes at once is not one: it is the button just pressed,
    gone with its screen.
    """
    bad = []
    for e in log:
        if e.get("tag") in _HOST:
            continue
        says = e.get("label") or e.get("around") or e.get("value")
        # A screen just opened: the reader reads what is in the group (NVDA, 4
        # Nov: "Mga Flashcard Deck, heading, Pumili ng kategorya...").
        if e.get("role") == "group":
            continue
        if e.get("stillThere") is False and e.get("role") not in ("button", "slider"):
            bad.append(("gone at once", e))
        elif not says:
            bad.append(("nothing to say", e))
    return bad
