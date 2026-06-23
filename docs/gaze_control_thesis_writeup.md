# Gaze Control for Learners with Severe Motor Disability

*A writeup for the thesis. Honest about what the technology does and does not
do — this framing is a strength in front of a panel, not a weakness.*

---

## 1. Rationale

FlashLearn PWD already removes many barriers for Persons With Disabilities:
text-to-speech and a Filipino Sign Language dictionary for Deaf/Hard-of-Hearing
learners, voice-guided navigation and high-contrast/large-text modes for
low-vision learners, and an AAC communication board for non-speaking learners.
One group, however, is still effectively excluded: learners with **severe motor
disability** — total-body paralysis, quadriplegia, or absent limbs — who can
neither tap the screen nor speak commands.

**Gaze Control** closes that gap. The learner operates the app using only
**head movement and blinks**, captured by the device's ordinary **front
camera**. No tapping, no speaking, no extra hardware — the same tablet every
other learner uses.

## 2. What it actually is (and is not)

It is important to state precisely what the technology does, because the term
"eye-tracking" is often over-promised.

- **What it does:** using on-device computer vision, the app estimates the
  learner's **head orientation** (turning left/right, tilting up/down) and
  whether their **eyes are open or shut**. The learner points their head toward
  an on-screen target and holds it briefly to select; a deliberate long blink
  acts as a confirm.
- **What it is *not*:** it is **not** calibrated pupil-gaze tracking — it does
  not compute the exact pixel the learner's pupils are aimed at. True pupil gaze
  on a phone/tablet requires a commercial, **paid** SDK and a per-user
  calibration step. We deliberately chose the head-and-blink approach because it
  is **reliable, calibration-free, and free** on the hardware our learners
  already have.

Framed correctly, this is **head-pose and blink control** — a recognised and
respected accessibility technique (the same family as "switch access" and
"dwell clicking" on desktop operating systems).

## 3. How it works

1. **Capture.** The front camera streams frames to the app. Nothing leaves the
   device.
2. **On-device vision.** Google ML Kit's face-detection model (bundled inside
   the app, running fully offline) returns, per frame, the head's rotation
   angles and each eye's open/closed probability.
3. **Zone resolution.** The head angles are mapped to one of four on-screen
   **targets** arranged on the edges of the screen — *Hear Word* (up),
   *Flip Card* (down), *Previous* (left), *Next* (right). A central rest zone
   means "doing nothing", so the learner can relax without triggering anything.
4. **Dwell to select.** While the learner holds their head toward a target, a
   ring fills around it. When the ring completes (≈1.5 s, adjustable), the
   action fires once. Looking away and back is required before it can fire
   again, preventing accidental repeats.
5. **Blink to confirm.** A deliberate long blink (both eyes shut past a short
   threshold) provides an alternate confirm gesture for learners who blink more
   reliably than they move.

The selection logic (zone mapping, dwell timing, blink detection) is
implemented as **pure, deterministic functions** and is covered by an automated
test suite, so its correctness does not depend on camera conditions.

## 4. Why on-device and free

The feature uses **Google ML Kit face detection**, which runs **entirely on the
device**. This yields three properties that matter for a school deployment in
the Philippines:

- **No cost.** No API key, no cloud billing, no subscription. It reuses the same
  on-device ML Kit family already powering the app's "Word Hunt" object-recognition
  feature.
- **Works offline.** No internet is required — important where connectivity is
  unreliable.
- **Privacy-preserving.** The camera feed is processed on-device and never
  uploaded or stored; only abstract numbers (angles, probabilities) are used,
  and they are discarded each frame.

## 5. Benefit for PWD students

For a learner with severe paralysis, the difference is categorical, not
incremental: from **cannot use the app at all** to **can study vocabulary,
flip flashcards, hear words spoken, and move through a lesson independently** —
without a caregiver operating the device for them. It restores **autonomy**,
which is itself an educational and dignity outcome, not merely a convenience.

Because gaze is **additive** — touch and all existing inputs keep working — the
feature also supports learners with *partial* motor ability, who can mix head
control with occasional taps.

## 6. Accuracy, limitations, and honesty for the panel

- **Lighting and camera angle matter.** Detection needs the learner's face
  reasonably lit and within the camera's view; a simple tablet stand and an
  in-app "aiming" screen mitigate this.
- **Resolution, not precision.** Four large edge targets (plus a rest zone) are
  used precisely because coarse, dominant head movements are reliable, whereas
  fine pointing is not. This is a deliberate accuracy-for-robustness trade.
- **Per-learner tuning.** Dwell time and movement thresholds are adjustable, so
  the experience can be matched to a learner's range of motion.
- **Not a medical device.** It is an assistive input method, evaluated for
  usability, not a clinical instrument.

Stating these limits plainly is the academically honest position and pre-empts
the panel's most likely challenge ("is this *really* eye tracking?").

## 7. Evaluation method (proposed)

Consistent with the app's existing triangulated usability approach
(see [sus_methodology.md](sus_methodology.md)):

- **Task-completion** with a small number of learners/proxies: can the
  participant complete a set of flashcard actions using gaze only? Record
  success rate, time-per-selection, and accidental-selection rate.
- **Facilitator SUS** (teacher/caregiver) for the setup-and-support experience.
- **Smileyometer** (3-face visual scale) for the learner's own experience.
- Report results descriptively; this is a feasibility/usability study of a new
  input modality, not a controlled efficacy trial.

## 8. Current status and future work

A **working prototype** is implemented (Settings → "Gaze Control (Preview)")
that demonstrates the full interaction — live camera, four dwell targets,
progress rings, and blink confirm — on a real device. The remaining work to
make it a first-class app feature (persisted settings, an aiming/calibration
step, and wiring gaze into the flashcard viewer's real buttons so touch and gaze
share one UI) is specified in [gaze_control_plan.md](gaze_control_plan.md).

Possible future extensions: an automatic **scanning** fallback (the app
highlights each target in turn and the learner blinks to choose) for learners
who cannot move their head reliably; and, if budget ever allows, an optional
upgrade to a calibrated pupil-gaze SDK for fine pointing.
