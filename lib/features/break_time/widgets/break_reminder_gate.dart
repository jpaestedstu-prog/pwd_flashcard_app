import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/break_reminder.dart';
import '../../../core/services/lock_announcer.dart';
import '../../../core/services/lock_presentation.dart';
import '../../../data/models/child_time_limit.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../l10n/app_localizations.dart';
import '../../../navigation/app_router.dart'
    show rootNavigatorKey, routerProvider;
import '../../../providers/active_time_provider.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/child_time_limit_provider.dart';
import '../../../providers/lock_announcement_provider.dart';
import '../../../providers/lock_state_provider.dart';
import '../break_time.dart';

/// Places where a break reminder waits instead of interrupting: a test the
/// study counts, a class session the teacher is running live, and games
/// played against or with someone else.
const List<String> breakReminderWaitsOn = [
  '/assessment/take',
  '/live-session',
  '/multiplayer',
  '/multiplayer-quiz',
  '/peer-collab',
];

/// App-root gate that reminds a learner to take a short break after the
/// stretch of learning their teacher or parent chose (Time limits → Break
/// reminders; [BreakReminderEvaluator] decides when).
///
/// A dialog with two answers — **Take a break** (the app's own break screen)
/// and **Keep learning** — so it can be answered by touch, the keyboard or
/// D-pad, Gaze Control, voice ("take a break") or a controller, and a screen
/// reader reads it. It is also announced through the same channels as the
/// "nearly time" warning (spoken, vibration), without the alarm chime: a
/// break is an invitation, not a hand-off.
///
/// Mounted inside `LockEnforcerGate` in `main.dart`, so it never shows over a
/// lock screen; it also stands aside while one is due.
class BreakReminderGate extends ConsumerStatefulWidget {
  const BreakReminderGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BreakReminderGate> createState() => _BreakReminderGateState();
}

class _BreakReminderGateState extends ConsumerState<BreakReminderGate>
    with WidgetsBindingObserver {
  /// Per learner: today's minute count when they last had a break.
  final Map<String, int> _anchor = {};
  bool _showing = false;
  DateTime? _wentAway;

  /// Kept alive by a `watch` in [build] (the provider is autoDispose).
  LockAnnouncer? _announcer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    breakTimeStarted.addListener(_reanchor);
  }

  @override
  void dispose() {
    breakTimeStarted.removeListener(_reanchor);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentAway ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _wentAway;
      _wentAway = null;
      // Time away from the app was a break of its own.
      if (away != null &&
          DateTime.now().difference(away) >=
              BreakReminderEvaluator.awayCountsAsBreak) {
        _reanchor();
      }
    }
  }

  UserProfile? _learner(UserProfile? profile) =>
      profile != null &&
          (profile.role == UserRole.student ||
              profile.role == UserRole.child) &&
          !profile.isGuestPlayer
      ? profile
      : null;

  /// The learner just had a break (or came back after one): count from now.
  void _reanchor() {
    final learner = _learner(ref.read(profileProvider));
    if (learner == null) return;
    _anchor[learner.id] = ref.read(activeTimeProvider(learner.id));
  }

  @override
  Widget build(BuildContext context) {
    final learner = _learner(ref.watch(profileProvider));
    if (learner != null) {
      _announcer = ref.watch(lockAnnouncerProvider);
      ref.listen<int>(
        activeTimeProvider(learner.id),
        (_, used) => _check(learner, used),
      );
    }
    return widget.child;
  }

  void _check(UserProfile learner, int used) {
    if (_showing) return;
    final id = learner.id;
    final anchor = BreakReminderEvaluator.keepAnchor(
      usedMinutes: used,
      anchorMinutes: _anchor[id] ?? used,
    );
    _anchor[id] = anchor;
    final limit = ref.read(childTimeLimitProvider(id)).valueOrNull;
    if (!BreakReminderEvaluator.isDue(
      limit: limit,
      usedMinutes: used,
      anchorMinutes: anchor,
    )) {
      return;
    }
    // A lock is due or showing: that is the message. Ask again later.
    if (ref.read(lockStateProvider(id)) != null) return;
    if (_waitHere()) return;
    _anchor[id] = used;
    _show(learner, limit!, used - anchor, used);
  }

  /// True on a screen where the reminder waits (see [breakReminderWaitsOn]).
  bool _waitHere() {
    try {
      final loc = ref
          .read(routerProvider)
          .routerDelegate
          .currentConfiguration
          .last
          .matchedLocation;
      return breakReminderWaitsOn.any(loc.startsWith);
    } catch (_) {
      return false;
    }
  }

  Future<void> _show(
    UserProfile learner,
    ChildTimeLimit limit,
    int minutesLearned,
    int used,
  ) async {
    final nav = rootNavigatorKey.currentContext;
    if (nav == null) return;
    final t = AppLocalizations.of(nav);
    if (t == null) return;
    final settings = ref.read(settingsProvider);
    final filipino = settings.locale == 'fil';
    final presentation = LockPresentation.forProfile(
      learner.disabilityType,
      settings,
    );
    final title = t.brkTitle;
    final body = presentation.simplifiedWording
        ? t.brkBodySimple(minutesLearned)
        : t.brkBody(minutesLearned);
    final left = BreakReminderEvaluator.minutesLeftToday(limit, used);
    final leftLine = left == null ? null : t.brkTimeLeft(left);

    _showing = true;
    unawaited(
      _announcer?.announce(
        presentation: presentation.warningVariant,
        message: '$title. $body',
        alarmEnabled: false,
        voiceEnabled: limit.voiceMessageEnabled,
        speakFilipino: filipino,
      ),
    );
    final takeBreak = await showDialog<bool>(
      context: nav,
      builder: (ctx) => BreakReminderDialog(
        title: title,
        body: body,
        timeLeft: leftLine,
        takeBreakLabel: t.brkTakeBreak,
        keepLearningLabel: t.brkKeepLearning,
      ),
    );
    _showing = false;
    unawaited(_announcer?.stop());
    if (takeBreak == true && nav.mounted) await showBreakTime(nav);
  }
}

/// The reminder itself. Public for its widget test.
class BreakReminderDialog extends StatelessWidget {
  const BreakReminderDialog({
    super.key,
    required this.title,
    required this.body,
    required this.timeLeft,
    required this.takeBreakLabel,
    required this.keepLearningLabel,
  });

  final String title;
  final String body;
  final String? timeLeft;
  final String takeBreakLabel;
  final String keepLearningLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      icon: const Icon(Icons.self_improvement_rounded, size: 40),
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (timeLeft != null) ...[
            const SizedBox(height: 12),
            Text(
              timeLeft!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ],
      ),
      actionsOverflowButtonSpacing: 8,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(keepLearningLabel),
        ),
        FilledButton.icon(
          autofocus: true,
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.spa_rounded),
          label: Text(takeBreakLabel),
        ),
      ],
    );
  }
}
