# Multi-device sync: one profile, one owner

**Status:** current design, kept deliberately. True multi-device teacher
syncing is a future feature, not a defect to fix.

**Last verified:** 2026-08-22, on two physical devices (Honor tablet +
Pixel Tablet AVD, separate anonymous Firebase UIDs, same teacher profile).

## The rule

A profile is owned by exactly one device at a time.

`profiles/{id}.owner_uid` holds the anonymous Firebase uid of the owning
device. Every write rule in [`firestore.rules`](../firestore.rules) goes
through `ownsProfile(profileId)`, which reads that field:

```
function ownsProfile(profileId) {
  return signedIn()
    && exists(/databases/$(database)/documents/profiles/$(profileId))
    && get(/databases/$(database)/documents/profiles/$(profileId)).data.owner_uid == request.auth.uid;
}
```

Reads are open to any signed-in user. Writes are not.

## What a recovery code does

**Restoring a teacher profile onto another device moves ownership to that
device. It does not let both devices sync at the same time.**

`FirestoreRepository.claimProfileWithRecoveryCode` re-stamps `owner_uid` on
the profile and on every owner-scoped document that travels with it
(`progress`, `custom_cards`, `shop_equipped`, the `app_state` keys) to the
claiming device's uid, in one atomic batch.

From that moment the original device is **read-only in the cloud** for that
profile. It is not locked out of the app: local Hive is still the source of
truth there, so the teacher can still open their class, mark work and see
their data. Only the cloud mirror stops accepting its writes.

This is the correct behaviour for the case the feature exists to serve — a
device that was lost, broken or replaced should not keep writing.

## Why it is easy to misread

The old device keeps looking healthy, because reads still work. On that
device:

- a deleted assignment leaves the list, but its Firestore document survives;
- the other device hands the row straight back on its next pull;
- nothing is logged anywhere the teacher would see.

The symptom therefore appears on the *other* device, one step removed from
the action that caused it.

**Diagnose it by querying Firestore directly**, not by trusting either
screen. Reads are open to any signed-in user, so an anonymous account is
enough: sign in via `identitytoolkit accounts:signUp`, then `runQuery` the
collection. `tool/assessment_rules_probe.py` has the request shapes.

## What the app does about it

The limitation stands. The reporting around it was fixed on 2026-08-22.

`CloudSyncOutcome` is three-way, and the third value exists precisely for
this situation:

| outcome | meaning | what the user is told |
| --- | --- | --- |
| `synced` | in Hive and Firestore | "Assessment assigned to 2 learners!" |
| `localOnly` | in Hive; offline or unreachable | "not sent yet — it will upload when syncing is working" |
| `notOwner` | in Hive; **refused for good** | "This profile was restored on another device, so that one now handles syncing" |

`AssessmentCloudService.isOwnershipRefusal` classifies these: only
`FirebaseException.code == 'permission-denied'` is permanent. `unavailable`
and timeouts stay `localOnly` and keep promising a later upload, because for
those the promise is real.

Never collapse `localOnly` and `notOwner`. The difference is "not yet"
versus "never", and a teacher who waits for a sync that is never coming
loses a lesson. Any future synced feature that reports a write outcome needs
the same three-way split.

The recovery screens' own wording already frames the code as a move — "if
this one is lost or replaced", "your previous device" — and needs no change.

## If this is ever built for real

Widening the `owner_uid` check is the wrong move; it would hand write access
to anyone who ever held the profile. It needs a genuine membership model:

- an `editors` list (or subcollection) on the profile document, with
  `ownsProfile` becoming a membership test;
- a way to grant and revoke a device, and to see which devices hold a
  profile;
- last-write-wins is probably no longer good enough for assignments once two
  educators can edit concurrently.

Recovery codes are a poor foundation for that — they are one-time,
revoke-on-regenerate, and carry no notion of a device roster.

## Related

- `AssessmentCloudService` — the sync contract and the `notOwner` outcome
- `FirestoreRepository.claimProfileWithRecoveryCode` — where ownership moves
- `test/features/assessment/ownership_transfer_test.dart` — the guards
- [`firestore.rules`](../firestore.rules) — `ownsProfile`
