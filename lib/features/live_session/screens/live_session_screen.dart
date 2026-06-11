import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/haptic_service.dart';
import '../../../core/accessibility/tts_service.dart';
import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../models/live_session_models.dart';
import '../services/live_scoring.dart';
import '../services/live_session_service.dart';

/// Real-time live session. Learners (Student / Child) get an accessible
/// receiver that renders the educator's pushed activities, awards stars for
/// correct answers per the session's scoring rules, and offers a big
/// Raise-Hand button. Educators are pointed to the TV Cast screen, which is
/// where they host and drive the session.
class LiveSessionScreen extends ConsumerWidget {
  const LiveSessionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    if (profile == null) {
      return const Scaffold(body: Center(child: Text('No profile selected')));
    }
    final isEducator = profile.role.isEducator;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEducator ? 'Live Session' : 'Join the Class'),
      ),
      body: SafeArea(
        child: isEducator
            ? const _EducatorPointer()
            : _LearnerView(profile: profile),
      ),
    );
  }
}

// ─── Educator pointer ──────────────────────────────────

class _EducatorPointer extends StatelessWidget {
  const _EducatorPointer();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cast_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Host live games & quizzes from TV Cast',
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open TV Cast, start casting, then choose "Live Activity" to '
              'build questions, set star scoring, and see raised hands and the '
              'scoreboard on the TV.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push('/tv-cast'),
              icon: const Icon(Icons.tv_rounded),
              label: const Text('Open TV Cast'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Learner view ──────────────────────────────────────

class _LearnerView extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _LearnerView({required this.profile});

  @override
  ConsumerState<_LearnerView> createState() => _LearnerViewState();
}

class _LearnerViewState extends ConsumerState<_LearnerView> {
  static const _service = LiveSessionService();

  String? _sessionKey;

  StreamSubscription<LiveSession?>? _sessionSub;
  StreamSubscription<List<LiveResponse>>? _responsesSub;
  StreamSubscription<List<RaisedHand>>? _handsSub;
  Timer? _firstCorrectTimer;

  LiveSession? _session;
  String? _currentActivityId;
  List<LiveResponse> _latestActivityResponses = const [];

  // Answer state for the on-screen activity.
  String? _respondedActivityId;
  Object? _myAnswer;
  bool _lastCorrect = false;
  int _lastAward = 0;

  // Star-cap accounting + first-correct idempotency.
  int _sessionEarned = 0;
  final Set<String> _firstCorrectApplied = {};

  bool _handRaised = false;

  @override
  void initState() {
    super.initState();
    _sessionKey = widget.profile.classroomId ?? widget.profile.homeGroupId;
    if (_sessionKey != null && FirebaseService.isConfigured) {
      _subscribe(_sessionKey!);
    }
  }

  void _subscribe(String key) {
    _sessionSub = _service.watchSession(key).listen(_onSession);
    _handsSub = _service.watchHands(key).listen((hands) {
      final raised = hands.any((h) => h.profileId == widget.profile.id);
      if (raised != _handRaised && mounted) {
        setState(() => _handRaised = raised);
      }
    });
  }

  void _onSession(LiveSession? session) {
    if (!mounted) return;
    final newActivityId = session?.currentActivity?.id;
    if (newActivityId != _currentActivityId) {
      // The educator pushed a new question (or cleared it) — reset answer
      // state and re-arm the per-activity responses subscription.
      _currentActivityId = newActivityId;
      _respondedActivityId = null;
      _myAnswer = null;
      _lastCorrect = false;
      _lastAward = 0;
      _firstCorrectTimer?.cancel();
      _responsesSub?.cancel();
      _latestActivityResponses = const [];
      final activity = session?.currentActivity;
      if (activity != null && _sessionKey != null) {
        _responsesSub = _service
            .watchResponses(sessionKey: _sessionKey!, activityId: activity.id)
            .listen((r) => _latestActivityResponses = r);
        _maybeReadAloud(activity);
      }
    }
    setState(() => _session = session);
  }

  void _maybeReadAloud(LiveActivity activity) {
    // Only read prompts that don't reveal the answer (MC question / TF
    // statement). Picture / FSL prompts are the answer, so we stay silent.
    final settings = ref.read(settingsProvider);
    if (!settings.ttsEnabled) return;
    final text = activity.prompt;
    if (text.isEmpty) return;
    unawaited(ref.read(ttsServiceProvider).speak(text));
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _responsesSub?.cancel();
    _handsSub?.cancel();
    _firstCorrectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionKey == null) {
      return _Notice(
        icon: Icons.group_add_rounded,
        title: 'Join a class first',
        message: widget.profile.role == UserRole.child
            ? 'Ask your parent for the home-group code, then join from Settings '
                'to take part in live activities.'
            : 'You are not in a classroom yet. Tap "Join a class" to take part '
                'in live activities.',
      );
    }
    if (!FirebaseService.isConfigured) {
      return const _Notice(
        icon: Icons.cloud_off_rounded,
        title: 'Connect to the internet',
        message: 'Live activities need a connection so you can join your class '
            'in real time. Connect to Wi-Fi or mobile data and reopen this '
            'screen.',
      );
    }

    final session = _session;
    if (session == null || session.status == LiveSessionStatus.ended) {
      return _WaitingView(
        message: 'No live activity yet. Your teacher will start one soon.',
        handRaised: _handRaised,
        onToggleHand: _toggleHand,
      );
    }
    final activity = session.currentActivity;
    if (activity == null) {
      return _WaitingView(
        message: 'Get ready! Waiting for the next question…',
        handRaised: _handRaised,
        onToggleHand: _toggleHand,
      );
    }
    return _ActivityView(
      profile: widget.profile,
      activity: activity,
      myAnswer: _myAnswer,
      responded: _respondedActivityId == activity.id,
      lastCorrect: _lastCorrect,
      lastAward: _lastAward,
      handRaised: _handRaised,
      onAnswer: (ans) => _answer(activity, ans),
      onToggleHand: _toggleHand,
    );
  }

  /// Screen-reader live-region announcement. Wraps the (deprecated-but-still
  /// functional) SemanticsService.announce; its replacement isn't available on
  /// the bundled Flutter SDK yet.
  void _announce(String message) {
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }

  // ─── Raise hand ─────────────────────────────────────

  Future<void> _toggleHand() async {
    final key = _sessionKey;
    if (key == null) return;
    final raising = !_handRaised;
    setState(() => _handRaised = raising);
    unawaited(ref.read(hapticServiceProvider).selectionClick());
    _announce(
      raising ? 'Hand raised. Your teacher can see your name.' : 'Hand lowered.',
    );
    try {
      if (raising) {
        await _service.raiseHand(
          sessionKey: key,
          profileId: widget.profile.id,
          profileName: widget.profile.name,
        );
      } else {
        await _service.lowerHand(sessionKey: key, profileId: widget.profile.id);
      }
    } catch (_) {
      // Revert the optimistic toggle on failure.
      if (mounted) setState(() => _handRaised = !raising);
    }
  }

  // ─── Answer + scoring ───────────────────────────────

  Future<void> _answer(LiveActivity activity, Object? answer) async {
    if (_respondedActivityId == activity.id) return;
    final key = _sessionKey;
    if (key == null) return;

    final isCorrect = activity.isCorrectAnswer(answer);
    final elapsedMs = DateTime.now()
        .difference(activity.pushedAt)
        .inMilliseconds
        .clamp(0, 1 << 31);
    final rules = _session?.scoring ?? const LiveScoringRules();

    final award = LiveScoring.computeStars(
      rules: rules,
      isCorrect: isCorrect,
      elapsedMs: elapsedMs,
      alreadyEarnedThisSession: _sessionEarned,
      activityPoints: activity.points,
    );
    if (award > 0) {
      ref.read(progressProvider.notifier).addStars(award);
      _sessionEarned += award;
    }

    setState(() {
      _respondedActivityId = activity.id;
      _myAnswer = answer;
      _lastCorrect = isCorrect;
      _lastAward = award;
    });

    final haptic = ref.read(hapticServiceProvider);
    if (isCorrect) {
      unawaited(haptic.success());
      _announce(
        award > 0 ? 'Correct! You earned $award stars.' : 'Correct!',
      );
    } else {
      unawaited(haptic.error());
      _announce('Good try. Wait for the next question.');
    }

    unawaited(_service.submitResponse(
      sessionKey: key,
      activityId: activity.id,
      profileId: widget.profile.id,
      profileName: widget.profile.name,
      isCorrect: isCorrect,
      answer: answer,
      elapsedMs: elapsedMs,
      starsAwarded: award,
    ));

    // First-correct bonus is a global decision — resolve it after a short
    // settle delay so every device sees the same response set and exactly one
    // (the earliest correct) awards itself the bonus.
    if (isCorrect &&
        rules.firstCorrectEnabled &&
        !_firstCorrectApplied.contains(activity.id)) {
      _firstCorrectTimer?.cancel();
      _firstCorrectTimer = Timer(
        const Duration(milliseconds: 2500),
        () => _resolveFirstCorrect(activity, rules),
      );
    }
  }

  Future<void> _resolveFirstCorrect(
    LiveActivity activity,
    LiveScoringRules rules,
  ) async {
    if (!mounted) return;
    if (_currentActivityId != activity.id) return; // moved on
    if (_firstCorrectApplied.contains(activity.id)) return;

    final corrects = _latestActivityResponses.where((r) => r.isCorrect).toList()
      ..sort((a, b) {
        final t = a.submittedAt.compareTo(b.submittedAt);
        return t != 0 ? t : a.profileId.compareTo(b.profileId);
      });
    if (corrects.isEmpty) return;
    if (corrects.first.profileId != widget.profile.id) return;

    var bonus = rules.firstCorrectBonus;
    if (rules.hasCap) {
      final remaining = rules.sessionCap - _sessionEarned;
      bonus = remaining <= 0 ? 0 : (bonus > remaining ? remaining : bonus);
    }
    if (bonus <= 0) return;

    _firstCorrectApplied.add(activity.id);
    ref.read(progressProvider.notifier).addStars(bonus);
    _sessionEarned += bonus;
    unawaited(ref.read(hapticServiceProvider).celebration());
    _announce('First correct answer! Bonus $bonus stars.');
    if (mounted) setState(() => _lastAward += bonus);

    // Keep the educator scoreboard accurate.
    unawaited(_service.updateResponseStars(
      sessionKey: _sessionKey!,
      activityId: activity.id,
      profileId: widget.profile.id,
      starsAwarded: _lastAward,
    ));
  }
}

// ─── Waiting view (with raise-hand) ────────────────────

class _WaitingView extends StatelessWidget {
  final String message;
  final bool handRaised;
  final VoidCallback onToggleHand;

  const _WaitingView({
    required this.message,
    required this.handRaised,
    required this.onToggleHand,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎒', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium
                        .copyWith(color: hc.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
        _RaiseHandBar(handRaised: handRaised, onToggle: onToggleHand),
      ],
    );
  }
}

// ─── Activity view ─────────────────────────────────────

class _ActivityView extends ConsumerWidget {
  final UserProfile profile;
  final LiveActivity activity;
  final Object? myAnswer;
  final bool responded;
  final bool lastCorrect;
  final int lastAward;
  final bool handRaised;
  final ValueChanged<Object?> onAnswer;
  final VoidCallback onToggleHand;

  const _ActivityView({
    required this.profile,
    required this.activity,
    required this.myAnswer,
    required this.responded,
    required this.lastCorrect,
    required this.lastAward,
    required this.handRaised,
    required this.onAnswer,
    required this.onToggleHand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activity.questionNumber != null &&
                    activity.totalQuestions != null)
                  _QNumberPill(
                    number: activity.questionNumber!,
                    total: activity.totalQuestions!,
                  ),
                const SizedBox(height: 8),
                _Prompt(activity: activity, ref: ref),
                const SizedBox(height: 20),
                ..._answerControls(context),
                if (responded) ...[
                  const SizedBox(height: 16),
                  _ResultBanner(correct: lastCorrect, award: lastAward),
                ],
              ],
            ),
          ),
        ),
        _RaiseHandBar(handRaised: handRaised, onToggle: onToggleHand),
      ],
    );
  }

  List<Widget> _answerControls(BuildContext context) {
    switch (activity.type) {
      case LiveActivityType.trueFalse:
        return [
          _AnswerButton(
            label: 'True',
            icon: Icons.check_circle_outline_rounded,
            selected: myAnswer == true,
            state: _stateFor(true),
            accent: _kOptionAccents[0],
            onTap: responded ? null : () => onAnswer(true),
          ),
          const SizedBox(height: 12),
          _AnswerButton(
            label: 'False',
            icon: Icons.cancel_outlined,
            selected: myAnswer == false,
            state: _stateFor(false),
            accent: _kOptionAccents[1],
            onTap: responded ? null : () => onAnswer(false),
          ),
        ];
      case LiveActivityType.fslSign when activity.selfReport:
        return [
          _AnswerButton(
            label: 'I got it! ✋',
            icon: Icons.thumb_up_alt_outlined,
            selected: myAnswer == true,
            state: _stateFor(true),
            accent: _kOptionAccents[3],
            onTap: responded ? null : () => onAnswer(true),
          ),
          const SizedBox(height: 12),
          _AnswerButton(
            label: 'Not yet',
            icon: Icons.refresh_rounded,
            selected: myAnswer == false,
            state: _SelectState.neutral,
            onTap: responded ? null : () => onAnswer(false),
          ),
        ];
      case LiveActivityType.flashcard:
        return [
          _AnswerButton(
            label: 'Got it!',
            icon: Icons.thumb_up_alt_outlined,
            selected: myAnswer == true,
            state: _SelectState.neutral,
            accent: _kOptionAccents[0],
            onTap: responded ? null : () => onAnswer(true),
          ),
        ];
      case LiveActivityType.multipleChoice:
      case LiveActivityType.pictureChoice:
      case LiveActivityType.fslSign:
        final options = activity.options;
        return [
          for (var i = 0; i < options.length; i++) ...[
            _AnswerButton(
              label: options[i],
              icon: Icons.radio_button_unchecked_rounded,
              selected: myAnswer == i,
              state: _stateFor(i),
              accent: _kOptionAccents[i % _kOptionAccents.length],
              onTap: responded ? null : () => onAnswer(i),
            ),
            if (i != options.length - 1) const SizedBox(height: 12),
          ],
        ];
    }
  }

  /// Visual state for an option once the learner has responded: shows the
  /// correct answer (green check) and a wrong pick (red), via icon + colour +
  /// text — never colour alone.
  _SelectState _stateFor(Object value) {
    if (!responded) return _SelectState.neutral;
    final isThisCorrect = activity.isCorrectAnswer(value);
    if (isThisCorrect) return _SelectState.correct;
    if (myAnswer == value) return _SelectState.wrong;
    return _SelectState.neutral;
  }
}

enum _SelectState { neutral, correct, wrong }

class _QNumberPill extends StatelessWidget {
  final int number;
  final int total;
  const _QNumberPill({required this.number, required this.total});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Question $number of $total',
          style: AppTypography.labelMedium.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  final LiveActivity activity;
  final WidgetRef ref;
  const _Prompt({required this.activity, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final type = activity.type;
    if (type == LiveActivityType.pictureChoice ||
        type == LiveActivityType.fslSign ||
        type == LiveActivityType.flashcard) {
      final card = _lookupCard(activity.flashcardId);
      final emoji = card != null ? FlashcardEmojis.forId(card.id) : '❓';
      final isFsl = type == LiveActivityType.fslSign;
      return Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 88)),
          const SizedBox(height: 8),
          if (isFsl)
            Text(
              'Watch the sign on the TV, then choose the matching word.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            )
          else if (type == LiveActivityType.flashcard && card != null)
            Text(
              '${card.wordEnglish}\n${card.wordFilipino}',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            )
          else
            Text(
              'Which word matches the picture?',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            ),
        ],
      );
    }
    return Semantics(
      header: true,
      child: Text(
        activity.prompt,
        textAlign: TextAlign.center,
        style: AppTypography.headlineSmall.copyWith(
          fontWeight: FontWeight.w800,
          color: hc.textPrimary,
        ),
      ),
    );
  }

  Flashcard? _lookupCard(String? id) {
    if (id == null) return null;
    final all = ref.read(allFlashcardsProvider);
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Kid-friendly accent colours cycled across answer options. Deliberately
/// avoids green/red, which are reserved for the correct/incorrect states so
/// colour never carries meaning on its own.
const List<Color> _kOptionAccents = [
  Color(0xFF42A5F5), // blue
  Color(0xFFFFA726), // orange
  Color(0xFF7E57C2), // purple
  Color(0xFF26C6DA), // teal
];

class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final _SelectState state;
  final Color accent;
  final VoidCallback? onTap;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.state,
    required this.onTap,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    Color border;
    Color bg;
    Color fg;
    IconData leadingIcon = icon;
    switch (state) {
      case _SelectState.correct:
        border = const Color(0xFF2E7D32);
        bg = const Color(0xFF2E7D32).withValues(alpha: 0.12);
        fg = const Color(0xFF1B5E20);
        leadingIcon = Icons.check_circle_rounded;
        break;
      case _SelectState.wrong:
        border = const Color(0xFFC62828);
        bg = const Color(0xFFC62828).withValues(alpha: 0.10);
        fg = const Color(0xFFB71C1C);
        leadingIcon = Icons.cancel_rounded;
        break;
      case _SelectState.neutral:
        border = selected ? accent : accent.withValues(alpha: 0.4);
        bg = selected
            ? accent.withValues(alpha: 0.12)
            : accent.withValues(alpha: 0.06);
        fg = hc.textPrimary;
        leadingIcon = icon;
        break;
    }

    final semanticSuffix = switch (state) {
      _SelectState.correct => ', correct answer',
      _SelectState.wrong => ', your answer, incorrect',
      _SelectState.neutral => '',
    };

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$label$semanticSuffix',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: 2),
            ),
            child: Row(
              children: [
                Icon(leadingIcon, color: fg),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  final bool correct;
  final int award;
  const _ResultBanner({required this.correct, required this.award});

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.celebration_rounded : Icons.favorite_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              correct
                  ? (award > 0
                      ? 'Correct! You earned $award ⭐'
                      : 'Correct! 🎉')
                  : 'Good try! Keep going 💪',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Raise-hand bar ────────────────────────────────────

class _RaiseHandBar extends StatelessWidget {
  final bool handRaised;
  final VoidCallback onToggle;
  const _RaiseHandBar({required this.handRaised, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Semantics(
          button: true,
          toggled: handRaised,
          label: handRaised
              ? 'Lower your hand'
              : 'Raise your hand to ask your teacher for help',
          child: SizedBox(
            height: 64,
            child: FilledButton.icon(
              onPressed: onToggle,
              style: FilledButton.styleFrom(
                backgroundColor:
                    handRaised ? const Color(0xFFFFB300) : AppColors.primary,
                foregroundColor: handRaised ? Colors.black : Colors.white,
                textStyle: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: Text(
                handRaised ? '✋' : '🙋',
                style: const TextStyle(fontSize: 24),
              ),
              label: Text(handRaised ? 'Lower hand' : 'Raise hand'),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared notice ─────────────────────────────────────

class _Notice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _Notice({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: hc.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
