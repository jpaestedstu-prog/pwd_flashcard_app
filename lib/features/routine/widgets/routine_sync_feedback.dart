import 'package:flutter/material.dart';

import '../../../core/services/cloud_sync_outcome.dart';
import '../../../widgets/app_snack_bar.dart';

/// Tells an educator what actually happened to a routine write.
///
/// A routine is an instruction to a child on another device, so "saved" is
/// only true when it left this one. Three outcomes, three different things
/// the educator should do:
///
///  * [CloudSyncOutcome.synced] — nothing to say. Silence is the reward.
///  * [CloudSyncOutcome.localOnly] — it is waiting, and will go up by itself.
///    Worth a word, because the learner does not have it *yet*.
///  * [CloudSyncOutcome.notOwner] — it is never going anywhere. This profile
///    was restored onto another device and that one now owns syncing for it.
///    Saying "not yet" here would be a promise that is never kept, and an
///    educator would keep re-saving a routine their learner will never see.
///
/// Deliberately the same three-way split, and nearly the same words, as the
/// assessment assign screen — an educator who has met one has met both.
void reportRoutineSync(
  BuildContext context,
  CloudSyncOutcome outcome, {
  required bool filipino,

  /// What was written, in the reader's language — "routine", "change",
  /// "deletion". Lands mid-sentence, so keep it lowercase.
  required String subject,
}) {
  if (!context.mounted) return;
  switch (outcome) {
    case CloudSyncOutcome.synced:
      return;
    case CloudSyncOutcome.localOnly:
      AppSnackBar.warning(
        context,
        message: filipino
            ? 'Naka-save ang $subject sa device na ito — hindi pa naipapadala. '
                'Mapapadala ito kapag gumana na ang pag-sync.'
            : 'Saved on this device — not sent yet. It will upload when '
                'syncing is working.',
      );
    case CloudSyncOutcome.notOwner:
      AppSnackBar.warning(
        context,
        message: filipino
            ? 'Naka-save lang sa device na ito. Na-restore ang profile na ito '
                'sa ibang device, kaya iyon na ang nagpapadala. I-restore ito '
                'pabalik dito para makarating ang $subject sa bata.'
            : 'Saved on this device only. This profile was restored on another '
                'device, so that one now handles syncing. Restore it back here '
                'to send the $subject to your learner.',
      );
  }
}
