import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/accessibility/haptic_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/enums.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/experiment_provider.dart';
import '../../experiment/models/experiment_models.dart';
import '../models/assessment_media.dart';
import '../models/assessment_media_presentation.dart';
import '../models/assessment_models.dart';
import '../providers/assessment_provider.dart';
import '../../../core/services/shared_media_service.dart';
import '../../../core/utils/accessible_sizing.dart';
import '../../../core/widgets/media_capture_screen.dart';
import '../../../core/accessibility/learner_support.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../models/question_prompt.dart';
import '../services/assessment_media_cache.dart';
import '../services/assessment_media_store.dart';
import '../services/assessment_service.dart';
import '../services/sign_clip_readiness.dart';
import '../widgets/assessment_media_panel.dart';
import '../widgets/assessment_sign_clip.dart';

/// Screen that runs an assessment quiz — supports multiple choice,
/// true/false, and fill-in-the-blank question formats. Fully accessible
/// with Semantics, TTS-ready, and high-contrast support.
class AssessmentTestScreen extends ConsumerStatefulWidget {
  final Assessment assessment;

  /// Source of "now" for every time this screen measures — question response
  /// times, total duration, and the countdown on a timed assessment.
  ///
  /// A seam, not a feature: the countdown is derived from the wall clock so a
  /// tablet that slept cannot hand the learner extra minutes, but `DateTime.now`
  /// is exactly what a widget test's fake-async cannot advance. Production
  /// leaves this alone and gets the real clock.
  final DateTime Function()? clock;

  /// Builds the sign clip for a "watch the sign" item. Injected so a widget
  /// test can stand in a marker for the video plugin, which no test binding
  /// provides. Null in production, which uses [AssessmentSignClip].
  final SignClipBuilder? signClipBuilder;

  /// Makes the sign clips available offline and returns the card ids that
  /// are still missing. Defaults to [SignClipReadiness.prepare]; a test seam,
  /// since no test binding can download a video.
  final Future<List<String>> Function(List<String> cardIds)? prepareSignClips;

  /// Makes the pictures, videos and sounds an educator attached available on
  /// this tablet and returns the ones still missing. Defaults to
  /// [AssessmentMediaCache.prepare]; a test seam.
  final Future<List<String>> Function(List<String> values)? prepareMedia;

  /// Records a video answer and returns the value to store (`file://…`),
  /// or null if the learner closed the camera. A seam: no test binding has
  /// the camera plugin. Null in the app, which opens [MediaCaptureScreen].
  final Future<String?> Function(BuildContext context, String prompt)?
  recordAnswer;

  const AssessmentTestScreen({
    super.key,
    required this.assessment,
    this.clock,
    this.signClipBuilder,
    this.prepareSignClips,
    this.prepareMedia,
    this.recordAnswer,
  });

  @override
  ConsumerState<AssessmentTestScreen> createState() =>
      _AssessmentTestScreenState();
}

class _AssessmentTestScreenState extends ConsumerState<AssessmentTestScreen> {
  late List<AssessmentQuestion> _questions;
  int _currentIndex = 0;
  final List<QuestionAnswer> _answers = [];
  String? _selectedAnswer;
  bool _answered = false;
  bool _isCorrect = false;
  final _fillController = TextEditingController();

  /// The question area's scroll position. A sign item's clip is tall enough
  /// that, on the tablet, answering left the "Correct! / The correct answer
  /// is…" feedback — and the fourth choice — below the fold, with nothing to
  /// bring it into view. And because the same scroll view carries on from
  /// question to question, a learner who scrolled down started the next one
  /// scrolled down too.
  final _scroll = ScrollController();
  late DateTime _questionStartTime;
  late DateTime _assessmentStartTime;
  bool _showHint = false;

  /// Countdown for assessments the educator gave a time limit. Null when the
  /// assessment is untimed, which is the common case — the field was written
  /// by the builder and the quiz generator but never read by anything, so
  /// "10 min" on a teacher's assessment meant nothing at all until now.
  Timer? _timer;
  Duration? _remaining;

  /// The limit this learner actually gets, which is the assessment's own limit
  /// plus their extra-time accommodation if they have one. Resolved once in
  /// [initState]: reading it per tick would let a mid-test profile switch move
  /// the finish line.
  int? _limitMinutes;

  /// Guards the single submission. The timer expiring and the learner
  /// answering the last question can otherwise both fire [_finishAssessment],
  /// saving the result twice and pushing two summary screens.
  bool _finished = false;

  /// The sign clips this test needs, and whether they are all on the tablet.
  /// A test with sign items does not start — no question, no clock — until
  /// every clip can play: a sign item met with no video was answered blind,
  /// and the study would have counted that as not knowing the sign.
  late final List<String> _signCardIds;
  bool _clipsReady = true;
  bool _clipsMissing = false;

  /// How this learner meets attached media, resolved once like the time
  /// limit — a mid-test profile switch must not re-order a question.
  late final AssessmentMediaPresentation _mediaPresentation;

  /// The attached media this learner will be shown, and whether some of it
  /// could not be made ready. Unlike a sign item, attached media supports the
  /// question rather than *being* it, so a learner may start without it —
  /// but only by choosing to, never because the clock began while a video
  /// was still downloading.
  late final List<String> _mediaValues;
  bool _mediaMissing = false;

  /// Video answers being shared, by question, and what each came back as.
  /// A learner's signed answer is shared in the background while they carry
  /// on; the test waits for them only at the very end.
  final Map<String, Future<void>> _pendingShares = {};
  final Map<String, String> _sharedAnswers = {};

  /// True while the last video answers finish uploading.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Accommodations are applied to the *presentation*, not to the stored
    // instrument: every learner in the class sits the same items, and the
    // ones who need a shorter choice list get one.
    final supports = ref.read(profileProvider)?.supports ?? const {};
    _questions = supports.contains(LearnerSupportOption.fewerChoices)
        ? AssessmentService.limitChoices(widget.assessment.questions, 2)
        : widget.assessment.questions;
    _limitMinutes = LearnerSupportCatalog.timeLimitMinutes(
      widget.assessment.timeLimitMinutes,
      supports,
    );
    _signCardIds = SignClipReadiness.cardIdsIn(widget.assessment);
    _mediaPresentation = AssessmentMediaPresentation.forProfile(
      ref.read(profileProvider),
    );
    _mediaValues = AssessmentMediaCache.valuesIn(
      widget.assessment,
      _mediaPresentation,
    );
    if (_signCardIds.isEmpty && _mediaValues.isEmpty) {
      _begin();
    } else {
      _clipsReady = false;
      _prepareClips();
    }
  }

  /// Starts the clocks: response times, duration and any time limit all count
  /// from the first question the learner can actually answer.
  void _begin() {
    _assessmentStartTime = _now();
    _questionStartTime = _now();
    final limit = _limitMinutes;
    if (limit != null && limit > 0) {
      _remaining = Duration(minutes: limit);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  Future<void> _prepareClips() async {
    if (_clipsMissing || _mediaMissing) {
      setState(() {
        _clipsMissing = false;
        _mediaMissing = false;
      });
    }
    if (_signCardIds.isNotEmpty) {
      final prepare = widget.prepareSignClips ?? SignClipReadiness.prepare;
      List<String> missing;
      try {
        missing = await prepare(_signCardIds);
      } catch (_) {
        missing = _signCardIds;
      }
      if (!mounted) return;
      if (missing.isNotEmpty) {
        setState(() => _clipsMissing = true);
        return;
      }
    }
    if (_mediaValues.isNotEmpty) {
      final prepare = widget.prepareMedia ?? AssessmentMediaCache.prepare;
      List<String> missing;
      try {
        missing = await prepare(_mediaValues);
      } catch (_) {
        missing = _mediaValues;
      }
      if (!mounted) return;
      if (missing.isNotEmpty) {
        setState(() => _mediaMissing = true);
        return;
      }
    }
    _startNow();
  }

  void _startNow() {
    setState(() => _clipsReady = true);
    _begin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    _fillController.dispose();
    super.dispose();
  }

  /// Recomputes the remaining time from the wall clock rather than counting
  /// ticks, so a tablet that slept or throttled timers does not hand back
  /// extra minutes. Runs out of time → submit what has been answered.
  void _tick() {
    if (!mounted || _finished) return;
    final limit = _limitMinutes;
    if (limit == null) return;
    final left =
        Duration(minutes: limit) -
        _now().difference(_assessmentStartTime);
    if (left <= Duration.zero) {
      _timer?.cancel();
      setState(() => _remaining = Duration.zero);
      _finishAssessment();
      return;
    }
    setState(() => _remaining = left);
  }

  /// Whether this learner asked for Reduced Motion. Read defensively: the
  /// settings live in a storage box that widget tests often leave closed, and
  /// a scroll nicety must never be the thing that fails a sitting.
  bool _reducedMotion() {
    try {
      return ref.read(settingsProvider).reducedMotion ||
          MediaQuery.of(context).disableAnimations;
    } catch (_) {
      return false;
    }
  }

  /// The screen's clock: the injected one in tests, the real one in the app.
  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// This screen's strings. English without a delegate, which is how widget
  /// tests build it.
  AppLocalizations get _t =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();

  AssessmentQuestion get _currentQuestion => _questions[_currentIndex];
  bool get _isLastQuestion => _currentIndex >= _questions.length - 1;
  /// Guarded against an empty question list.
  ///
  /// Dividing by zero gives NaN, and the progress label rounds it —
  /// `(NaN).round()` throws "Unsupported operation: Infinity or NaN toInt",
  /// which took the whole screen down rather than showing an empty assessment.
  /// The builder will not save a question-less assessment, but one can still
  /// arrive from a Firestore sync, and a malformed record should not crash.
  double get _progress =>
      _questions.isEmpty ? 0 : (_currentIndex + 1) / _questions.length;

  void _selectAnswer(String answer) {
    if (_answered) return;
    final haptic = ref.read(hapticServiceProvider);
    final responseTime =
        _now().difference(_questionStartTime).inMilliseconds;
    final correct =
        answer.trim().toLowerCase() == _currentQuestion.correctAnswer.trim().toLowerCase();

    setState(() {
      _selectedAnswer = answer;
      _answered = true;
      _isCorrect = correct;
    });

    if (correct) {
      haptic.celebration();
    } else {
      haptic.error();
    }

    // Bring the feedback into view once it has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (_reducedMotion()) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(
          end,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _answers.add(QuestionAnswer(
      questionId: _currentQuestion.id,
      givenAnswer: answer,
      isCorrect: correct,
      responseTimeMs: responseTime,
    ));
  }

  /// Records (or re-records) the answer to a video question. A second take
  /// replaces the first — one answer per question, as every count assumes.
  Future<void> _recordVideoAnswer() async {
    final q = _currentQuestion;
    final prompt = QuestionPrompt.localize(
      q.questionText,
      AppLocalizations.of(context),
    );
    final value = await (widget.recordAnswer ?? _defaultRecordAnswer)(
      context,
      prompt,
    );
    if (value == null || !mounted || _finished) return;
    final answer = QuestionAnswer(
      questionId: q.id,
      givenAnswer: value,
      isCorrect: false,
      responseTimeMs: _now().difference(_questionStartTime).inMilliseconds,
      needsReview: true,
    );
    final previous = _answers.indexWhere((a) => a.questionId == q.id);
    if (previous == -1) {
      _answers.add(answer);
    } else {
      final old = _answers[previous].givenAnswer;
      _answers[previous] = answer;
      unawaited(
        const AssessmentMediaStore().discard([
          old,
          ?_sharedAnswers.remove(q.id),
        ]),
      );
    }
    _startSharing(q.id, value);
    ref.read(hapticServiceProvider).lightTap();
    setState(() {
      _answered = true;
      _isCorrect = false;
      _selectedAnswer = value;
    });
  }

  Future<String?> _defaultRecordAnswer(
    BuildContext context,
    String prompt,
  ) async {
    final path = await captureMedia(
      context,
      mode: CaptureMode.video,
      title: _t.assessVideoAnswerRecord,
      prompt: prompt,
    );
    if (path == null) return null;
    final learner = ref.read(profileProvider)?.id ?? 'learner';
    final adopted = await const AssessmentMediaStore().adoptCaptured(
      capturedPath: path,
      ownerKey: 'ans_${widget.assessment.id}_${_currentQuestion.id}_$learner',
      kind: AssessmentMediaKind.video,
    );
    return adopted.status == MediaPickStatus.added ? adopted.value : null;
  }

  void _startSharing(String questionId, String value) {
    final learner = ref.read(profileProvider)?.id ?? '';
    _pendingShares[questionId] = const AssessmentMediaStore()
        .share(value, ownerProfileId: learner)
        .then((r) async {
          if (r.status != SharedUploadStatus.shared) return;
          final current = _answers
              .where((a) => a.questionId == questionId)
              .map((a) => a.givenAnswer)
              .firstOrNull;
          if (current == value) {
            _sharedAnswers[questionId] = r.value;
          } else {
            // A newer take replaced this one while it uploaded.
            await const AssessmentMediaStore().discard([r.value]);
          }
        });
  }

  /// The words that tell this learner how to answer on camera.
  String _videoAnswerHint() {
    final profile = ref.read(profileProvider);
    if (profile?.disabilityType == DisabilityType.visual) {
      return _t.assessVideoAnswerHintSay;
    }
    if (profile?.disabilityType == DisabilityType.hearing &&
        _mediaPresentation.showSign) {
      return _t.assessVideoAnswerHintSign;
    }
    return _t.assessVideoAnswerHintEither;
  }

  void _submitFillIn() {
    final text = _fillController.text.trim();
    if (text.isEmpty) return;
    _selectAnswer(text);
  }

  void _nextQuestion() {
    if (_isLastQuestion) {
      _finishAssessment();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedAnswer = null;
      _answered = false;
      _isCorrect = false;
      _showHint = false;
      _fillController.clear();
      _questionStartTime = _now();
    });
    // Every question starts at its own top, whatever the last one scrolled to.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _finishAssessment() async {
    if (_finished) return;
    final profile = ref.read(profileProvider);
    if (profile == null) return;
    _finished = true;
    _timer?.cancel();
    // The clock stops here, not after the uploads below.
    final durationSeconds =
        _now().difference(_assessmentStartTime).inSeconds;

    // Video answers still uploading get a moment to finish, so the result
    // carries their shared value and the teacher's tablet can play them.
    // One that cannot (offline) is kept on this tablet and shared on the
    // next sync — see AssessmentMediaPublisher.publishLearnerAnswers.
    if (_pendingShares.isNotEmpty) {
      setState(() => _sending = true);
      try {
        await Future.wait(
          _pendingShares.values,
        ).timeout(const Duration(seconds: 90));
      } catch (_) {
        // Whatever finished is used; the rest are shared later.
      }
      for (var i = 0; i < _answers.length; i++) {
        final shared = _sharedAnswers[_answers[i].questionId];
        if (_answers[i].needsReview && shared != null) {
          _answers[i] = _answers[i].withGivenAnswer(shared);
        }
      }
    }

    // Only the questions the app marks count here. A video answer waits for
    // a person, so it is neither right nor wrong yet — and every existing
    // percentage (reports, the class report, the study's exports) stays what
    // it would have been.
    final answerOf = {for (final a in _answers) a.questionId: a};
    final marked = _questions.where((q) => !q.format.needsReview).toList();
    final score = marked.where((q) => answerOf[q.id]?.isCorrect ?? false).length;

    // Calculate per-category scores
    final categoryScores = <String, double>{};
    final categoryCorrect = <String, int>{};
    final categoryTotal = <String, int>{};
    for (final q in marked) {
      final cat = q.category;
      if (cat == null) continue;
      final key = cat.label;
      categoryTotal[key] = (categoryTotal[key] ?? 0) + 1;
      if (answerOf[q.id]?.isCorrect ?? false) {
        categoryCorrect[key] = (categoryCorrect[key] ?? 0) + 1;
      }
    }
    for (final key in categoryTotal.keys) {
      categoryScores[key] = (categoryCorrect[key] ?? 0) / categoryTotal[key]!;
    }

    final result = AssessmentResult(
      id: const Uuid().v4(),
      assessmentId: widget.assessment.id,
      profileId: profile.id,
      type: widget.assessment.type,
      score: score,
      totalQuestions: marked.length,
      answers: _answers,
      completedAt: _now(),
      durationSeconds: durationSeconds,
      categories: widget.assessment.categories,
      categoryScores: categoryScores,
      // Only the two that changed this sitting. The rest of the learner's
      // supports shape the app, not the test, and recording them here would
      // make the result look accommodated when it was not.
      accommodations: profile.supports
          .where(
            (s) =>
                s == LearnerSupportOption.extendedTestTime ||
                s == LearnerSupportOption.fewerChoices,
          )
          .toSet(),
    );

    // Save result
    ref.read(assessmentResultsProvider.notifier).saveResult(result);

    // Award stars based on performance. A test of video answers only has
    // no score yet; answering it on camera still earns stars for the effort.
    final pct = marked.isEmpty
        ? (_answers.isEmpty ? 0.0 : 0.5)
        : score / marked.length;
    int stars = 0;
    if (pct >= 0.9) {
      stars = 5;
    } else if (pct >= 0.75) {
      stars = 3;
    } else if (pct >= 0.5) {
      stars = 2;
    } else if (pct > 0) {
      stars = 1;
    }
    if (stars > 0) {
      final starsEnabled = ref.read(
        gamificationFeatureProvider(GamificationFeature.stars),
      );
      if (starsEnabled) {
        ref.read(progressProvider.notifier).addStars(stars);
      }
    }

    // Navigate to result summary
    if (mounted) {
      context.pushReplacement(
        '/assessment/summary',
        extra: result,
      );
    }
  }

  void _confirmQuit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t.testQuitTitle),
        content: Text(_t.testQuitBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t.testQuitContinue),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: HCColor.of(context).errorText),
            child: Text(_t.testQuitConfirm),
          ),
        ],
      ),
    );
  }

  /// Shown until every sign clip is on the tablet — see [_clipsReady].
  Widget _buildClipCheck(BuildContext context) {
    final hc = HCColor.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_mediaMissing) ...[
                  const Text('🖼️', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.assessMediaMissingTitle ??
                        "Some pictures or videos aren't on this tablet",
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.assessMediaMissingBody ??
                        'Connect to Wi-Fi and try again, or start without '
                            'them. The test has not started.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _prepareClips,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n?.assessClipsTryAgain ?? 'Try again'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _startNow,
                    child: Text(
                      l10n?.assessMediaStartAnyway ?? 'Start without them',
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n?.assessClipsGoBack ?? 'Go back'),
                  ),
                ] else if (!_clipsMissing) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _signCardIds.isEmpty
                        ? (l10n?.assessMediaPreparing ??
                              'Getting the pictures and videos ready…')
                        : (l10n?.assessClipsPreparing ??
                              'Getting the sign videos ready…'),
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                    ),
                  ),
                ] else ...[
                  const Text('📶', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    l10n?.assessClipsMissingTitle ??
                        'The sign videos need the internet',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n?.assessClipsMissingBody ??
                        'This test has sign-language videos that are not on '
                            'this tablet yet. Connect to Wi‑Fi, then try '
                            'again. The test has not started.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _prepareClips,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n?.assessClipsTryAgain ?? 'Try again'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n?.assessClipsGoBack ?? 'Go back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSending(BuildContext context) {
    final hc = HCColor.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(context.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _t.assessVideoAnswerSending,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium.copyWith(
                      color: hc.textPrimary,
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

  @override
  Widget build(BuildContext context) {
    if (!_clipsReady) return _buildClipCheck(context);
    if (_sending) return _buildSending(context);
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // ─── Top Bar ──────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(padding, 12, padding, 0),
                child: Row(
                  children: [
                    IconButton(
                        tooltip: _t.testQuitTooltip,
                        onPressed: _confirmQuit,
                        icon: Icon(Icons.close_rounded,
                            color: hc.textSecondary),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.assessment.type.labelOf(_t),
                            style: AppTypography.labelMedium.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                          Text(
                            _t.testQuestionOf(
                              _currentIndex + 1,
                              _questions.length,
                            ),
                            style: AppTypography.titleSmall.copyWith(
                              color: hc.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score so far
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: hc.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_answers.where((a) => a.isCorrect).length}/'
                        '${_answers.where((a) => !a.needsReview).length}',
                        style: AppTypography.labelLarge.copyWith(
                          color: hc.readableOver(
                            hc.primary,
                            hc.primary.withValues(alpha: 0.15),
                          ),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Progress Bar (+ countdown, when timed) ───
              // The countdown shares this row rather than the top bar: the
              // bar can give up width, whereas a third chip up there overflows
              // at large text scales on a small phone.
              Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: padding, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label:
                            _t.testProgressSemantics((_progress * 100).round()),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _progress,
                            minHeight: 8,
                            backgroundColor: hc.border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(hc.primary),
                          ),
                        ),
                      ),
                    ),
                    if (_remaining != null) ...[
                      const SizedBox(width: 12),
                      _TimeRemainingChip(remaining: _remaining!, hc: hc),
                    ],
                  ],
                ),
              ),

              // ─── Question Content ─────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Category chip
                      // Not on a sign item: the clip is the whole question there, and the
                      // category narrows the choices — a "Days & Time" chip over one day
                      // of the week and three unrelated words gave the answer away.
                      if (_currentQuestion.category != null &&
                          _currentQuestion.format != QuestionFormat.signVideo)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _currentQuestion.category!.color
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _currentQuestion.category!.labelOf(_t),
                              style: AppTypography.labelSmall.copyWith(
                                color: _currentQuestion.category!.darkColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Format badge
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: hc.surfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _currentQuestion.format.labelOf(
                              AppLocalizations.of(context),
                            ),
                            style: AppTypography.labelSmall.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Question text
                      Semantics(
                        header: true,
                        child: Text(
                          // A sign item's prompt is the same sentence every
                          // time, so it is read from l10n rather than from the
                          // stored question — translating what is already
                          // saved would rewrite a learner's pre-test template.
                          _currentQuestion.format == QuestionFormat.signVideo
                              ? (AppLocalizations.of(
                                      context,
                                    )?.signQuestionPrompt ??
                                    _currentQuestion.questionText)
                              // Generated wording is shown in the reader's
                              // language; the stored text is untouched.
                              : QuestionPrompt.localize(
                                  _currentQuestion.questionText,
                                  AppLocalizations.of(context),
                                ),
                          style: AppTypography.headlineMedium.copyWith(
                            color: hc.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                          .animate(key: ValueKey(_currentIndex))
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: 0.05, end: 0),

                      const SizedBox(height: 24),

                      // The clip *is* the prompt on a sign item, so it sits
                      // between the question and the choices. No caption:
                      // naming the word would give the answer away.
                      if (_currentQuestion.format ==
                              QuestionFormat.signVideo &&
                          _currentQuestion.signCardId != null) ...[
                        (widget.signClipBuilder ??
                                (ctx, id) => AssessmentSignClip(cardId: id))(
                            context, _currentQuestion.signCardId!),
                        const SizedBox(height: 20),
                      ],

                      // What the educator attached: a picture, a video, a
                      // sound, a signed version of the question — in the
                      // order and form this learner needs. Keyed by question
                      // so a video never carries on into the next one.
                      if (_mediaPresentation.showsAnything(
                        _currentQuestion.media,
                      )) ...[
                        AssessmentMediaPanel(
                          key: ValueKey('media_$_currentIndex'),
                          media: _currentQuestion.media,
                          presentation: _mediaPresentation,
                          fallbackLabel: QuestionPrompt.localize(
                            _currentQuestion.questionText,
                            AppLocalizations.of(context),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Answer area based on format
                      if (_currentQuestion.format ==
                          QuestionFormat.videoResponse)
                        _buildVideoAnswer(hc)
                      else if (_currentQuestion.format ==
                          QuestionFormat.fillInBlank)
                        _buildFillInBlank(hc)
                      else
                        _buildChoices(hc),

                      // Hint toggle
                      if (_currentQuestion.hint != null &&
                          _currentQuestion.hint!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _showHint = !_showHint),
                          child: Semantics(
                            button: true,
                            label: _showHint
                                ? _t.testHideHint
                                : _t.testShowHint,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showHint
                                      ? Icons.lightbulb_rounded
                                      : Icons.lightbulb_outline_rounded,
                                  color: hc.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showHint
                                      ? _t.testHideHint
                                      : _t.testShowHint,
                                  style: AppTypography.labelMedium.copyWith(
                                    color: hc.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showHint)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    hc.warning.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                  color: hc.warning
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                _currentQuestion.hint!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: hc.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: -0.1, end: 0),
                          ),
                      ],

                      // Feedback after answering
                      if (_answered) ...[
                        const SizedBox(height: 20),
                        _buildFeedback(hc),
                      ],
                    ],
                  ),
                ),
              ),

              // ─── Bottom Action ────────────────────────────
              if (_answered)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      padding, 0, padding, padding),
                  child: SizedBox(
                    width: double.infinity,
                    height: scaledControlHeight(context, 56),
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hc.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _isLastQuestion ? _t.testFinish : _t.testNext,
                        style: AppTypography.buttonText,
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// How one choice looks: plain before answering, then green for the right
  /// answer and red for a wrong pick — the same for words and pictures.
  ({Color bg, Color border, Color text}) _choiceColors(
    HCColor hc, {
    required bool isSelected,
    required bool isCorrectAnswer,
  }) {
    if (!_answered) {
      return (bg: hc.surface, border: hc.border, text: hc.textPrimary);
    }
    if (isSelected && _isCorrect) {
      return (
        bg: AppColors.success.withValues(alpha: 0.15),
        border: AppColors.success,
        text: AppColors.success,
      );
    }
    if (isSelected && !_isCorrect) {
      return (
        bg: AppColors.error.withValues(alpha: 0.15),
        border: AppColors.error,
        text: AppColors.error,
      );
    }
    if (isCorrectAnswer) {
      return (
        bg: AppColors.success.withValues(alpha: 0.1),
        border: AppColors.success.withValues(alpha: 0.5),
        text: AppColors.success,
      );
    }
    return (bg: hc.surface, border: hc.border, text: hc.textHint);
  }

  Widget _buildChoices(HCColor hc) {
    // Pictures to tap, for a learner who does not read yet — unless this
    // learner cannot use pictures, who keeps the list their screen reader
    // reads (see AssessmentMediaPresentation.pictureChoices).
    if (_mediaPresentation.pictureChoices &&
        _currentQuestion.hasPictureChoices) {
      return _buildPictureChoices(hc);
    }
    return Column(
      children: List.generate(_currentQuestion.choices.length, (i) {
        final choice = _currentQuestion.choices[i];
        // What the learner reads; `choice` stays the stored answer.
        final shown = QuestionPrompt.choice(_currentQuestion, choice, _t);
        final isSelected = _selectedAnswer == choice;
        final isCorrectAnswer =
            choice.toLowerCase() ==
            _currentQuestion.correctAnswer.toLowerCase();

        final colors = _choiceColors(
          hc,
          isSelected: isSelected,
          isCorrectAnswer: isCorrectAnswer,
        );
        final bgColor = colors.bg;
        final borderColor = colors.border;
        final textColor = colors.text;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            button: !_answered,
            label: shown,
            selected: isSelected,
            child: GestureDetector(
              onTap: () => _selectAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: borderColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + i), // A, B, C, D
                          style: AppTypography.labelLarge.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        shown,
                        style: AppTypography.titleSmall.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_answered && isCorrectAnswer)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 22),
                    if (_answered && isSelected && !_isCorrect)
                      const Icon(Icons.cancel_rounded,
                          color: AppColors.error, size: 22),
                  ],
                ),
              ),
            ),
          ),
        )
            .animate(key: ValueKey('choice_${_currentIndex}_$i'))
            .fadeIn(duration: 300.ms, delay: (100 + i * 80).ms)
            .slideY(begin: 0.1, end: 0);
      }),
    );
  }

  /// The choices as a grid of pictures. Every card still carries its letter
  /// and words — for the educator reading over a shoulder, and for the
  /// learner who is just starting to read — and the whole card is the
  /// button, a big target for an unsteady hand or a gaze pointer.
  Widget _buildPictureChoices(HCColor hc) {
    final q = _currentQuestion;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 520;
        final columns = wide
            ? (q.choices.length > 4 ? 3 : 2)
            : (scale > 1.5 ? 1 : 2);
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < q.choices.length; i++)
              SizedBox(
                width: width,
                child: _pictureChoice(hc, i)
                    .animate(key: ValueKey('picture_${_currentIndex}_$i'))
                    .fadeIn(duration: 300.ms, delay: (100 + i * 80).ms),
              ),
          ],
        );
      },
    );
  }

  Widget _pictureChoice(HCColor hc, int i) {
    final q = _currentQuestion;
    final choice = q.choices[i];
    final shown = QuestionPrompt.choice(q, choice, _t);
    final isSelected = _selectedAnswer == choice;
    final isCorrectAnswer =
        choice.toLowerCase() == q.correctAnswer.toLowerCase();
    final colors = _choiceColors(
      hc,
      isSelected: isSelected,
      isCorrectAnswer: isCorrectAnswer,
    );
    final picture = q.choiceImages[choice];
    final letter = String.fromCharCode(65 + i);

    return Semantics(
      button: !_answered,
      selected: isSelected,
      label: shown,
      onTap: _answered ? null : () => _selectAnswer(choice),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => _selectAnswer(choice),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.bg,
              borderRadius: BorderRadius.circular(18),
              // Thicker than the list's rim: on a picture the colour is the
              // main signal of right and wrong.
              border: Border.all(color: colors.border, width: 3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: picture != null
                      ? AssessmentPicture(value: picture, maxHeight: 600)
                      : Container(
                          decoration: BoxDecoration(
                            color: hc.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            letter,
                            style: AppTypography.displayLarge.copyWith(
                              color: hc.textSecondary,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.border.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        letter,
                        style: AppTypography.labelLarge.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shown,
                        style: AppTypography.titleSmall.copyWith(
                          color: colors.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_answered && isCorrectAnswer)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 22,
                      ),
                    if (_answered && isSelected && !_isCorrect)
                      const Icon(
                        Icons.cancel_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Answering on camera: one big button, then the take itself with a way
  /// to record it again.
  Widget _buildVideoAnswer(HCColor hc) {
    final taken = _answered ? _selectedAnswer : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _videoAnswerHint(),
          style: AppTypography.bodyLarge.copyWith(color: hc.textPrimary),
        ),
        const SizedBox(height: 14),
        if (taken == null)
          SizedBox(
            height: scaledControlHeight(context, 64),
            child: FilledButton.icon(
              onPressed: _recordVideoAnswer,
              icon: const Icon(Icons.videocam_rounded, size: 28),
              label: Text(
                _t.assessVideoAnswerRecord,
                style: AppTypography.buttonText,
              ),
            ),
          )
        else ...[
          AssessmentMediaPanel(
            key: ValueKey('answer_$taken'),
            media: AssessmentMedia(video: taken),
            presentation: AssessmentMediaPresentation.educatorPreview,
            fallbackLabel: _t.assessYourVideoAnswer,
          ),
          OutlinedButton.icon(
            onPressed: _recordVideoAnswer,
            icon: const Icon(Icons.replay_rounded),
            label: Text(_t.assessVideoAnswerRedo),
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(scaledControlHeight(context, 52)),
            ),
          ),
        ],
      ],
    ).animate(key: ValueKey('video_$_currentIndex')).fadeIn(duration: 400.ms);
  }

  Widget _buildFillInBlank(HCColor hc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _fillController,
          enabled: !_answered,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: _t.testTypeHere,
            hintStyle: AppTypography.bodyMedium.copyWith(color: hc.textHint),
            filled: true,
            fillColor: hc.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: hc.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            suffixIcon: _answered
                ? Icon(
                    _isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: _isCorrect ? AppColors.success : AppColors.error,
                  )
                : null,
          ),
          style: AppTypography.titleMedium.copyWith(
            color: _answered
                ? (_isCorrect ? AppColors.success : AppColors.error)
                : hc.textPrimary,
          ),
          onSubmitted: (_) => _submitFillIn(),
        ),
        if (!_answered) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: scaledControlHeight(context, 50),
            child: ElevatedButton(
              onPressed: _submitFillIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: hc.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(_t.testSubmit, style: AppTypography.buttonText),
            ),
          ),
        ],
        if (_answered && !_isCorrect) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  _t.testHintAnswer(
                    QuestionPrompt.choice(
                      _currentQuestion,
                      _currentQuestion.correctAnswer,
                      _t,
                    ),
                  ),
                  style: AppTypography.labelMedium.copyWith(
                    color: HCColor.of(context).successText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
        ],
      ],
    ).animate(key: ValueKey('fill_$_currentIndex')).fadeIn(duration: 400.ms);
  }

  Widget _buildFeedback(HCColor hc) {
    if (_currentQuestion.format.needsReview) {
      // Not right, not wrong: sent to a person.
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const Text('🎥', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t.assessVideoAnswerSaved,
                style: AppTypography.titleSmall.copyWith(
                  color: hc.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms);
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (_isCorrect ? AppColors.success : AppColors.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_isCorrect ? AppColors.success : AppColors.error)
              .withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(
            _isCorrect ? '🎉' : '💡',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCorrect ? _t.testCorrect : _t.testNotQuite,
                  style: AppTypography.titleSmall.copyWith(
                    color:
                        _isCorrect ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!_isCorrect)
                  Text(
                    _t.testTheAnswerIs(
                      QuestionPrompt.choice(
                        _currentQuestion,
                        _currentQuestion.correctAnswer,
                        _t,
                      ),
                    ),
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1.0, 1.0),
          duration: 300.ms,
        );
  }
}

// ─── Time Remaining Chip ───────────────────────────────

/// Calm countdown for a timed assessment.
///
/// Deliberately not animated, and it does not flash: this app's learners
/// include children with cognitive and attention disabilities, for whom a
/// pulsing clock is a reason to stop trying. It changes colour once, in the
/// last minute, and reads its remaining time to a screen reader as words
/// rather than as a bare "4:07".
class _TimeRemainingChip extends StatelessWidget {
  final Duration remaining;
  final HCColor hc;

  const _TimeRemainingChip({required this.remaining, required this.hc});

  @override
  Widget build(BuildContext context) {
    final urgent = remaining.inSeconds <= 60;
    final color = urgent ? hc.error : hc.textSecondary;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Semantics(
      liveRegion: urgent,
      label: minutes > 0
          ? (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .testMinutesLeft(minutes)
          : (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .testSecondsLeft(seconds),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              '$minutes:${seconds.toString().padLeft(2, '0')}',
              style: AppTypography.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
