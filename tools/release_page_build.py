"""Generate everything on the website that describes the current APK release.

    python tools/release_page_build.py          # write the site files
    python tools/release_page_build.py --check  # exit 1 if they are stale

One source of truth instead of ~12 hand edits per release:

  * version + build   <- pubspec.yaml
  * sizes + SHA-256s  <- the built APKs in build/release-v<version>/
  * changelog         <- tools/release_notes.json (newest first)

It rewrites only what sits between <!--gen:NAME--> ... <!--/gen:NAME--> markers
in website/index.html and website/teachers-guide.html, writes
website/version.json (read by the app's "Check for updates"), writes the
GitHub release notes to build/release-v<version>/RELEASE_NOTES.md, and bumps the
service-worker cache when a precached page changed so returning visitors get
the new text.

Guards (each one a build failure, not a warning):
  * the newest changelog entry must be the pubspec version and build;
  * every APK must exist in the release folder;
  * every marker must be present exactly where the page expects it.
"""
import hashlib, html, json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = os.path.join(ROOT, "website")
REPO = "jpaestedstu-prog/pwd_flashcard_app"
SITE_URL = "https://jpaestedstu-prog.github.io/pwd_flashcard_app/"
VARIANTS = [  # (file suffix, EN label, FIL label)
    ("arm64", "64-bit (standard)", "64-bit (standard)"),
    ("arm32", "32-bit", "32-bit"),
    ("universal", "Universal", "Universal"),
]


def fail(msg):
    sys.exit(f"release_page_build: {msg}")


def pubspec_version():
    text = open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8").read()
    m = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", text, re.M)
    if not m:
        fail("no `version: x.y.z+n` line in pubspec.yaml")
    return m.group(1), int(m.group(2))


def mb(size):
    # Same rounding the site has always used (MiB, as Flutter reports it).
    return f"{round(size / 1048576)} MB"


def load_release(version, build):
    notes = json.load(open(os.path.join(ROOT, "tools", "release_notes.json"), encoding="utf-8"))
    releases = notes["releases"]
    top = releases[0]
    if (top["version"], top["build"]) != (version, build):
        fail(f"newest release_notes.json entry is {top['version']}+{top['build']}, "
             f"pubspec says {version}+{build}")
    folder = os.path.join(ROOT, "build", f"release-v{version}")
    apks = []
    for key, en, fil in VARIANTS:
        name = f"FlashLearnPWD-v{version}-{key}.apk"
        path = os.path.join(folder, name)
        if not os.path.isfile(path):
            fail(f"missing {path} — build the APKs and copy them there first")
        data = open(path, "rb").read()
        apks.append({
            "key": key, "name": name, "label_en": en, "label_fil": fil,
            "bytes": len(data), "size": mb(len(data)),
            "sha256": hashlib.sha256(data).hexdigest(),
            "url": f"https://github.com/{REPO}/releases/download/v{version}/{name}",
        })
    return releases, apks, folder


def bi(en, fil):
    return f'<span class="en">{en}</span><span class="fil">{fil}</span>'


def render_download(version, releases, apks):
    std = apks[0]
    rows = "\n".join(
        f'              <tr><td><a href="{a["url"]}">{a["label_en"]}</a></td><td>{a["size"]}</td>'
        f'<td><code>{a["sha256"]}</code></td></tr>' for a in apks)
    changes = "\n".join(
        f'            <p><strong>v{r["version"]}</strong> — {r["date"]}<br>\n'
        f'            {bi(r["summary_en"], r["summary_fil"])}</p>' for r in releases)
    return f"""
        <ul class="dl-meta">
          <li>📦 <span><b>{bi("Version:", "Bersyon:")}</b> {version}</span></li>
          <li>🤖 <span><b>{bi("Requires:", "Kailangan:")}</b> {bi("Android 10 or newer", "Android 10 pataas")}</span></li>
          <li>💾 <span><b>{bi("Size:", "Laki:")}</b> {std["size"]}</span></li>
          <li>🔓 <span><b>Account:</b> {bi("none needed — open and learn", "hindi kailangan — buksan at matuto")}</span></li>
        </ul>
        <a class="btn btn-primary" href="{std["url"]}">⬇️ {bi(f"Download APK (v{version})", f"I-download ang APK (v{version})")}</a>
        <details class="dl-versions">
          <summary>{bi("Other versions &amp; checksums", "Iba pang bersyon at checksums")}</summary>
          <div class="body">
            <p style="font-size:.9em">{bi('If the standard APK says "app not compatible", try the 32-bit version. The universal APK works on every device but is larger.', 'Kung sinabi ng standard APK na "app not compatible", subukan ang 32-bit na bersyon. Gumagana ang universal APK sa lahat ng device ngunit mas malaki ito.')}</p>
            <table>
              <tr><th>APK</th><th>{bi("Size", "Laki")}</th><th>SHA-256</th></tr>
{rows}
            </table>
          </div>
        </details>
        <details class="dl-versions">
          <summary>{bi("What's new (changelog)", "Ano ang bago (changelog)")}</summary>
          <div class="body">
{changes}
          </div>
        </details>
        """


def render_jsonld(version, apks):
    return f"""<script type="application/ld+json">
{{
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  "name": "FlashLearn PWD",
  "operatingSystem": "Android 10+",
  "applicationCategory": "EducationalApplication",
  "description": "Free bilingual English/Filipino flashcard learning app designed for students with disabilities, with Filipino Sign Language support, games, stories, and a full accessibility suite.",
  "offers": {{ "@type": "Offer", "price": "0", "priceCurrency": "PHP" }},
  "downloadUrl": "{apks[0]["url"]}",
  "softwareVersion": "{version}"
}}
</script>"""


WELCOME = os.path.join(SITE, "assets", "videos", "fsl-welcome.mp4")


def render_fsl_welcome():
    """The FSL welcome for Deaf visitors — only once a signer has recorded it.

    Drop the clip at website/assets/videos/fsl-welcome.mp4 (and, optionally,
    fsl-welcome.en.vtt / fsl-welcome.fil.vtt captions) and re-run this script.
    Until then the section renders as nothing: no empty player, no placeholder.
    See docs/fsl_welcome_video.md for the script and the recording recipe.
    """
    if not os.path.isfile(WELCOME):
        return ""
    tracks = ""
    for lang, label, default in (("en", "English", " default"), ("fil", "Filipino", "")):
        if os.path.isfile(WELCOME.replace(".mp4", f".{lang}.vtt")):
            tracks += (f'\n        <track kind="captions" src="assets/videos/fsl-welcome.{lang}.vtt" '
                       f'srclang="{lang}" label="{label}"{default}>')
    return f"""
<section id="fsl-welcome" class="band" aria-labelledby="fslWelcomeTitle">
  <div class="wrap">
    <span class="section-label">🤟 {bi("Welcome in FSL", "Pagbati sa FSL")}</span>
    <h2 class="title" id="fslWelcomeTitle">{bi("A welcome in Filipino Sign Language", "Isang pagbati sa Filipino Sign Language")}</h2>
    <p class="lead">{bi("For Deaf and hard-of-hearing visitors: what FlashLearn PWD is and how to get it, signed in FSL.", "Para sa mga Deaf at mahina ang pandinig: kung ano ang FlashLearn PWD at paano ito makukuha, sa FSL.")}</p>
    <div class="demo-video">
      <video controls playsinline preload="metadata" src="assets/videos/fsl-welcome.mp4">{tracks}
      </video>
    </div>
  </div>
</section>
"""


def render_version_json(version, build, releases, apks):
    top = releases[0]
    return json.dumps({
        "_comment": "Generated by tools/release_page_build.py. Read by the app's Check for updates.",
        "latest": {
            "version": version,
            "build": build,
            "date": top["date"],
            "page": SITE_URL + "#download",
            "notes_en": top.get("notes_en", ""),
            "notes_fil": top.get("notes_fil", ""),
            "apks": {a["key"]: {"url": a["url"], "bytes": a["bytes"], "sha256": a["sha256"]} for a in apks},
        },
    }, indent=2, ensure_ascii=False) + "\n"


def render_release_notes(version, releases, apks):
    top = releases[0]
    lines = ["Public release of FlashLearn PWD — the free bilingual (English/Filipino) flashcard learning app for students with disabilities.", ""]
    if top.get("bullets_en"):
        lines += [f"**What's new since v{releases[1]['version']}**" if len(releases) > 1 else "**What's new**"]
        lines += [f"- {b}" for b in top["bullets_en"]] + [""]
    lines += ["Installs over earlier versions and keeps your profiles.", "", "**Which file do I download?**",
              f"- `{apks[0]['name']}` ({apks[0]['size']}) — standard, works on almost all Android 10+ devices",
              f"- `{apks[1]['name']}` ({apks[1]['size']}) — for older 32-bit devices",
              f"- `{apks[2]['name']}` ({apks[2]['size']}) — works everywhere", "",
              "**SHA-256 checksums**", "```"]
    lines += [f"{a['sha256']}  {a['name']}" for a in apks] + ["```", "", f"Website & install guide: {SITE_URL}", ""]
    return "\n".join(lines)


def replace_region(text, name, content, expect=1, path=""):
    pattern = re.compile(rf"(<!--gen:{name}-->)(.*?)(<!--/gen:{name}-->)", re.S)
    found = len(pattern.findall(text))
    if found != expect:
        fail(f"{path}: expected {expect} <!--gen:{name}--> region(s), found {found}")
    return pattern.sub(lambda m: m.group(1) + content + m.group(3), text)


def read(path):
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def main():
    check = "--check" in sys.argv
    version, build = pubspec_version()
    releases, apks, folder = load_release(version, build)

    outputs = {}
    p = os.path.join(SITE, "index.html")
    t = read(p)
    t = replace_region(t, "app-jsonld", render_jsonld(version, apks), path=p)
    t = replace_region(t, "download", render_download(version, releases, apks), path=p)
    t = replace_region(t, "apk-name", apks[0]["name"], expect=2, path=p)
    t = replace_region(t, "fsl-welcome", render_fsl_welcome(), path=p)
    outputs[p] = t
    p = os.path.join(SITE, "teachers-guide.html")
    outputs[p] = replace_region(read(p), "apk-size", apks[0]["size"], expect=2, path=p)
    outputs[os.path.join(SITE, "version.json")] = render_version_json(version, build, releases, apks)

    changed = [p for p, t in outputs.items() if not os.path.exists(p) or read(p) != t]
    if check:
        for p in changed:
            print("stale:", os.path.relpath(p, ROOT))
        sys.exit(1 if changed else 0)

    for p in changed:
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(outputs[p])
        print("wrote", os.path.relpath(p, ROOT))
    notes = os.path.join(folder, "RELEASE_NOTES.md")
    with open(notes, "w", encoding="utf-8", newline="") as f:
        f.write(render_release_notes(version, releases, apks))
    print("wrote", os.path.relpath(notes, ROOT))

    # Precached pages changed -> new cache name, or returning visitors keep the old text.
    precached = {os.path.join(SITE, n) for n in ("index.html", "teachers-guide.html")}
    if precached & set(changed):
        sw = os.path.join(SITE, "sw.js")
        s = read(sw)
        n = int(re.search(r"flp-site-v(\d+)", s).group(1))
        with open(sw, "w", encoding="utf-8", newline="") as f:
            f.write(s.replace(f"flp-site-v{n}", f"flp-site-v{n + 1}", 1))
        print(f"sw.js cache flp-site-v{n} -> v{n + 1}")
    print(f"v{version}+{build}: " + ", ".join(f"{a['key']} {a['size']}" for a in apks))


if __name__ == "__main__":
    main()
