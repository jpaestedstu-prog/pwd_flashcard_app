# Signing FlashLearn PWD

Every FlashLearn PWD APK is signed with one key. Android installs an update
over an existing copy only when the update carries the same key, so this key
is what keeps every tablet updatable. Lose it and no installed copy can ever
be updated again; leak it (with its password) and anyone could sign an
"update" that tablets would accept.

## Where it lives

| File | What |
| --- | --- |
| `~/.flashlearn-signing/flashlearn-release.p12` | The key. PKCS12, alias `flashlearn`, valid until 2056, SHA-256 `AF:D7:30:B9:0F:AB:C1:1A:2D:CD:07:D1:98:58:76:4C:4C:68:A4:E3:3F:0E:5F:59:B3:F8:68:BB:37:3F:2B:A8` |
| `~/.flashlearn-signing/key.properties` | Where the key is and its password. Read by `android/app/build.gradle.kts`. |
| `Documents/FlashLearn PWD - signing key backup/` | The backup: the key and a README, **no password**. |

Both live outside the project folder, so zipping, sharing or pushing the
project never shares them. Their folders are readable only by the owner's
Windows account (and SYSTEM). Keep extra copies of the backup folder on a USB
drive and in a private cloud folder, and the password in a password manager
or on paper, away from those copies.

## History

Versions 1.0.0 to 1.2.2 were signed with this PC's Android debug keystore
(`~/.android/debug.keystore`). That key was generated on this PC and exists
nowhere else, but every debug keystore uses the public password `android`.
On 4 October 2026 the same key moved into its own keystore with a strong
random password. The certificate, and so every signature, is unchanged:
installed copies update exactly as before. The copies behind the public
password were deleted.

## How the build uses it

- **Every build type signs with it** — debug, profile and release. A debug
  build therefore installs over a tablet's real copy. This matters: when
  `flutter run` meets a signature mismatch it *uninstalls* the app, which
  wipes every profile on a shared study tablet.
- **No key, no build.** Gradle stops with a message if `key.properties` is
  missing, rather than signing with some other key.
- `FLASHLEARN_SIGNING_PROPERTIES` may point at a `key.properties` somewhere
  else (a backup restored to another folder).

## Another PC

- **To release from another PC**, restore the backup — its README has the
  four steps.
- **For a throwaway build on a PC without the key**, point
  `FLASHLEARN_SIGNING_PROPERTIES` at a properties file for that PC's own
  debug keystore. Never install such a build on a study tablet: it cannot
  update the real app, and `flutter run` would uninstall it.

## If the key or its password is ever exposed

Move to a new key with Android's key rotation (APK Signature Scheme v3),
which lets installed copies accept the new key without reinstalling:

```sh
apksigner rotate --out lineage.bin \
  --old-signer --ks flashlearn-release.p12 --ks-key-alias flashlearn \
  --new-signer --ks new-release.p12 --ks-key-alias flashlearn2
# then, for every APK `flutter build apk` produces:
apksigner sign --rotation-min-sdk-version 29 \
  --ks flashlearn-release.p12 --ks-key-alias flashlearn \
  --next-signer --ks new-release.p12 --ks-key-alias flashlearn2 \
  --lineage lineage.bin app-release.apk
apksigner verify -v --print-certs app-release.apk
```

`--rotation-min-sdk-version 29` matches the app's minSdk; without it the
rotation only takes effect on Android 13 and newer. Both keys must then be
kept safe, and the first rotated build should be tried as an update on a
spare device before it reaches a study tablet. `apksigner` is in
`C:\Android\Sdk\build-tools\36.1.0\`.
