import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';
import '../services/assessment_cloud_service.dart';
import '../services/assessment_media_cache.dart';
import '../services/assessment_service.dart';
import '../services/sign_clip_readiness.dart';

/// Keeps a learner's assigned work current while the app is open. Renders
/// nothing.
///
/// [learnerAssignmentSyncProvider] is a `FutureProvider.family`, so on its
/// own it runs once per profile and then caches. Three things re-run it:
///
///  * **New work, live.** A Firestore listener on the learner's assignments
///    fires the moment a teacher presses Assign, so the test appears on a
///    tablet that never left the app. It only re-pulls when the set of
///    assignments — or this learner's feedback on one — differs from what
///    this device already holds, so an idle learner costs nothing.
///  * **A failed pull is retried.** The first pull on a slow classroom network
///    can time out; it used to stay failed until the learner left and reopened
///    the app, and assigned work stayed invisible until then. Retries back off
///    from [firstRetry] up to [maxRetry] and stop at the first success.
///  * **Coming back to the foreground** — the tablet was put down and picked
///    up again.
///
/// Mounted once, by the learner's navigation shell, so it survives tab
/// switches and scrolling. It only *invalidates*; the screens that show the
/// work keep watching the provider themselves and repaint when it lands.
class LearnerAssignmentSync extends ConsumerStatefulWidget {
  final String profileId;

  /// The live assignment ids. Defaults to Firestore; a test seam.
  final Stream<Set<String>> Function(String learnerId)? watchAssignments;

  /// The assignment ids this device already holds. Defaults to Hive; a seam.
  final Set<String>? Function(String learnerId)? knownAssignmentIds;

  /// Downloads the sign clips of waiting tests. Defaults to
  /// [SignClipReadiness.prefetch]; a test seam.
  final Future<void> Function(List<Assessment> tests)? prefetchClips;

  final Duration firstRetry;
  final Duration maxRetry;

  const LearnerAssignmentSync({
    super.key,
    required this.profileId,
    this.watchAssignments,
    this.knownAssignmentIds,
    this.prefetchClips,
    this.firstRetry = const Duration(seconds: 10),
    this.maxRetry = const Duration(minutes: 2),
  });

  @override
  ConsumerState<LearnerAssignmentSync> createState() =>
      _LearnerAssignmentSyncState();
}

class _LearnerAssignmentSyncState extends ConsumerState<LearnerAssignmentSync>
    with WidgetsBindingObserver {
  StreamSubscription<Set<String>>? _live;
  ProviderSubscription<AsyncValue<bool>>? _outcome;
  Timer? _retry;
  late Duration _nextRetry = widget.firstRetry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchOutcome();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LearnerAssignmentSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profileId != widget.profileId) {
      _retry?.cancel();
      _nextRetry = widget.firstRetry;
      _watchOutcome();
      _listen();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _live?.cancel();
    _outcome?.close();
    _retry?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (widget.profileId.isEmpty) return;
    _pull();
    // A listener that errored out (a dropped connection it could not ride
    // out) is restarted here rather than left dead for the session.
    if (_live == null) _listen();
  }

  void _pull() {
    if (!mounted) return;
    ref.invalidate(learnerAssignmentSyncProvider(widget.profileId));
  }

  void _listen() {
    _live?.cancel();
    _live = null;
    if (widget.profileId.isEmpty) return;
    final watch =
        widget.watchAssignments ??
        const AssessmentCloudService().watchLearnerAssignmentIds;
    _live = watch(widget.profileId).listen(
      (cloudIds) {
        final known = _known();
        final differs =
            known == null ||
            cloudIds.any((id) => !known.contains(id)) ||
            known.any((id) => !cloudIds.contains(id));
        if (differs) _pull();
      },
      onError: (Object _) => _live = null,
      onDone: () => _live = null,
      cancelOnError: true,
    );
  }

  Set<String>? _known() {
    final seam = widget.knownAssignmentIds;
    if (seam != null) return seam(widget.profileId);
    try {
      return {
        for (final a in AssessmentService.getAssignmentsForStudent(
          widget.profileId,
        ))
          AssessmentCloudService.revisionKey(a, widget.profileId),
      };
    } catch (_) {
      // Storage not ready — treat everything as new and pull.
      return null;
    }
  }

  /// Downloads the sign clips of the tests waiting for this learner while the
  /// tablet is online — the moment a pull has just worked — so the test can
  /// start in a classroom with no signal. Best-effort: the test screen checks
  /// again before the first question.
  void _prefetchClips() {
    try {
      final open = AssessmentService.getOpenableAssignments(widget.profileId);
      final waiting = open.map((w) => w.assessment).toList();
      if (waiting.isNotEmpty) {
        unawaited(
          (widget.prefetchClips ?? SignClipReadiness.prefetch)(
            waiting,
          ).catchError((Object _) {}),
        );
      }
      // The pictures, videos and signed instructions an educator attached,
      // and their feedback — the same "fetch while online" reasoning. Only
      // the slots this learner will be shown.
      final presentation = ref.read(assessmentMediaPresentationProvider);
      final media = [
        for (final w in open) ...[
          ...AssessmentMediaCache.valuesIn(w.assessment, presentation),
          ...AssessmentMediaCache.instructionValues(w.assignment, presentation),
        ],
        for (final f in AssessmentService.getFeedbackForStudent(
          widget.profileId,
        ))
          for (final kind in presentation.kindsFor(f.feedback.media))
            f.feedback.media.urlFor(kind),
      ];
      if (media.isNotEmpty) {
        unawaited(
          AssessmentMediaCache.prefetchValues(media).catchError((Object _) {}),
        );
      }
    } catch (_) {
      // Storage not ready — the test screen's own check still applies.
    }
  }

  void _scheduleRetry() {
    if (_retry?.isActive ?? false) return;
    final delay = _nextRetry;
    _retry = Timer(delay, _pull);
    final doubled = delay * 2;
    _nextRetry = doubled > widget.maxRetry ? widget.maxRetry : doubled;
  }

  /// Retries a failed pull, and resets the back-off after a good one.
  void _watchOutcome() {
    _outcome?.close();
    _outcome = null;
    if (widget.profileId.isEmpty) return;
    _outcome = ref.listenManual<AsyncValue<bool>>(
      learnerAssignmentSyncProvider(widget.profileId),
      (previous, next) {
        if (next.isLoading) return;
        final ok = next.valueOrNull ?? false;
        if (ok) {
          _retry?.cancel();
          _nextRetry = widget.firstRetry;
          _prefetchClips();
        } else {
          _scheduleRetry();
        }
      },
      // A pull that already failed before this widget started listening
      // still has to be retried.
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
