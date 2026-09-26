# Free-Tier Feature & Backend Matrix

**Project:** `pwdpwdpwd` — Interactive Flashcard App for PWD Students
**Firebase project:** `pwd-flashcard`

## Summary

This app is **deliberately built to run entirely on Firebase's free Spark plan**. No billing
(Blaze) plan is required. The only cloud products it uses are:

- **Cloud Firestore** — the shared database (free quota: 50,000 reads + 20,000 writes/day).
- **Anonymous Authentication** — always free, no quota.
- **Firebase Analytics + Crashlytics** — opt-in only, default **OFF**, parent-gated; free on Spark.

There are **no Cloud Functions, no Cloud Storage, and no Firebase Cloud Messaging (push)** —
the three products that would otherwise force an upgrade to the paid Blaze plan. Everything
else is either local-only or backed by Firestore.

This is enforced and documented in code — see
[`lib/core/services/firebase_service.dart`](lib/core/services/firebase_service.dart) (lines 15–21)
and [`firestore.rules`](firestore.rules) (the `progress_audit` and `rate_limits` collections
are intentionally client-write-blocked; they would only be populated by a Blaze-tier Cloud
Function, and the app works correctly without them).

## Feature → backend → free-tier matrix

Legend — **Local:** no network used. **Firestore:** reads/writes Cloud Firestore (free on
Spark). **Auth:** Anonymous Authentication. **Billing (Blaze) required?** is **No** for every
feature.

| Feature | Backend used | Runs on free Spark plan? | Notes |
|---|---|:---:|---|
| **Analytics** (teacher analytics, progress analytics) | Firestore reads (profiles, progress), aggregated on-device; opt-in Firebase Analytics | ✅ Yes | No server-side compute — all aggregation is client-side. See [`teacher_analytics_screen.dart`](lib/features/teacher_analytics/screens/teacher_analytics_screen.dart). |
| **Dashboards** (student / multi-student / classroom / parent / gamification) | Firestore stream reads (profiles, progress, members) | ✅ Yes | Real-time via Firestore snapshots; falls back to local Hive cache when offline. |
| **Progress tracking** | Firestore read/write `progress/{id}`, `session_logs` | ✅ Yes | Offline writes queue and replay on reconnect. Client-side validation in [`progress_sync_listener.dart`](lib/core/services/progress_sync_listener.dart) replaces the Blaze-only server-side anti-cheat. |
| **Students** (profile management) | Firestore read/write `profiles/{id}` (+ cascade delete); Hive is the local source of truth | ✅ Yes | Hybrid local-first design; Firestore is the cross-device mirror. |
| **Reports** (weekly PDF, CSV / research export) | **Local only** — PDF/CSV generated on device | ✅ Yes | No network traffic. See [`report_generator.dart`](lib/features/reports/services/report_generator.dart). |
| **Task / assignment** | Firestore (assessment assignment + tracking) | ✅ Yes | Implemented through the assessment module: [`assessment_assign_screen.dart`](lib/features/assessment/screens/assessment_assign_screen.dart), [`assignment_tracking_screen.dart`](lib/features/assessment/screens/assignment_tracking_screen.dart). There is no separate `task_assignment` module. |
| **TV casting** | **Local network only** — in-app pure-Dart HTTP server (`shelf`), QR-code pairing | ✅ Yes | Zero backend; peer-to-peer over Wi-Fi. See [`tv_cast_server.dart`](lib/features/tv_cast/services/tv_cast_server.dart). No native cast SDK, so no Kotlin/KGP conflicts. |
| **Worksheets** | **Local only** — PDF generated from bundled seed data | ✅ Yes | See [`worksheet_service.dart`](lib/core/services/worksheet_service.dart). |
| **Classroom** | Firestore read/write `classrooms`, `classroom_members`, `classroom_audit` | ✅ Yes | Direct (non-queued) writes for responsive teacher UX. |
| **Assessments** | **Local (Hive)** for the question bank and results; Firestore only for assignment/tracking | ✅ Yes | See [`assessment_service.dart`](lib/features/assessment/services/assessment_service.dart). |
| **Shared media** (teacher pictures, videos, sounds and FSL clips on assessments, feedback and routines; learner video answers) | Firestore `shared_media/{id}` + `chunks` — each file split into ≤ 1 MB `bytes` pieces | ✅ Yes | Replaces Cloud Storage, which needs Blaze. Files are capped at **15 MB**; the rules enforce the cap and let only the uploading device write or delete. Each tablet downloads a file once and keeps it. See [`shared_media_service.dart`](lib/core/services/shared_media_service.dart); rules checked by `tool/shared_media_rules_probe.py`. |
| **Notifications** | **Local only** (`flutter_local_notifications`); parental alarms sync via Firestore, then fire locally on-device | ✅ Yes | **No FCM dependency at all.** See [`notification_service.dart`](lib/core/services/notification_service.dart). |
| **Live sessions** | Firestore `live_sessions/{classroomId}` + `responses` subcollection | ✅ Yes | Real-time via Firestore snapshots (not Cloud Functions). Requires connectivity while a session is live. |
| **Messaging / friends / home groups / parent-teacher notes** | Firestore (+ local Hive cache) | ✅ Yes | All paths covered by owner-scoped rules in [`firestore.rules`](firestore.rules). |
| **Messages: class broadcast, safety reports, classmate suggestions** | Firestore writes/reads (`messages`, `message_reports`, `classroom_members`, `home_group_members`, `home_groups`) | ✅ Yes | A broadcast is one ordinary message per learner, committed in batches (a class of 30 = 30 writes of the 20K/day budget). A report is one `message_reports` doc plus one message per teacher/parent (≤ 3 writes). Classmate suggestions are one-time reads of the learner's own class roster, only when the Add Friend dialog opens. The parent/child inbox adds one listener per home group, the same shape as the classroom listeners. No rules change, no Storage, no Functions. |
| **Messages: photos & recorded sign videos** | Firestore chunks via `SharedMediaService` (`shared_media`, tagged `purpose: message`) — **no Cloud Storage** | ✅ Yes | Videos ≤ 10 s (~1.25 MB at 1 Mbit/s), photos at the camera's medium size; at most 5 per learner per day; each file is deleted by the sender's own tablet after 7 days (`MessageMediaRetention`). Worst case (30 learners × 5 clips × 7 days) ≈ 1.3 GB; real use is megabytes. On Spark an over-quota write is refused, never billed.
| **Messages: server-side blocking & parent approval** | Firestore security rules (`hasBlocked`, `parentApproval`) | ✅ Yes | Rules deploys are free. A learner message costs one extra rule lookup (`blocks/{recipient}_{sender}`); educators skip it, so a class broadcast stays inside the per-batch lookup limit (verified: 25 messages in one batch). Checked by `tool/messaging_rules_probe.py` (37 checks). |
| **Parental controls** (time limits, alarms, unlock overrides, active-time logs) | Firestore docs read on the child's device, enforced/fired locally | ✅ Yes | |
| **Recovery / account linking** | Anonymous Auth → email/password link; `recovery_codes` in Firestore | ✅ Yes | Auth is free; the anonymous UID is preserved on link, so no data migration is needed. See [`firebase_service.dart`](lib/core/services/firebase_service.dart). |
| **Shop / achievements / gamification / stickers / mood / stories / games / learning paths** | Mostly local (Hive); progress mirrored to Firestore | ✅ Yes | |
| **Experiment / survey / showcase** | Local / Firestore reads | ✅ Yes | |

## Free-tier setup prerequisites

The app runs on Spark, but Firestore-backed features need two one-time console steps (already
documented in [`firebase_service.dart`](lib/core/services/firebase_service.dart), lines 23–34):

1. **Enable Anonymous sign-in** — Firebase Console → Authentication → Sign-in method →
   Anonymous → Enable. Without it, every Firestore read fails with `permission-denied`,
   because the rules require `request.auth != null`.
2. **Deploy the security rules** — `firebase deploy --only firestore:rules` from the project
   root. The default Firebase test-mode rules expire after 30 days and then deny everything.
3. **One online launch per device** — the anonymous UID is minted on first successful contact
   with Firebase Auth. After that it persists and the device can stay offline indefinitely.

If Firebase is not reachable (no config, offline first launch), the app degrades gracefully to
local-only: core learning (flashcards, games, stories, worksheets, reports, assessments) keeps
working from Hive, and pending cloud writes queue for later replay.

## What would force a Blaze (paid) plan — and why this app avoids it

| Product | Used here? | Why it would cost money |
|---|:---:|---|
| Cloud Functions | ❌ No | Deploying any function requires the Blaze plan. The app does server-side integrity checks client-side instead. |
| Cloud Storage | ❌ No | All assets are bundled or generated on-device; FSL videos are downloaded from GitHub Releases / Cloudinary and cached locally, not from Firebase Storage. Files that teachers pick and learners record are shared through **Firestore** instead (see *Shared media* above). |
| Firebase Cloud Messaging (outbound push) | ❌ No | No `firebase_messaging` dependency; all reminders are local notifications. |

`pubspec.yaml` confirms the absence of `cloud_functions`, `firebase_storage`, and
`firebase_messaging`.

## Free-tier quota headroom

Firestore Spark limits are **50,000 document reads** and **20,000 writes** per day. For a
classroom-sized deployment (~30 students), typical daily usage stays well within these limits,
especially because Hive serves as a local cache and offline persistence reduces redundant
reads.

Shared media is the heaviest user of the quota, so it is budgeted: a 5 MB clip is 6 writes to
upload and 7 reads per tablet that downloads it (once — every tablet keeps its copy), and
Spark's **1 GiB stored / 10 GiB downloaded per month** comfortably holds a class's worth of
short FSL clips recorded in the app at 480p (about 1 MB per 10 seconds). On Spark, running out
of quota never costs anything: uploads fail until the quota resets, and the app keeps the file
on the tablet and says "not shared yet". If a deployment ever outgrows the quota, the upgrade path is enabling Blaze for higher
Firestore quotas — still without needing Cloud Functions.
