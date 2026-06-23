# Gaze Control — Implementation Plan

Hands-free, voice-free control of the app for learners with severe motor
disability (e.g. total-body paralysis, missing limbs). The learner moves their
**head** toward an on-screen target and **dwells** to select, or uses a
**deliberate long blink** to confirm. Detection runs **fully on-device** via
Google ML Kit face detection — no internet, no API key, no paid tier.

> **Honest scope.** Consumer front cameras + ML Kit give reliable **head pose
> (yaw/pitch) + eye-open state**, *not* calibrated pupil gaze. So this is
> **head-and-blink control**, presented honestly as such. True pupil gaze would
> need a paid SDK (Tobii, eyedid/Seeso) and a calibration step. The head + dwell
> + blink design is what is robust and demo-safe on the hardware we target.

---

## 1. What already exists (prototype + Phases 1–3, Voice + Nav D-pad, in this branch)

The feature: prototype, settings/persistence, flashcard-viewer integration, a
reusable `GazeScope` (with a blink-scan fallback) any screen can adopt, optional
**voice commands**, and **hands-free bottom-nav** (a head-driven D-pad over the
tab bar). (An experimental **Head Pointer** mode was built and then removed — see
the note below.)

| Layer | File | Notes |
|---|---|---|
| Models | [gaze_models.dart](../lib/features/gaze_control/models/gaze_models.dart) | `GazeZone`, `FaceSignal`, `GazeReading` — no camera/ML Kit types |
| Models | [gaze_settings.dart](../lib/features/gaze_control/models/gaze_settings.dart) | persisted config; sensitivity→threshold mapping; scan mode |
| Models | [gaze_action.dart](../lib/features/gaze_control/models/gaze_action.dart) | a gaze-selectable action (zone + label/icon/colour + callback) |
| Logic (pure) | [gaze_zone_resolver.dart](../lib/features/gaze_control/logic/gaze_zone_resolver.dart) | head angles → target zone |
| Logic (pure) | [dwell_tracker.dart](../lib/features/gaze_control/logic/dwell_tracker.dart) | dwell-to-select state machine (edge-triggered) |
| Logic (pure) | [blink_detector.dart](../lib/features/gaze_control/logic/blink_detector.dart) | deliberate long-blink = confirm |
| Logic (pure) | [scan_cycler.dart](../lib/features/gaze_control/logic/scan_cycler.dart) | scanning-mode highlight index (wraps) |
| Logic (pure) | [nav_gaze_cursor.dart](../lib/features/gaze_control/logic/nav_gaze_cursor.dart) | bottom-nav D-pad cursor: wrap/move/sync over the tabs |
| Provider | [gaze_settings_provider.dart](../lib/features/gaze_control/providers/gaze_settings_provider.dart) | Hive-safe, fire-and-forget persistence |
| Gate | [gaze_camera_owners.dart](../lib/features/gaze_control/providers/gaze_camera_owners.dart) | app-wide single-camera owner count; shell nav-gaze yields to foreground camera surfaces |
| Service | [gaze_detector.dart](../lib/features/gaze_control/services/gaze_detector.dart) | ML Kit wrapper behind an injectable interface |
| Controller | [gaze_controller.dart](../lib/features/gaze_control/controllers/gaze_controller.dart) | reusable engine: camera stream + pipeline → `ChangeNotifier` state + `onSelect`/`onBlink` |
| Widgets | [gaze_widgets.dart](../lib/features/gaze_control/widgets/gaze_widgets.dart) | shared `GazeTarget` (dwell ring) + `GazeCameraView` |
| Widgets | [gaze_overlay.dart](../lib/features/gaze_control/widgets/gaze_overlay.dart) | generic non-interactive overlay (edge rings + camera PiP), driven by the action list |
| **Reusable API** | [gaze_scope.dart](../lib/features/gaze_control/widgets/gaze_scope.dart) | wrap any screen: pass up to 4 `GazeAction`s; handles camera, overlay, dwell + scanning, voice, settings-gating |
| **Reusable API** | [nav_gaze_scope.dart](../lib/features/gaze_control/widgets/nav_gaze_scope.dart) | wraps the nav shell: head ◀ ▶ moves a tab highlight, blink/look-up opens it; background camera owner (yields via `gazeCameraOwners`); ignores input while covered |
| Voice | [voice_commands.dart](../lib/features/gaze_control/logic/voice_commands.dart) · [voice_command_controller.dart](../lib/features/gaze_control/controllers/voice_command_controller.dart) | spoken phrase → action/scroll/back (pure resolver) + on-device STT loop |
| Screen | [gaze_settings_screen.dart](../lib/features/gaze_control/screens/gaze_settings_screen.dart) | config UI (sensitivity, hold time, blink, scanning, voice, calibration) + "Try it now" |
| Screen | [gaze_control_screen.dart](../lib/features/gaze_control/screens/gaze_control_screen.dart) | full-screen preview; a thin consumer of `GazeController` |
| **Integration** | [flashcard_viewer_screen.dart](../lib/features/flashcards/screens/flashcard_viewer_screen.dart) | wrapped in `GazeScope`: gaze drives Previous/Next/Hear/Flip; touch unchanged; **off unless enabled** |
| **Integration** | [communication_board_screen.dart](../lib/features/communication_board/screens/communication_board_screen.dart) | AAC board: a gaze **cursor** scrubs tiles (left/right), up=Speak, down=Add, blink=next category; touch unchanged; **off unless enabled** |
| **Integration** | [flashcard_quiz_screen.dart](../lib/features/games/screens/flashcard_quiz_screen.dart) | Flashcard Quiz game: look left = Still Learning, right = I Know (matches the swipe); disabled while paused; touch unchanged; **off unless enabled** |
| **Integration** | [picture_word_screen.dart](../lib/features/games/screens/picture_word_screen.dart) | Picture–Word MCQ: gaze **cursor** over the 3–4 choices (left/right), down or blink = Choose; works in both picture & word modes; touch unchanged; **off unless enabled** |
| **Integration** | [bottom_nav_shell.dart](../lib/navigation/bottom_nav_shell.dart) | wraps the shell in `NavGazeScope`: head D-pad over the tab bar (highlight ring + hint chip); touch unchanged; **off unless enabled** |
| Routes | [app_router.dart](../lib/navigation/app_router.dart) | `/gaze-settings`, `/gaze-control` |
| Entry | [settings_screen.dart](../lib/features/settings/screens/settings_screen.dart) | Settings → "Gaze Control (Preview)" → config screen |
| Tests | 11 files under `test/gaze_*` | 84 tests, all green |

**Design mirrors the existing Word Hunt feature** (`object_scan`): the same
hardened camera-lifecycle handling, the same "pure logic behind an injectable
interface so it is unit-testable without a device" pattern, the same
camera-less fallback screen.

### Adding gaze to another screen (the Phase 3 payoff)
Wrap the screen's body and pass the actions — a few lines, and it's inert unless
the learner enabled Gaze Control:

```dart
GazeScope(
  actions: [
    GazeAction(zone: GazeZone.left,  label: 'Back',  icon: Icons.arrow_back,    color: ..., onSelect: _back),
    GazeAction(zone: GazeZone.right, label: 'Next',  icon: Icons.arrow_forward, color: ..., onSelect: _next),
    GazeAction(zone: GazeZone.up,    label: 'Say',   icon: Icons.volume_up,     color: ..., onSelect: _say),
    GazeAction(zone: GazeZone.down,  label: 'Pick',  icon: Icons.check,         color: ..., onSelect: _pick),
  ],
  onBlink: _pick,
  child: myScreenBody,
)
```

### Verified in this environment
- `flutter analyze` — **no issues** (whole project).
- `flutter test` — **full suite green (1069/1069)**, including the eleven
  `test/gaze_*` files (**84/84**, of which `gaze_nav_test` covers the new D-pad
  cursor + `NavGazeScope` camera-owner gating). Existing screens are unchanged
  when gaze is off (the default), so the nav shell / viewer / board tests still
  pass.
- `flutter build apk --debug` — **builds** (ML Kit native dep integrates on
  Android: minSdk 29 + desugaring).
- Dependency resolves cleanly: `google_mlkit_face_detection: 0.13.2`, sharing
  `google_mlkit_commons 0.11.1` with the existing labeler.

### NOT yet verifiable here (needs a physical Android device)
- Live camera + ML Kit face detection on real hardware.
- The **front-camera mirror sign** (`mirrorHorizontal` in `gaze_detector.dart`)
  — confirm left/right aren't swapped; flip the flag if they are. This is the
  single tuning step before the prototype "feels right".
- Frame rate / battery on low-end devices.

---

## 2. Architecture

```
CameraImage (front, NV21/BGRA stream)
  └─ _inputImageFromCameraImage()         // rotation + format → InputImage
       └─ GazeDetector.detect(InputImage) // ML Kit FaceDetector
            └─ FaceSignal {turn, tilt, eyesOpen}   ← faceSignalFromAngles()
                 ├─ resolveGazeZone(signal)   → GazeZone (pure)
                 │     └─ DwellTracker.update(zone, t) → GazeReading (pure)
                 └─ BlinkDetector.update(eyes, t)      → bool (pure)
                      └─ UI: edge targets, dwell rings, selection
```

The three pure-logic units carry all the behaviour and **all the tests**. The
camera glue is deliberately thin and the one device-dependent piece
(`_inputImageFromCameraImage`) follows the official ML Kit example verbatim.

---

## 3. Roadmap to a shippable feature

### Phase 0 — Hardware validation *(do this first, ~½ day)*
Run the prototype on the **target tablet** + at least one phone. Confirm:
detection acquires a face at arm's length; the four targets fire from a
comfortable head movement; the mirror sign is correct; blink-to-confirm works.
Tune `kDefaultTurnThresholdDeg` / `kDefaultTiltThresholdDeg` /
`kDefaultDwellDuration` to the actual users. **Gate:** if detection is
unreliable on the real hardware, stop and reconsider before Phase 1.

### Phase 1 — Settings + persistence ✅ *(done)*
- ✅ `GazeSettings` model (enabled, sensitivity, hold/dwell time, blink, mirror,
  invert) persisted in the Hive `settings` box via `gazeSettingsProvider`. A
  single friendly **sensitivity** dial maps to the per-axis degree thresholds.
- ✅ **Config screen** (`/gaze-settings`) with sliders/toggles, on-device
  calibration switches (mirror / invert) for the left-right & up-down sign, and
  a "Try it now" launch into the live preview. The prototype now reads these
  settings (dwell time, thresholds, mirror/invert, blink on/off).
- ⏳ *Deferred:* per-learner (vs. per-device) gating and a guided face-framing
  step — fold into Phase 2 when gaze becomes a real input on learning screens.

### Phase 2 — Drive the flashcard viewer ✅ *(done)*
- ✅ `GazeController` (`ChangeNotifier`) owns the camera stream + pipeline and
  exposes `status`/`faceVisible`/`zone`/`progress` plus `onSelect`/`onBlink`.
  The full-screen preview and the viewer overlay share this one engine.
- ✅ `FlashcardViewerScreen` maps the four zones to its **real** actions —
  `up → Hear Word (TTS)`, `down → Flip`, `left → Previous`, `right → Next`,
  `blink → Flip` — with a non-interactive overlay showing edge dwell rings and a
  camera PiP. Selections trigger the viewer's existing handlers + haptic.
- ✅ **Touch stays fully working** (the overlay is `IgnorePointer`), and gaze is
  **off unless the learner enables it** in Settings, so the viewer is unchanged
  by default.
- ⏳ *Refinement:* anchor the dwell ring directly on each real button (instead of
  fixed edge positions) for a perfectly unified gaze/touch target — a polish
  step once on-device placement is validated.

### Phase 3 — Generalise ✅ *(done)*
- ✅ Reusable `GazeScope` widget: wrap any screen, pass up to four `GazeAction`s
  (one per edge) + an optional `onBlink`, and it handles the camera, overlay,
  dwell selection, and settings-gating. The flashcard viewer was refactored to
  use it, removing the bespoke Phase 2 wiring (one engine, one overlay, one path).
- ✅ On-screen **scanning fallback** (`scanMode`): the targets highlight one by
  one (`ScanCycler`, configurable speed) and the learner **blinks** to pick the
  highlighted one — for learners who can blink reliably but cannot move their
  head. Configurable from the settings screen.
- ✅ **First extra adopter — Communication Board (AAC).** Wrapped in `GazeScope`
  with a gaze **cursor** over the tile grid: look left/right to move the
  highlight, up to Speak the sentence, down to Add the highlighted tile, blink
  to cycle category — so a gaze-only learner can build and speak sentences and
  reach every word. The cursor auto-scrolls into view and the highlight only
  appears when Gaze Control is enabled; touch is unchanged. `wrapBoardIndex` is
  pure + unit-tested.
- ✅ **Second extra adopter — Flashcard Quiz game.** Wrapped in `GazeScope`:
  look left for "Still Learning", right for "I Know" (mirroring the swipe).
  Answers are disabled while paused and blink is intentionally unbound (so an
  involuntary blink can't submit), and touch is unchanged.
- ✅ **Third extra adopter — Picture–Word MCQ game.** A gaze **cursor** moves
  across the 3–4 answer choices (left/right), and look-down or blink chooses the
  highlighted one — working in both the picture-choice and word-choice modes.
  Disabled while a result is showing or paused; touch unchanged.
- ⏳ *Further adopters:* the remaining games (e.g. Word Match, Memory Match) can
  opt in with the same snippet (head-zone for ≤4 fixed actions, or a cursor for
  a grid), now that the two patterns are proven.

> **Removed — Head Pointer (was Phase 4).** A universal head-steered cursor
> (`GazePointerLayer`) was built and heavily tuned for noise — One Euro filter,
> dead-zone + clamp, `AnimatedPositioned` dampening, ~15 fps capture, a
> Steadiness setting, a `FaceSelector` reflection/second-face gate, an accurate-
> mode toggle, and wink-to-click. On real hardware the cursor still felt too
> shaky to rely on (consumer front-camera head-pose is inherently jittery and
> isn't true eye gaze), so the whole mode and all its tuning were **removed** to
> keep the feature focused on the modes that work well: **Big Targets** (+ its
> blink-scan fallback) and **Voice**. The pointer-only files
> (`gaze_pointer_layer`, `pointer_math`, `pointer_dwell`, `one_euro_filter`,
> `wink_detector`) and settings (control-style, steadiness, scroll speed,
> high-accuracy) are gone; the detector reverted to fast mode + `largestFace`.

> **Also removed earlier:** a *Switch / tap scanning* style (camera-free,
> tap-anywhere/external-switch), to keep the modes focused. (The camera
> **blink-scan** sub-mode of Big Targets, for blink-only learners, stays.)

### Phase 5 — Voice commands ✅ *(done)*
An **additive** capability (a toggle, not a style) that layers on top of any
control style — so a learner can use voice alone, or voice + gaze together.
- ✅ Reuses the existing on-device `SttService` (`speech_to_text`, EN + FIL,
  fuzzy matching) — **free, no API key, no billing.** `VoiceCommandController`
  keeps the mic re-armed across the engine's short listen bursts.
- ✅ Spoken phrase → intent via the pure, unit-tested `resolveVoiceCommand`:
  directional words ("next/previous/up/down", incl. Filipino "susunod/kaliwa/…")
  map to the screen's edge actions; label words ("flip", "hear", "speak",
  "choose") fuzzy-match the action labels; global commands handle
  **"scroll up/down"** (synthesised wheel) and **"go back"/"exit"** (navigate).
- ✅ Runs through the same per-screen `GazeAction`s, so every `GazeScope` screen
  (viewer, board, games) is voice-controllable with no extra wiring; a small
  "🎤 listening / last heard" chip gives feedback.
- ✅ `RECORD_AUDIO` + `microphone` (not required) declared in the manifest.
- ⏳ *Caveats (honest):* recognition latency/accuracy varies with child voices,
  Filipino accents and classroom noise (mitigated by the tiny command grammar +
  fuzzy match); and the app's own TTS speaks vocabulary words, which don't
  collide with the command words. Voice covers `GazeScope` screens, not every
  app screen. Needs on-device validation.

### Phase 6 — Hands-free bottom-nav (D-pad navigation) ✅ *(done)*
Big Targets answered "drive *this* screen"; this answers "**move between
screens**". The bottom tab bar (Home / Cards / Games / Stories / Progress, and
the educator/child variants) becomes a game-controller D-pad: **look ◀ / ▶** to
move a bright highlight ring across the tabs, **blink** (or **look up**) to open
the highlighted one. It reuses the exact head-zone + dwell + blink pipeline as
Big Targets — discrete, edge-triggered moves, **never the jittery continuous
cursor** of the removed Head Pointer.
- ✅ **Reliable by construction.** Each look is one D-pad step (the dwell tracker
  is edge-triggered: hold to fire once, return to centre to re-arm), so there's
  nothing to jitter. Movement is pure + unit-tested (`NavGazeCursor` /
  `wrapNavIndex`, wrapping like the AAC board cursor). Look-**down** is
  deliberately ignored so glancing at the bar can't open a tab by accident.
- ✅ **Mounted once on the long-lived shell** (`NavGazeScope` wraps the nav
  shell), so moving between tabs keeps the **same camera alive** — no
  re-initialise per tab, smooth scrubbing. The highlight re-syncs to the real
  selection on every tab change (gaze *or* touch).
- ✅ **One camera, ever.** The shell nav-gaze is a *background* camera owner: a
  tiny app-wide gate (`gazeCameraOwners`) is acquired by every foreground camera
  surface (the `GazeScope` activities, the gaze preview, Word Hunt's scanner) in
  `initState` and released in `dispose`; while it's held the shell stands its
  camera down and re-acquires on return. The hardware never runs two sessions.
- ✅ **No stray navigations.** Gaze input is ignored whenever the shell isn't the
  top route (`ModalRoute.isCurrent`, read live), and the camera stands down on
  immersive routes (nav bar hidden), so a head move under a pushed screen/dialog
  can never jump tabs.
- ✅ **Additive + inert by default.** Off unless "Enable Gaze Control" is on;
  touch is untouched. A small hint chip ("Look ◀ ▶ to choose · blink to open")
  appears above the bar only while it's active.
- ⏳ *Caveat (honest):* the brief camera hand-off when leaving/returning to a hub
  from a camera screen (a ~1 s "Starting gaze…") and the move/commit cadence are
  the things to confirm on-device; hold-time/sensitivity are tunable in Settings.

#### Phase 6b — D-pad reaches the Home feature tiles ✅ *(done)*
A new Settings choice, **"Bottom nav + Home tiles"** (`GazeNavScope`), extends the
same head D-pad up onto the Student / Child **Home** screen's feature tiles, so a
gaze-only learner can open any feature from Home — not just switch tabs.
- ✅ **One cursor spans both regions.** `NavGazeCursor` was generalised to a pure,
  unit-tested **2D ragged-grid** cursor (`GazeGridCursor`): the Home tile rows are
  stacked on top of the bottom-nav row (always the last row). **Look ◀ ▶** moves
  within a row (wraps), **▲ ▼** between rows; the single-row case is byte-identical
  to the old nav-only D-pad. A blink opens the focused tile; when blink is off,
  **look-up commits** so head-only learners keep an open gesture (rows stay
  reachable by looking down, which wraps).
- ✅ **Decoupled bridge.** The foreground Home screen publishes its tile grid to an
  app-wide `gazeHomeGrid` registry (rows of `GazeTileCell`, matching the visual
  `SliverGrid` layout) and the shell publishes back the focused cell, so Home draws
  the highlight ring + auto-scrolls it into view. The grid is built by
  `GazeTileGridBuilder` as the screen lays the tiles out, so the published rows can
  never disagree with what's on screen. Inert + a pure pass-through unless the
  combined scope is on, so touch and the gaze-off layout are unchanged.
- ✅ **Still one camera.** The Home grid opens no camera of its own — the shell's
  single nav-gaze camera drives it — so the single-session guarantee holds.
- ⏳ *Caveat (honest):* the vertical move/commit cadence over a long Home list, and
  the look-up-from-nav entry point, are the things to confirm on-device.

#### Phase 6c — D-pad reaches **every** hub + the flashcard viewer ✅ *(done)*
The "feature tiles" reach (Phase 6b) was generalised from Home-only to **all five
student/child hubs**, and the card viewer was reworked onto the same D-pad, so the
highlight navigates ◀ ▶ ▲ ▼ consistently throughout. (The setting is relabelled
**"Bottom nav + feature tiles"**.)
- ✅ **One gate, any tab.** `NavGazeScope` no longer requires the Home tab —
  `_useFeatureGrid` is simply `gazeHomeGrid.hasGrid`. Only the foreground hub
  publishes a grid (and clears it on dispose), so the live grid always belongs to
  the visible tab. `DeckListScreen` (Cards), `GameHubScreen` (Games),
  `StoryListScreen` (Stories, one section per category) and `ProgressScreen`
  (action buttons as 1-column rows) now feed `GazeTileGridBuilder` exactly like
  Home, and the state flag is `featureTilesActive`.
- ✅ **No teardown race.** During a tab fade both hubs briefly coexist; an
  **owner token** on `gazeHomeGrid.publishGrid/clearGrid` (held by each
  `GazeHomeRegistrar`) stops the outgoing screen's dispose from wiping the
  incoming grid. `GazeFocusable` gained an `expand:false` mode for Progress's
  full-width buttons in an unbounded list.
- ✅ **Viewer reworked to the shell D-pad.** The flashcard viewer dropped its
  edge-dwell `GazeScope` for a new reusable **`GazeDpadScope`** — a foreground,
  self-camera analogue of `NavGazeScope` that drives a `GazeGridCursor` over the
  bottom action bar (Previous · FSL · Show Me · Examples · Flip · Next): ◀ ▶ moves
  the ring, blink (or look-up) opens the focused control. Still one camera (it is
  the sole foreground `gazeCameraOwners` owner there).
- ✅ Tests: `gaze_dpad_scope_test` (scope wiring + foreground camera lifecycle),
  a non-Home-tab case in `gaze_nav_test`, and a stale-owner guard in
  `gaze_home_grid_test`. `flutter analyze` clean; full suite green.

---

## 4. Free-tier / cost confirmation

- **Google ML Kit face detection** runs **on-device**; the model is bundled in
  the APK. **No API key, no Firebase billing, no Google Cloud project, no
  internet at runtime.** Same family/licensing as the `google_mlkit_image_labeling`
  already shipping in Word Hunt.
- **Do not** use Cloud Vision API — *that* one bills. We don't need it.
- Net new cost: **₱0 / $0**. Only an APK size increase (a few MB for the model).

---

## 5. Compatibility plan (Android phones + tablets, all supported versions)

> A capstone can't literally test the entire Android fleet — no project can.
> What we *can* do is follow the practices that make wide compatibility the
> default, and degrade gracefully where a device falls short. Below is how each
> axis is handled.

| Axis | Approach |
|---|---|
| **Min Android version** | Project `minSdk 29`; ML Kit face detection needs only API 21. Covered. |
| **No front camera** | `camerasLoader` finds the front lens; if absent → friendly "needs a front camera" fallback (the app stays usable, gaze is just unavailable). `<uses-feature camera ... required="false"/>` is already declared. |
| **Permission denied / revoked** | Dedicated `permissionDenied` state with a retry; re-acquires when the user returns from system settings (lifecycle handler). |
| **Camera image format** | Request `nv21` on Android / `bgra8888` on iOS — the single-plane formats `InputImage` consumes directly; unexpected formats skip the frame instead of crashing. |
| **Sensor orientation / rotation** | `_inputImageFromCameraImage` computes rotation from sensor orientation + device orientation (front-lens formula), per the official ML Kit sample. |
| **Phone vs tablet screens** | UI is alignment-based (edge targets) + `SafeArea`; tested across the project's tablet/phone size + text-scale matrix with no overflow. Tablets *help* (bigger targets). |
| **Low-end CPU/GPU** | `ResolutionPreset.medium`, *fast* detector mode, one-frame-in-flight guard, and a 90 ms min frame gap to cap CPU/battery. |
| **Lifecycle (background, permission dialog)** | Same hard-won guards as Word Hunt. Crucially, a controller is **never disposed before `initialize()` completes** — CameraX throws `releaseFlutterSurfaceTexture() … not yet been initialized` otherwise. Teardown only disposes an *initialised* controller; if one is still starting, it's nulled out and the init path disposes it once the surface exists. The image stream is stopped before disposing and dwell/blink reset, all wrapped so platform errors during teardown can't surface. |
| **Single camera (no two-session clash)** | The bottom-nav gaze runs on the long-lived shell, so it could overlap a screen that opens its own camera. An app-wide `gazeCameraOwners` gate makes the shell a *background* owner: any foreground camera surface acquires it on mount / releases on dispose, and the shell stands its camera down while held. Guarantees one CameraX session at a time. |
| **Lighting / distance (physical)** | Out of software's control; mitigate with the aiming screen + a stand. Document recommended setup for the demo. |

---

## 6. Testing strategy

- **Pure logic** (resolver, dwell, blink, angle mapping): exhaustive unit tests
  with a fake clock — the behaviour that matters, fully covered, no device.
- **Screen**: widget test renders the camera-less fallback across the device/
  text-scale matrix (injected fake camera + detector), asserting no overflow.
- **On device** (manual, Phase 0): a short scripted checklist — acquire face,
  fire each of the four targets, blink-confirm, lose/recover face, background &
  resume, deny & re-grant permission.
- **Demo safety net:** record a screen-capture of a successful run as a backup
  in case live lighting is poor on presentation day.

---

## 7. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Live demo fails (lighting/angle) | Aiming screen + stand + recorded backup video; gaze is additive so touch always works. |
| Panel expects "real eye tracking" | Frame honestly as head + blink control; cite the SDK/calibration cost of true pupil gaze. |
| Accidental selections | Dwell deadzone + edge-triggered (look-away-to-re-arm) + tunable dwell time. |
| Detection jitter | Dominant-axis resolver ignores small movements; thresholds tunable per learner. |
| Scope creep on the timeline | Phases are independently shippable; Phase 0 is a go/no-go gate. |
```
