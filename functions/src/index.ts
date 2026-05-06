import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {logger} from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();

// Per-write star gain ceiling. A single game session in this app awards
// at most 5 stars; 50 leaves room for batched updates without flagging.
const MAX_STAR_GAIN_PER_WRITE = 50;

// Per-uid throughput cap on progress writes. Catches accidental loops and
// trivial scripted abuse without affecting normal play (a kid finishing a
// game emits a handful of writes, not dozens).
const MAX_PROGRESS_WRITES_PER_MINUTE = 30;

// In-app, a single GameScore awards at most 5 stars and asks at most 20
// questions. Anything beyond is a malformed or fabricated entry.
const MAX_STARS_PER_GAME_SCORE = 5;
const MAX_TOTAL_PER_GAME_SCORE = 50;

// Server-side reverts re-write the doc, which would re-trigger this
// function. We stamp `_revertedAt` on the revert and skip any incoming
// write that matches recently — short-circuits the loop without needing
// a separate "is this the admin SDK?" signal.
const REVERT_SUPPRESSION_WINDOW_MS = 10_000;

interface ProgressDoc {
  owner_uid?: string;
  words_learned?: number;
  total_stars?: number;
  spent_stars?: number;
  category_progress?: Record<string, number>;
  recent_scores?: Array<Record<string, unknown>>;
  _revertedAt?: admin.firestore.Timestamp;
}

/**
 * Validates every write to progress/{profileId}. Violations are logged to
 * progress_audit and the doc is reverted to its prior state.
 *
 * Trust boundary: the client app is hostile by default. A student with
 * root access to their device can edit Hive directly and force a sync,
 * so any check that only runs on the client is bypassable. This function
 * is the authority on what counts as a legitimate progress update.
 */
export const validateProgressUpdate = onDocumentWritten(
  "progress/{profileId}",
  async (event) => {
    const profileId = event.params.profileId;
    const before = event.data?.before.data() as ProgressDoc | undefined;
    const after = event.data?.after.data() as ProgressDoc | undefined;

    // Doc deletion — nothing to validate.
    if (!after) return;

    // Skip our own revert writes.
    const revertedAt = after._revertedAt?.toMillis();
    if (revertedAt && Date.now() - revertedAt < REVERT_SUPPRESSION_WINDOW_MS) {
      return;
    }

    const ownerUid = after.owner_uid;
    if (!ownerUid) {
      // Phase A rules already require owner_uid on writes; if one slips
      // through (e.g. legacy doc), we can't rate-limit by uid. Log and
      // bail — don't revert, since there's no "before" owner to restore.
      logger.warn("progress doc missing owner_uid", {profileId});
      return;
    }

    // ─── Validation ────────────────────────────────────
    const violations: string[] = [];

    if (before?.owner_uid && before.owner_uid !== ownerUid) {
      violations.push(
        `owner_uid changed: ${before.owner_uid} → ${ownerUid}`,
      );
    }

    const beforeWords = before?.words_learned ?? 0;
    const afterWords = after.words_learned ?? 0;
    if (afterWords < beforeWords) {
      violations.push(`words_learned regressed: ${beforeWords} → ${afterWords}`);
    }

    const beforeStars = before?.total_stars ?? 0;
    const afterStars = after.total_stars ?? 0;
    if (afterStars < beforeStars) {
      violations.push(`total_stars regressed: ${beforeStars} → ${afterStars}`);
    }
    if (afterStars - beforeStars > MAX_STAR_GAIN_PER_WRITE) {
      violations.push(
        `total_stars jumped by ${afterStars - beforeStars} ` +
          `(> ${MAX_STAR_GAIN_PER_WRITE})`,
      );
    }

    const beforeSpent = before?.spent_stars ?? 0;
    const afterSpent = after.spent_stars ?? 0;
    if (afterSpent < beforeSpent) {
      violations.push(`spent_stars regressed: ${beforeSpent} → ${afterSpent}`);
    }

    const cat = after.category_progress ?? {};
    for (const [name, value] of Object.entries(cat)) {
      if (typeof value !== "number" || value < 0 || value > 1) {
        violations.push(`category_progress[${name}] = ${value} (must be 0..1)`);
      }
    }

    const scores = after.recent_scores ?? [];
    for (let i = 0; i < scores.length; i++) {
      const s = scores[i] as Record<string, unknown>;
      const score = typeof s.score === "number" ? s.score : 0;
      const total = typeof s.total === "number" ? s.total : 0;
      const starsEarned =
        typeof s.starsEarned === "number" ? s.starsEarned : 0;
      if (score > total) {
        violations.push(`recent_scores[${i}]: score ${score} > total ${total}`);
      }
      if (total > MAX_TOTAL_PER_GAME_SCORE) {
        violations.push(`recent_scores[${i}]: total ${total} unrealistic`);
      }
      if (starsEarned > MAX_STARS_PER_GAME_SCORE) {
        violations.push(
          `recent_scores[${i}]: starsEarned ${starsEarned} ` +
            `> cap ${MAX_STARS_PER_GAME_SCORE}`,
        );
      }
    }

    // ─── Rate limit ────────────────────────────────────
    const rateLimited = await checkRateLimit(ownerUid);
    if (rateLimited) {
      violations.push(
        `progress write rate limit exceeded ` +
          `(> ${MAX_PROGRESS_WRITES_PER_MINUTE}/min)`,
      );
    }

    if (violations.length === 0) return;

    // ─── Audit + revert ────────────────────────────────
    logger.warn("progress validation failed", {
      profileId,
      ownerUid,
      violations,
    });

    await db
      .collection("progress_audit")
      .doc(profileId)
      .collection("events")
      .add({
        profile_id: profileId,
        owner_uid: ownerUid,
        violations,
        attempted_at: admin.firestore.FieldValue.serverTimestamp(),
        before_snapshot: before ?? null,
        after_snapshot: after,
      });

    if (before) {
      // Restore to last-known-good state, plus the revert marker so we
      // don't re-trigger ourselves.
      await event.data!.after.ref.set(
        {
          ...before,
          _revertedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: false},
      );
    } else {
      // No prior state — the very first write to this doc was already
      // suspect. Delete instead of resurrecting an empty doc.
      await event.data!.after.ref.delete();
    }
  },
);

/**
 * Per-uid rolling counter. Returns true when the writer has exceeded the
 * per-minute cap. Uses a transaction so concurrent writes converge on a
 * single counter.
 */
async function checkRateLimit(uid: string): Promise<boolean> {
  const ref = db.collection("rate_limits").doc(uid);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.data() as
      | {window_start_ms?: number; count?: number}
      | undefined;

    const windowStart = data?.window_start_ms ?? 0;
    const count = data?.count ?? 0;
    const inSameWindow = now - windowStart < 60_000;

    const nextCount = inSameWindow ? count + 1 : 1;
    const nextWindowStart = inSameWindow ? windowStart : now;

    tx.set(
      ref,
      {window_start_ms: nextWindowStart, count: nextCount, kind: "progress"},
      {merge: true},
    );

    return nextCount > MAX_PROGRESS_WRITES_PER_MINUTE;
  });
}
