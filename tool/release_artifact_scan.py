"""Checks release files for anything that must never ship.

    python tool/release_artifact_scan.py build/release-v1.4.0/*.apk build/store-v1.4.0/*

For each APK / AAB / IPA (all zip files): no signing material or passwords,
no private keys, no test-only code or fixtures, no app data files (Hive
boxes), no local paths from the build PC, and not debuggable. Prints every
finding; exits 1 if there is one. Reads only.
"""
import re, subprocess, sys, zipfile
from pathlib import Path

NAME_BAD = re.compile(
    r'(\.(jks|keystore|p12|pfx|pem|hive|hivec|lock)$)|key\.properties|play-upload|'
    r'flashlearn-release|google-services\.json$|/test/|integration_test|face_photo|'
    r'\.env$', re.I)


def build_pc_paths():
    """The build PC's home folder and user name, in the forms a leaked path
    takes. Read at run time, so the scanner names nobody in the public repo."""
    home = Path.home()
    names = {home.name}
    if sys.platform == 'win32':  # the 8.3 form of the folder (C:\Users\ABCDEF~1)
        import ctypes
        buf = ctypes.create_unicode_buffer(260)
        if ctypes.windll.kernel32.GetShortPathNameW(str(home), buf, 260):
            names.add(Path(buf.value).name)
    alts = [re.escape(str(home).encode()), re.escape(home.as_posix().encode())]
    alts += [re.escape(n.encode()) for n in names if len(n) >= 4]  # a short name would match anything
    return re.compile(b'|'.join(alts), re.I)


CONTENT_BAD = [
    (re.compile(rb'-----BEGIN [A-Z ]*PRIVATE KEY-----'), 'a private key'),
    (re.compile(rb'storePassword|keyPassword'), 'a signing password field'),
    (re.compile(rb'IntegrationTestPlugin|integration_test/'), 'test-only code'),
    (re.compile(rb'faceJpegBase64|walk_face\.jpg'), 'the walkthrough face fixture'),
    (build_pc_paths(), 'a path from the build PC'),
    (re.compile(rb'\.flashlearn-signing'), 'the signing folder name'),
]
# Big media are not worth scanning byte by byte.
SKIP = re.compile(r'\.(mp4|mp3|wav|ogg|png|jpg|jpeg|webp|gif|ttf|otf|woff2?)$', re.I)


def debuggable(path):
    if not path.endswith('.apk'):
        return None
    tool = sorted(Path(r'C:\Android\Sdk\build-tools').glob('*'))[-1] / 'aapt2.exe'
    out = subprocess.run([str(tool), 'dump', 'badging', path], capture_output=True, text=True).stdout
    return 'application-debuggable' in out


def scan(path):
    findings = []
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        for n in names:
            if NAME_BAD.search(n):
                findings.append(f'file {n}')
            if SKIP.search(n):
                continue
            data = z.read(n)
            for rx, what in CONTENT_BAD:
                if rx.search(data):
                    findings.append(f'{what} in {n}')
    dbg = debuggable(path)
    if dbg:
        findings.append('the APK is debuggable')
    return len(names), findings


def main():
    bad = 0
    for p in sys.argv[1:]:
        if not Path(p).is_file() or not re.search(r'\.(apk|aab|ipa)$', p):
            continue
        count, findings = scan(p)
        print(f'{"FAIL" if findings else "ok  "} {Path(p).name}: {count} files')
        for f in sorted(set(findings))[:20]:
            print('      ', f)
        bad += bool(findings)
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
