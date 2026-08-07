import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../widgets/flashcard_image.dart';
import '../../../core/services/action_clip_service.dart';
import '../../../core/services/flashcard_photo_service.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/hive_service.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../../../widgets/language_replay_bar.dart';
import '../models/tv_cast_session.dart';
import '../providers/tv_cast_provider.dart';
import '../services/tv_cast_asset_bridge.dart';
import '../services/tv_cast_ip_discovery.dart';
import '../services/tv_cast_prewarm.dart';
import '../widgets/tv_cast_live_panel.dart';
import '../widgets/tv_cast_qr_card.dart';
import '../widgets/tv_cast_remote_controls.dart';

/// Educator-facing TV Cast control screen. Starts an in-app HTTP server,
/// shows a QR + URL, and exposes the remote controls that drive what
/// every connected TV browser displays.
class TvCastScreen extends ConsumerStatefulWidget {
  const TvCastScreen({super.key});

  @override
  ConsumerState<TvCastScreen> createState() => _TvCastScreenState();
}

class _TvCastScreenState extends ConsumerState<TvCastScreen> {
  bool _starting = false;

  // ─── Network-change watchdog ──────────────────────────
  // While casting, the TV reaches this phone at a fixed local IP. If the phone
  // drops Wi-Fi or hops to a different network that IP changes (or vanishes) and
  // the TV can no longer find the cast — it shows "Oops, the teacher is
  // connecting". We mirror that on the phone with a banner so the teacher knows
  // to get back on the same Wi-Fi. connectivity_plus is the fast trigger; the
  // periodic IP re-check is what actually catches a same-type Wi-Fi A→B switch
  // (the local IP changes), since SSID isn't read on purpose (see
  // TvCastIpDiscovery — avoids the network_info_plus native-plugin conflict).
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _netCheckTimer;
  ScaffoldMessengerState? _messenger;
  String? _shownWarning;

  @override
  void initState() {
    super.initState();
    _connSub = Connectivity().onConnectivityChanged.listen(
      (_) => _checkNetwork(),
    );
    _netCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkNetwork(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _netCheckTimer?.cancel();
    _messenger?.clearMaterialBanners();
    super.dispose();
  }

  /// Compares the phone's current local IP against the address the cast server
  /// is bound to. Shows / clears the network-change banner accordingly. No-op
  /// when the server isn't running.
  Future<void> _checkNetwork() async {
    final session = ref.read(tvCastSessionProvider);
    if (!session.isServerRunning || session.listenUrl == null) {
      _clearNetworkWarning();
      return;
    }
    final boundHost = Uri.tryParse(session.listenUrl!)?.host;
    final ip = await TvCastIpDiscovery.findLocalIp();
    if (!mounted) return;
    if (ip == null) {
      _showNetworkWarning(
        'Wi-Fi disconnected — the TV can\'t reach this cast. Reconnect to the '
        'same Wi-Fi to continue.',
      );
    } else if (boundHost != null && ip != boundHost) {
      _showNetworkWarning(
        'You\'re on a different network now — the TV can\'t reach this cast. '
        'Reconnect to the original Wi-Fi, or tap Restart for a new code.',
        showRestart: true,
      );
    } else {
      _clearNetworkWarning();
    }
  }

  void _showNetworkWarning(String message, {bool showRestart = false}) {
    if (_shownWarning == message) return; // already showing this exact message
    _shownWarning = message;
    final messenger = _messenger;
    if (messenger == null) return;
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        leading: const Icon(Icons.wifi_off_rounded, color: AppColors.primary),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          if (showRestart)
            TextButton(
              onPressed: _restartCast,
              child: const Text('Restart'),
            ),
          TextButton(
            onPressed: _clearNetworkWarning,
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _clearNetworkWarning() {
    if (_shownWarning == null) return;
    _shownWarning = null;
    _messenger?.clearMaterialBanners();
  }

  /// Rebinds the server so the QR / URL match the current network.
  Future<void> _restartCast() async {
    _clearNetworkWarning();
    try {
      await ref.read(tvCastSessionProvider.notifier).stopServer();
    } catch (_) {
      // The session resets even if closing the socket throws.
    }
    if (!mounted) return;
    await _start();
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await ref.read(tvCastSessionProvider.notifier).startServer();
      final state = ref.read(tvCastSessionProvider);
      if (mounted && state.listenUrl == null) {
        AppSnackBar.error(
          context,
          message:
              'Wi-Fi not detected. Connect to the same network as your TV.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, message: 'Could not start cast: $e');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    // Confirm first so an accidental tap can't kill an active classroom cast —
    // and so the shutdown logo always produces a visible response.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop casting?'),
        content: const Text(
          'This ends the current cast and disconnects any TVs. '
          'You can start again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Capture before the await so we don't touch context across an async gap.
    final router = GoRouter.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    // Read the tally *before* stopping — stopServer clears it.
    final summary = notifier.sessionSummary;
    try {
      await notifier.stopServer();
    } catch (_) {
      // The session state still resets even if closing the socket throws.
    }
    if (!mounted) return;

    // Hand the educator a receipt for what the cast actually did. Skipped for
    // a cast that was started and immediately stopped — there'd be nothing on
    // it but zeroes.
    if (summary != null && summary.hasContent) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => _SessionSummaryDialog(summary: summary),
      );
      if (!mounted) return;
    } else {
      AppSnackBar.success(context, message: 'Casting stopped');
    }
    // Leave the cast screen so "shutdown" clearly ends the session instead of
    // silently reverting to the Start card on the same page.
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tvCastSessionProvider);
    final hc = HCColor.of(context);
    final padding = context.pagePadding;
    // Gates the on-demand audio replay (phone-side) for Flashcards / Stories.
    final ttsEnabled = ref.watch(settingsProvider.select((s) => s.ttsEnabled));

    return Scaffold(
      appBar: AppBar(
        title: const Text('TV Cast'),
        actions: [
          if (state.isServerRunning) ...[
            // "Teacher is out" — keeps the cast alive so the TV can show the
            // away screen; tap again to resume. Distinct from Stop below.
            IconButton(
              tooltip: state.isAway
                  ? 'Teacher is back (resume cast)'
                  : 'Show "Teacher is out" on TV',
              icon: Icon(
                state.isAway
                    ? Icons.coffee_rounded
                    : Icons.directions_walk_rounded,
                color: state.isAway ? AppColors.primary : null,
              ),
              onPressed: () => ref
                  .read(tvCastSessionProvider.notifier)
                  .setAway(!state.isAway),
            ),
            IconButton(
              tooltip: 'Stop casting',
              icon: const Icon(Icons.power_settings_new_rounded),
              onPressed: _stop,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!state.isServerRunning) ...[
                _StartCard(starting: _starting, onStart: _start),
                // Only while idle: mid-cast the educator needs the controls,
                // not a look back at last week.
                const _CastHistory(),
              ] else ...[
                if (state.listenUrl != null)
                  TvCastQrCard(
                    url: state.listenUrl!,
                    code: state.castCode,
                  ),
                const SizedBox(height: 12),
                _ViewerCount(count: state.connectedViewers),
                if (state.isAway) ...[
                  const SizedBox(height: 12),
                  const _AwayNotice(),
                ],
                const SizedBox(height: 20),
                Text(
                  'What to cast',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                _ModePicker(state: state),
                const SizedBox(height: 16),
                _ModeConfig(state: state),
                if (state.mode != CastMode.idle &&
                    state.mode != CastMode.live) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel('Now showing on TV'),
                  const SizedBox(height: 10),
                  _CastPreview(state: state),
                ],
                // Per-cast pacing toggle for the auto-advanceable modes. Lets
                // the educator stop the slideshow timer and step through items
                // manually (or turn it back on).
                if (state.mode == CastMode.flashcards ||
                    state.mode == CastMode.fslVideo ||
                    state.mode == CastMode.story) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel('Pacing'),
                  const SizedBox(height: 8),
                  _AutoAdvanceControl(state: state),
                  // Flashcards can also reveal a real photo by tapping the card
                  // on the TV. This toggles that tap-to-flip on/off.
                  if (state.mode == CastMode.flashcards) ...[
                    const SizedBox(height: 8),
                    _TapOnlyControl(state: state),
                  ],
                ],
                const SizedBox(height: 20),
                // The Live Activity panel has its own push controls; the
                // prev/pause/next remote only applies to the slide modes.
                if (state.mode != CastMode.idle &&
                    state.mode != CastMode.live)
                  TvCastRemoteControls(
                    isPaused: state.isPaused,
                    onPrev: () =>
                        ref.read(tvCastSessionProvider.notifier).prev(),
                    onPlayPause: () =>
                        ref.read(tvCastSessionProvider.notifier).togglePause(),
                    onNext: () =>
                        ref.read(tvCastSessionProvider.notifier).next(),
                  ),
                // On-demand audio replay for the current word / page, in either
                // language — plays from this phone so the educator can model
                // pronunciation without advancing the slide. (The TV narrates
                // automatically as slides change.)
                if ((state.mode == CastMode.flashcards ||
                        state.mode == CastMode.story) &&
                    ttsEnabled) ...[
                  const SizedBox(height: 20),
                  const _SectionLabel('Replay audio'),
                  const SizedBox(height: 6),
                  Text(
                    'Hear the current ${state.mode == CastMode.story ? 'page' : 'word'} '
                    'again on this phone.',
                    style: AppTypography.bodySmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LanguageReplayBar(
                    onEnglish: () => ref
                        .read(tvCastSessionProvider.notifier)
                        .replayCurrentWord(filipino: false),
                    onFilipino: () => ref
                        .read(tvCastSessionProvider.notifier)
                        .replayCurrentWord(filipino: true),
                  ),
                ],
                const SizedBox(height: 20),
                const _SectionLabel('TV display style'),
                const SizedBox(height: 10),
                _TemplateGallery(current: state.castTheme),
                const SizedBox(height: 20),
                const _SectionLabel('Lesson timer'),
                const SizedBox(height: 8),
                _TimerControl(state: state),
                const SizedBox(height: 20),
                const _SectionLabel('Readability on TV'),
                const SizedBox(height: 8),
                _ReadabilityControls(state: state),
                const SizedBox(height: 16),
                const _SectionLabel('Show on TV'),
                const SizedBox(height: 8),
                _CastTitleField(state: state),
                const SizedBox(height: 20),
                const _SectionLabel('Audio'),
                const SizedBox(height: 6),
                _AudioControls(state: state),
                const SizedBox(height: 20),
                const _SectionLabel('Fullscreen'),
                const SizedBox(height: 8),
                _FullscreenControl(state: state),
                const SizedBox(height: 20),
                const _SectionLabel('TV remote'),
                const SizedBox(height: 8),
                _TvRemoteControl(state: state),
                const SizedBox(height: 24),
                const _TroubleshootPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Start card ────────────────────────────────────────

class _StartCard extends StatelessWidget {
  final bool starting;
  final VoidCallback onStart;

  const _StartCard({required this.starting, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tv_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cast to any TV',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Works on any TV with a web browser — Samsung, LG, Sony, '
            'Fire TV, Chromecast with Google TV, smart projectors, '
            'or any laptop plugged into HDMI. You open the link in the TV\'s '
            'own browser — this is not the same as mirroring or casting your '
            'tablet, so sound comes from the TV.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: starting ? null : onStart,
            icon: starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(starting ? 'Starting…' : 'Start Casting'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              textStyle: AppTypography.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Connected viewer count ────────────────────────────

class _ViewerCount extends StatelessWidget {
  final int count;
  const _ViewerCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final color = count > 0 ? const Color(0xFF4CAF50) : hc.textSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: count > 0
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          count == 0
              ? 'Waiting for TV to connect…'
              : '$count viewer${count == 1 ? '' : 's'} connected',
          style: AppTypography.labelMedium.copyWith(color: color),
        ),
      ],
    );
  }
}

// ─── "Teacher is out" notice ───────────────────────────

/// Shown on the phone while the away toggle is on, so the teacher knows the TV
/// is currently displaying the "The teacher is out" screen.
class _AwayNotice extends StatelessWidget {
  const _AwayNotice();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'The TV is showing "The teacher is out". Tap the walk icon to '
              'resume casting.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mode picker (segmented buttons) ───────────────────

class _ModePicker extends ConsumerWidget {
  final TvCastSession state;
  const _ModePicker({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final modes = [
      (CastMode.flashcards, Icons.style_rounded, 'Flashcards'),
      (CastMode.fslVideo, Icons.sign_language_rounded, 'FSL'),
      (CastMode.story, Icons.menu_book_rounded, 'Stories'),
      (CastMode.live, Icons.quiz_rounded, 'Live Activity'),
      (CastMode.progress, Icons.leaderboard_rounded, 'Progress'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((m) {
        final selected = state.mode == m.$1;
        return ChoiceChip(
          selected: selected,
          avatar: Icon(
            m.$2,
            size: 18,
            color: selected ? Colors.white : AppColors.primary,
          ),
          label: Text(m.$3),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          onSelected: (_) => notifier.setMode(m.$1),
        );
      }).toList(),
    );
  }
}

// ─── Mode-specific configuration ───────────────────────

class _ModeConfig extends ConsumerWidget {
  final TvCastSession state;
  const _ModeConfig({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final hc = HCColor.of(context);

    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final dropdown = DropdownButtonFormField<FlashcardCategory>(
          initialValue: state.category,
          decoration: InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.category_rounded),
          ),
          items: FlashcardCategory.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    '${c.label}  (${SeedData.getByCategory(c).length})',
                  ),
                ),
              )
              .toList(),
          onChanged: (c) {
            if (c != null) notifier.setCategory(c);
          },
        );
        // FSL mode adds a per-word picker so the teacher can jump to a
        // specific sign instead of waiting for autoplay to cycle to it.
        if (state.mode == CastMode.fslVideo && state.category != null) {
          final cat = state.category!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dropdown,
              const SizedBox(height: 12),
              _FslWordPicker(state: state),
              _PrewarmControl(
                targetKey: 'cat:${cat.index}',
                targetLabel: cat.label,
                onStart: () => ref
                    .read(tvCastPrewarmProvider.notifier)
                    .warmCategory(cat),
              ),
            ],
          );
        }
        // Flashcards mode adds the "Show Me" button below the category when the
        // current card has an action clip (a looping video/GIF of the word in
        // motion) — mirroring the in-app "Show Me" button. It hides itself on
        // cards without a clip.
        if (state.mode == CastMode.flashcards && state.category != null) {
          final cat = state.category!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dropdown,
              _FlipControl(state: state),
              _ShowMeControl(state: state),
              _PrewarmControl(
                targetKey: 'cat:${cat.index}',
                targetLabel: cat.label,
                onStart: () => ref
                    .read(tvCastPrewarmProvider.notifier)
                    .warmCategory(cat),
              ),
            ],
          );
        }
        return dropdown;

      case CastMode.story:
        final all = SeedStories.all;
        final dropdown = DropdownButtonFormField<String>(
          initialValue: state.storyId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Story',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.auto_stories_rounded),
          ),
          items: all
              .map(
                (s) => DropdownMenuItem(
                  value: s.id,
                  child: Text(
                    '${s.emoji}  ${s.titleEn}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) notifier.setStory(id);
          },
        );
        // Story mode adds two controls below the picker, each shown only when
        // the current page supports it: the cartoon ⇄ real-life picture flip
        // (mirrors the in-app Stories tap-to-flip illustration) and the "Watch
        // in FSL" sign-language button (mirrors the Flashcards "Show Me"). Each
        // hides itself on pages / stories that lack that content.
        final storyId = state.storyId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            dropdown,
            _StoryImageFlipControl(state: state),
            _StoryFslControl(state: state),
            if (storyId != null)
              _PrewarmControl(
                targetKey: 'story:$storyId',
                targetLabel: all
                    .firstWhere(
                      (s) => s.id == storyId,
                      orElse: () => all.first,
                    )
                    .titleEn,
                onStart: () => ref
                    .read(tvCastPrewarmProvider.notifier)
                    .warmStory(storyId),
              ),
          ],
        );

      case CastMode.progress:
        return _ProgressViewPicker(state: state);

      case CastMode.live:
        return TvCastLivePanel(state: state);

      case CastMode.idle:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hc.textSecondary.withValues(alpha: 0.2)),
          ),
          child: Text(
            'Pick what to cast above. The TV will switch instantly.',
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        );
    }
  }
}

// ─── Readability on TV (text size + language) ──────────

/// How big the TV's words are, and which language they're in.
///
/// Both are properties of the *display*, not of the content, which is why they
/// live here rather than in the app's own accessibility settings: one tablet
/// drives a screen a whole mixed-ability class is reading, and the right answer
/// changes per room and per lesson.
class _ReadabilityControls extends ConsumerWidget {
  final TvCastSession state;
  const _ReadabilityControls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniLabel(
              icon: Icons.format_size_rounded,
              text: 'Text size on TV',
              hc: hc,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CastTextSize.values
                  .map(
                    (s) => _PrefChip(
                      label: s.label,
                      selected: state.castTextSize == s,
                      onTap: () => notifier.setCastTextSize(s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              'Makes the word, story line, sign caption and answer choices '
              'bigger — for learners reading from the back, or with low vision.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: 16),
            _MiniLabel(
              icon: Icons.translate_rounded,
              text: 'Language on TV',
              hc: hc,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CastLanguage.values
                  .map(
                    (l) => _PrefChip(
                      label: l.label,
                      selected: state.castLanguage == l,
                      onTap: () => notifier.setCastLanguage(l),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 6),
            Text(
              state.castLanguage == CastLanguage.both
                  ? 'The TV shows and speaks both languages.'
                  : 'The TV shows and speaks ${state.castLanguage.label} only '
                        '— the other language is hidden, not removed, so you '
                        'can switch back mid-lesson.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final HCColor hc;
  const _MiniLabel({required this.icon, required this.text, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Compact selected/unselected chip shared by the readability pickers.
class _PrefChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PrefChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      labelStyle: AppTypography.labelMedium.copyWith(
        color: selected ? Colors.white : AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      onSelected: (_) => onTap(),
    );
  }
}

// ─── "Prepare for casting" (offline pre-download) ──────

/// Pulls every clip and picture a category / story will need onto the device
/// before the lesson starts.
///
/// The cast downloads media the moment the TV asks for it, which on a school
/// connection means the class watches a placeholder while an 8 MB sign clip
/// arrives. This turns that into a choice: prepare once during setup, then the
/// cast plays from disk and keeps working if the network drops entirely.
class _PrewarmControl extends ConsumerWidget {
  /// `cat:<index>` or `story:<id>` — must match the key the notifier stamps,
  /// so a finished run for a *different* category doesn't read as "ready".
  final String targetKey;
  final String targetLabel;
  final VoidCallback onStart;

  const _PrewarmControl({
    required this.targetKey,
    required this.targetLabel,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final prewarm = ref.watch(tvCastPrewarmProvider);
    final notifier = ref.read(tvCastPrewarmProvider.notifier);
    final isThisTarget = prewarm.targetKey == targetKey;
    final running = prewarm.isRunning && isThisTarget;
    final finished = isThisTarget && prewarm.status == PrewarmStatus.done;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: finished
              ? const Color(0xFF2E7D32).withValues(alpha: 0.35)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                finished
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_download_rounded,
                color: finished ? const Color(0xFF2E7D32) : AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  finished ? 'Ready to cast offline' : 'Prepare for casting',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            running
                ? 'Downloading ${prewarm.done + 1} of ${prewarm.total}'
                      '${prewarm.label.isEmpty ? '' : ' — ${prewarm.label}'}'
                : finished
                ? _doneMessage(prewarm)
                : 'Download every sign, clip and picture in $targetLabel now, '
                      'so the TV never waits mid-lesson — and the cast keeps '
                      'working if the Wi-Fi drops.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          if (running) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: prewarm.fraction,
                minHeight: 8,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (running)
            OutlinedButton.icon(
              onPressed: notifier.cancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Stop downloading'),
            )
          else
            FilledButton.icon(
              onPressed: prewarm.isRunning ? null : onStart,
              icon: Icon(
                finished ? Icons.refresh_rounded : Icons.download_rounded,
                size: 18,
              ),
              label: Text(finished ? 'Check again' : 'Prepare $targetLabel'),
            ),
        ],
      ),
    );
  }

  String _doneMessage(TvCastPrewarmState p) {
    if (p.total == 0) {
      return 'Nothing to download for $targetLabel — it casts from the app.';
    }
    if (p.failed > 0) {
      return '${p.total - p.failed} of ${p.total} ready. ${p.failed} '
          'couldn\'t be downloaded — those will load during the lesson if the '
          'network is up.';
    }
    return 'All ${p.total} items are on this device. $targetLabel will cast '
        'instantly, even with no internet.';
  }
}

// ─── Progress view picker ──────────────────────────────

/// Chooses which progress display the TV shows.
///
/// Defaults to "Class wins" — a wall-sized ranking of children by stars is a
/// choice a teacher should make deliberately, not one the app makes for them.
/// The leaderboard is one tap away for classes it suits.
class _ProgressViewPicker extends ConsumerWidget {
  final TvCastSession state;
  const _ProgressViewPicker({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CastProgressView.values.map((v) {
            final selected = state.castProgressView == v;
            return ChoiceChip(
              selected: selected,
              avatar: Icon(
                v == CastProgressView.classWins
                    ? Icons.groups_rounded
                    : Icons.leaderboard_rounded,
                size: 18,
                color: selected ? Colors.white : AppColors.primary,
              ),
              label: Text(v.label),
              labelStyle: AppTypography.labelMedium.copyWith(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              onSelected: (_) => notifier.setCastProgressView(v),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                state.castProgressView == CastProgressView.classWins
                    ? Icons.groups_rounded
                    : Icons.leaderboard_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${state.castProgressView.description} '
                  'Updates by itself as your class works.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Fullscreen toggle ──────────────────────────────────

/// A single toggle (default on) that fills the whole TV — browser fullscreen,
/// no address bar / chrome — for every connected TV. Driven from this phone /
/// tablet and applied on the TV by `app.js`, exactly like the other cast
/// controls. Lenient casting devices (most Smart-TV browsers, Fire TV Silk,
/// WebView dongles) fill the instant it's turned on; stricter ones (Chrome on
/// Chromecast / Google TV only enter fullscreen from a user gesture) fill on the
/// first remote OK / tap on the TV. Turning it off exits everywhere. The cast
/// page auto-resizes to fit any TV either way — this only controls the chrome.
class _FullscreenControl extends ConsumerWidget {
  final TvCastSession state;
  const _FullscreenControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final subtitle = state.fullscreenOnTv
        ? 'The TV fills the whole screen and auto-resizes to fit any TV — Smart '
              'TV, Chromecast / Google TV, Fire TV, projector or HDMI laptop. On '
              'some TVs, press OK on the remote once to finish filling the screen.'
        : 'The TV keeps the browser bars. Turn on to fill the whole screen.';

    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: SwitchListTile(
        value: state.fullscreenOnTv,
        onChanged: notifier.setFullscreenOnTv,
        secondary: const Icon(Icons.fullscreen_rounded),
        title: Text(
          'Fullscreen on TV',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ),
    );
  }
}

// ─── Cast history ──────────────────────────────────────

/// The educator's recent casts, shown under the Start card.
///
/// Casting used to leave no trace at all — this is the record of what was
/// actually taught off the TV, which is the question a teacher has when they
/// come back to the screen ("what did I get through on Tuesday?").
///
/// Counts only, never learner names, and deliberately outside the research
/// export: that dataset is scoped to the Student population by design.
class _CastHistory extends ConsumerWidget {
  const _CastHistory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final profile = ref.watch(profileProvider);
    if (profile == null) return const SizedBox.shrink();

    final history = ref.watch(castSessionHistoryProvider(profile.id));
    if (history.isEmpty) return const SizedBox.shrink();

    // A handful is what's useful at a glance; the rest stays on disk.
    final shown = history.take(5).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _SectionLabel('Recent casts'),
              const Spacer(),
              TextButton(
                onPressed: () => _confirmClear(context, ref, profile.id),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Material(
            color: hc.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: hc.textSecondary.withValues(alpha: 0.15),
                    ),
                  _CastHistoryRow(summary: shown[i]),
                ],
              ],
            ),
          ),
          if (history.length > shown.length) ...[
            const SizedBox(height: 6),
            Text(
              '${history.length - shown.length} older '
              '${history.length - shown.length == 1 ? 'cast' : 'casts'} kept '
              '(90 days).',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    String profileId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear cast history?'),
        content: const Text(
          'This removes the record of your past casts from this device. '
          'It does not affect any student data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await HiveService.clearCastSessions(profileId);
    ref.invalidate(castSessionHistoryProvider(profileId));
  }
}

class _CastHistoryRow extends StatelessWidget {
  final TvCastSessionSummary summary;
  const _CastHistoryRow({required this.summary});

  /// "Today, 11:36" / "Yesterday" / "Mon 4 Aug" — recent casts are the ones a
  /// teacher is placing in their week, so relative beats a raw date.
  String _when(DateTime? at) {
    if (at == null) return 'Earlier';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today, $hh:$mm';
    if (diff == 1) return 'Yesterday, $hh:$mm';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${days[at.weekday - 1]} ${at.day} ${months[at.month - 1]}';
  }

  String _modeLabel(CastMode m) => switch (m) {
    CastMode.flashcards => 'Flashcards',
    CastMode.fslVideo => 'FSL',
    CastMode.story => 'Stories',
    CastMode.progress => 'Progress',
    CastMode.live => 'Live',
    CastMode.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final d = summary.duration;
    final mins = d.inMinutes < 1 ? '<1 min' : '${d.inMinutes} min';

    final bits = <String>[];
    if (summary.cardsShown > 0) bits.add('${summary.cardsShown} cards');
    if (summary.storyPagesShown > 0) {
      bits.add('${summary.storyPagesShown} pages');
    }
    if (summary.liveQuestionsPushed > 0) {
      bits.add(
        '${summary.liveQuestionsPushed} Qs · ${summary.liveAnswers} answers',
      );
    }

    final modes = summary.modesUsed.map(_modeLabel).where((s) => s.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.history_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_when(summary.startedAt)} · $mins',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hc.textPrimary,
                  ),
                ),
                if (modes.isNotEmpty || bits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      [
                        if (modes.isNotEmpty) modes.join(' + '),
                        ...bits,
                      ].join(' · '),
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Session summary ───────────────────────────────────

/// The receipt shown when a cast ends.
///
/// Casting was otherwise completely ephemeral — a teacher ran a lesson off the
/// TV and the app kept nothing. This at least tells them what just happened,
/// in the moment they can still act on it.
class _SessionSummaryDialog extends StatelessWidget {
  final TvCastSessionSummary summary;
  const _SessionSummaryDialog({required this.summary});

  String _duration(Duration d) {
    if (d.inMinutes < 1) return '${d.inSeconds} sec';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '$h hr $m min';
    return '${d.inMinutes} min';
  }

  String _modeLabel(CastMode m) => switch (m) {
    CastMode.flashcards => 'Flashcards',
    CastMode.fslVideo => 'FSL signs',
    CastMode.story => 'Stories',
    CastMode.progress => 'Progress',
    CastMode.live => 'Live Activity',
    CastMode.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final rows = <(IconData, String)>[
      (Icons.schedule_rounded, '${_duration(summary.duration)} of casting'),
      if (summary.modesUsed.isNotEmpty)
        (
          Icons.cast_rounded,
          summary.modesUsed.map(_modeLabel).join(' · '),
        ),
      if (summary.cardsShown > 0)
        (Icons.style_rounded, '${summary.cardsShown} cards / signs shown'),
      if (summary.storyPagesShown > 0)
        (Icons.menu_book_rounded, '${summary.storyPagesShown} story pages'),
      if (summary.liveQuestionsPushed > 0)
        (
          Icons.quiz_rounded,
          '${summary.liveQuestionsPushed} live questions · '
              '${summary.liveAnswers} answers',
        ),
      if (summary.peakViewers > 0)
        (
          Icons.tv_rounded,
          '${summary.peakViewers} '
              '${summary.peakViewers == 1 ? 'TV' : 'TVs'} at once',
        ),
    ];

    return AlertDialog(
      title: const Text('Lesson cast'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, text) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: AppTypography.bodyMedium.copyWith(
                        color: hc.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

// ─── Lesson timer ──────────────────────────────────────

/// Sets a countdown the whole room can see, overlaid on whatever is casting.
///
/// Ticks locally (a 1 s `setState`) rather than through the provider: the
/// provider deliberately stores only the deadline, because a per-second state
/// change would bump the cast revision and make the TV rebuild its stage —
/// restarting any playing sign clip once a second.
class _TimerControl extends ConsumerStatefulWidget {
  final TvCastSession state;
  const _TimerControl({required this.state});

  @override
  ConsumerState<_TimerControl> createState() => _TimerControlState();
}

class _TimerControlState extends ConsumerState<_TimerControl> {
  Timer? _tick;

  static const _presets = [
    (label: '1 min', minutes: 1),
    (label: '3 min', minutes: 3),
    (label: '5 min', minutes: 5),
    (label: '10 min', minutes: 10),
  ];

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.state.timerSecondsLeft != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _clock(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final left = widget.state.timerSecondsLeft;
    final paused = widget.state.timerPausedSecondsLeft != null;
    final finished = widget.state.isTimerFinished;

    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniLabel(
              icon: Icons.timer_outlined,
              text: 'Lesson timer',
              hc: hc,
            ),
            const SizedBox(height: 8),
            if (left == null) ...[
              Text(
                'Show a countdown in the corner of the TV — for transitions, '
                'quiet reading, or "five more minutes". The lesson keeps '
                'playing underneath it.',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets
                    .map(
                      (p) => OutlinedButton(
                        onPressed: () => notifier.startTimer(
                          Duration(minutes: p.minutes),
                        ),
                        child: Text(p.label),
                      ),
                    )
                    .toList(),
              ),
            ] else ...[
              Row(
                children: [
                  Text(
                    finished ? "Time's up" : _clock(left),
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w900,
                      color: finished
                          ? const Color(0xFFC62828)
                          : hc.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (paused && !finished) ...[
                    const SizedBox(width: 10),
                    Text(
                      'paused',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!finished)
                    IconButton(
                      onPressed: paused
                          ? notifier.resumeTimer
                          : notifier.pauseTimer,
                      icon: Icon(
                        paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                    ),
                  IconButton(
                    onPressed: notifier.clearTimer,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                finished
                    ? 'The TV is showing "Time\'s up!". Clear it, or start '
                          'another.'
                    : 'Showing on the TV, over the lesson.',
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets
                    .map(
                      (p) => OutlinedButton(
                        onPressed: () => notifier.startTimer(
                          Duration(minutes: p.minutes),
                        ),
                        child: Text(p.label),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── TV remote as a control surface ────────────────────

/// Lets the TV's own remote step the lesson, so a teacher at the board doesn't
/// have to walk back to the tablet. Enforced on the phone, not the TV — turning
/// it off stops an already-open TV page from driving the cast.
class _TvRemoteControl extends ConsumerWidget {
  final TvCastSession state;
  const _TvRemoteControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: SwitchListTile(
        value: state.tvRemoteEnabled,
        onChanged: notifier.setTvRemoteEnabled,
        secondary: const Icon(Icons.settings_remote_rounded),
        title: Text(
          'Control from the TV remote',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          state.tvRemoteEnabled
              ? 'Press ◀ or ▶ on the TV remote to move between cards, signs or '
                    'story pages, and play/pause to hold. Handy when you\'re at '
                    'the board and the tablet is on your desk. (OK still just '
                    'turns on the TV\'s sound.)'
              : 'The TV remote can\'t change the lesson. Turn on if you want to '
                    'step through from the board — or leave off for a screen '
                    'left unattended.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ),
    );
  }
}

// ─── Troubleshoot panel ────────────────────────────────

class _TroubleshootPanel extends StatelessWidget {
  const _TroubleshootPanel();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return ExpansionTile(
      title: Text(
        'Troubleshooting',
        style: AppTypography.titleSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: hc.textPrimary,
        ),
      ),
      leading: const Icon(Icons.help_outline_rounded),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: const [
        _Tip(text: 'Both phone and TV must be on the SAME Wi-Fi network.'),
        _Tip(
          text:
              'If you\'re on a school or guest Wi-Fi, "AP isolation" may '
              'block phone-to-TV traffic. Try a regular home network.',
        ),
        _Tip(text: 'Samsung TV: open the "Internet" app, type the URL.'),
        _Tip(text: 'LG TV: open "Web Browser" from the home dashboard.'),
        _Tip(text: 'Fire TV: install Silk Browser (free), then open URL.'),
        _Tip(
          text:
              'Chromecast with Google TV: open Chrome from the apps list, '
              'type the URL.',
        ),
        _Tip(
          text: 'Apple TV: AirPlay-mirror a laptop browser showing the URL.',
        ),
        _Tip(
          text:
              'Not filling the whole TV? Make sure "Fullscreen on TV" is on '
              'above. On some TVs (e.g. Chromecast / Google TV) press OK on the '
              'remote once to finish filling the screen.',
        ),
        _Tip(
          text:
              'You can leave this screen — the cast keeps running. A "Casting '
              'to TV" bar stays at the bottom of the app so you can pause or '
              'skip from anywhere, and tapping it brings you back here.',
        ),
        _Tip(
          text:
              'Only TVs that open your exact cast link (it ends in your cast '
              'code) can see the lesson. Starting a new cast makes a new code '
              'and retires the old link.',
        ),
        _Tip(
          text:
              'Too quiet? The app already speaks at maximum — raise the TV\'s '
              'volume (or the phone\'s, if sound plays from the phone).',
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  final String text;
  const _Tip({required this.text});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: hc.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section label ─────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Text(
      text,
      style: AppTypography.titleMedium.copyWith(
        fontWeight: FontWeight.w700,
        color: hc.textPrimary,
      ),
    );
  }
}

// ─── TV display template gallery ───────────────────────

/// Icon + swatch colour for each TV display template.
const Map<CastTheme, (IconData, Color)> _templateStyle = {
  CastTheme.classroom: (Icons.school_rounded, Color(0xFF1565C0)),
  CastTheme.dark: (Icons.dark_mode_rounded, Color(0xFF0F172A)),
  CastTheme.light: (Icons.light_mode_rounded, Color(0xFFCBD5E1)),
  CastTheme.playful: (Icons.celebration_rounded, Color(0xFFEC407A)),
  CastTheme.calm: (Icons.spa_rounded, Color(0xFF80CBC4)),
  CastTheme.seasonal: (Icons.ac_unit_rounded, Color(0xFF8E24AA)),
  CastTheme.highContrast: (Icons.contrast_rounded, Color(0xFF000000)),
};

class _TemplateGallery extends ConsumerWidget {
  final CastTheme current;
  const _TemplateGallery({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    // Surface classroom first (the recommended lit-room default), then the
    // rest, with high-contrast last as the accessibility option.
    const order = [
      CastTheme.classroom,
      CastTheme.dark,
      CastTheme.light,
      CastTheme.playful,
      CastTheme.calm,
      CastTheme.seasonal,
      CastTheme.highContrast,
    ];
    return Column(
      children: [
        for (final t in order)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TemplateCard(
              theme: t,
              selected: current == t,
              onTap: () => notifier.setCastTheme(t),
            ),
          ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final CastTheme theme;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final (icon, swatch) = _templateStyle[theme] ?? (Icons.tv_rounded, AppColors.primary);
    return Semantics(
      button: true,
      selected: selected,
      label: '${theme.label} display style. ${theme.description}',
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.10)
            : hc.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.15),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: swatch,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Icon(icon, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.label,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hc.textPrimary,
                        ),
                      ),
                      Text(
                        theme.description,
                        style: AppTypography.bodySmall
                            .copyWith(color: hc.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected ? AppColors.primary : hc.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── "Show on TV" branding field ───────────────────────

/// Optional branding text the educator can show on the TV (e.g. a class name).
/// Syncs from the session when unfocused so the live-session auto-fill is
/// reflected without fighting the educator's typing.
class _CastTitleField extends ConsumerStatefulWidget {
  final TvCastSession state;
  const _CastTitleField({required this.state});

  @override
  ConsumerState<_CastTitleField> createState() => _CastTitleFieldState();
}

class _CastTitleFieldState extends ConsumerState<_CastTitleField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.castTitle ?? '');
  }

  @override
  void didUpdateWidget(covariant _CastTitleField old) {
    super.didUpdateWidget(old);
    final incoming = widget.state.castTitle ?? '';
    if (!_focus.hasFocus && incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textInputAction: TextInputAction.done,
      maxLength: 40,
      decoration: InputDecoration(
        hintText: 'e.g. Ms. Cruz — Grade 2 (optional)',
        prefixIcon: const Icon(Icons.badge_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _controller.clear();
                  ref.read(tvCastSessionProvider.notifier).setCastTitle(null);
                  setState(() {});
                },
              ),
      ),
      onChanged: (v) {
        ref.read(tvCastSessionProvider.notifier).setCastTitle(v);
        setState(() {}); // refresh the clear button
      },
    );
  }
}

// ─── Auto-advance (pacing) ─────────────────────────────

/// A single toggle that turns the auto-advance slideshow timer on/off for the
/// current mode. Default on (the classic slideshow); off lets the educator
/// dwell on each item and step with the prev/next remote.
class _AutoAdvanceControl extends ConsumerWidget {
  final TvCastSession state;
  const _AutoAdvanceControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final noun = switch (state.mode) {
      CastMode.story => 'page',
      CastMode.fslVideo => 'sign',
      _ => 'card',
    };
    final subtitle = state.autoAdvanceEnabled
        ? 'Moves to the next $noun automatically every few seconds.'
        : 'Stays on each $noun until you tap Next.';

    // A Material surface (not a coloured Container) so the SwitchListTile can
    // paint its ink/background — matches the Audio controls card below.
    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: SwitchListTile(
        value: state.autoAdvanceEnabled,
        onChanged: notifier.setAutoAdvanceEnabled,
        secondary: const Icon(Icons.slideshow_rounded),
        title: Text(
          'Auto-advance',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ),
    );
  }
}

// ─── Tap Only (flashcard photo reveal) ─────────────────

/// Enables the flashcard photo-flip feature. On by default: the TV shows the
/// emoji and a "Flip" button below lets you reveal the real photograph on the
/// TV (mirroring the in-app "Cards" emoji⇄photo flip). Off shows the emoji
/// only. There is no auto-flip — the reveal is always driven by the Flip button.
class _TapOnlyControl extends ConsumerWidget {
  final TvCastSession state;
  const _TapOnlyControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final subtitle = state.flipTapOnly
        ? 'The TV shows the emoji; use the Flip button to reveal the real photo '
              '(and flip back). Works on any TV.'
        : 'The TV shows the emoji only — the photo is hidden.';

    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: SwitchListTile(
        value: state.flipTapOnly,
        onChanged: notifier.setFlipTapOnly,
        secondary: const Icon(Icons.touch_app_rounded),
        title: Text(
          'Tap Only',
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      ),
    );
  }
}

// ─── Flip button (reveal the real photo on the TV) ─────

/// A "Flip" button shown for flashcards whose current card has a real photo
/// (and the photo-flip feature is on). Tapping it flips the TV flashcard
/// between the emoji and the photograph — driven from the phone so it works on
/// any receiver, including TVs you can't touch. Hidden while "Show Me" is
/// playing (the card isn't on screen then).
class _FlipControl extends ConsumerWidget {
  final TvCastSession state;
  const _FlipControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.flipTapOnly || state.showMeActive) return const SizedBox.shrink();
    final category = state.category;
    if (category == null) return const SizedBox.shrink();
    final cards = SeedData.getByCategory(category);
    if (cards.isEmpty) return const SizedBox.shrink();
    final card = cards[state.slideIndex % cards.length];
    if (!FlashcardPhotoService.hasPhoto(card)) return const SizedBox.shrink();

    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final flipped = state.cardFlipped;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: notifier.flipCard,
            icon: const Icon(Icons.flip_rounded),
            label: Text(flipped ? 'Show emoji' : 'Flip to photo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            flipped
                ? 'The TV is showing the real photo. Tap to flip back to the emoji.'
                : 'Flip "${card.wordEnglish}" on the TV to its real photo.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── "Show Me" action clip ─────────────────────────────

/// A "Show Me" button shown only when the current flashcard has an action clip
/// (a short looping video / GIF of the word in motion). Tapping it plays the
/// clip on the TV (and pauses autoplay so it isn't cut off); tapping again
/// returns to the card. Mirrors the in-app "Show Me" button.
class _ShowMeControl extends ConsumerWidget {
  final TvCastSession state;
  const _ShowMeControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = state.category;
    if (category == null) return const SizedBox.shrink();
    final cards = SeedData.getByCategory(category);
    if (cards.isEmpty) return const SizedBox.shrink();
    final card = cards[state.slideIndex % cards.length];
    if (!ActionClipService.hasClip(card)) return const SizedBox.shrink();

    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final active = state.showMeActive;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => notifier.setShowMe(!active),
            icon: Icon(
              active
                  ? Icons.stop_circle_rounded
                  : Icons.play_circle_fill_rounded,
            ),
            label: Text(active ? 'Hide clip' : 'Show Me'),
            style: FilledButton.styleFrom(
              backgroundColor: active
                  ? AppColors.secondaryDark
                  : AppColors.secondary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active
                ? 'Playing the clip on the TV. Tap to go back to the card.'
                : 'Play a short clip of "${card.wordEnglish}" in motion on the TV.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Story "Tap to Flip Animation" (cartoon ⇄ real picture) ────

/// A "Tap to Flip Animation (Cartoon ↔ Picture)" button shown only when the
/// current story page ships a cartoon + real-life picture pair. Tapping it flips
/// the TV story illustration between the cartoon and the real photograph —
/// driven from the phone so it works on any receiver, including TVs you can't
/// touch. For these pages the TV drops the emoji and shows both pictures,
/// mirroring the in-app Stories tap-to-flip illustration. Hides itself on pages
/// / stories without a picture pair (currently only "A Day at the Farm" ships
/// the full set).
class _StoryImageFlipControl extends ConsumerWidget {
  final TvCastSession state;
  const _StoryImageFlipControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = SeedStories.all.where((s) => s.id == state.storyId);
    if (stories.isEmpty) return const SizedBox.shrink();
    final story = stories.first;
    final total = story.sentencesEn.length;
    if (total == 0) return const SizedBox.shrink();
    final pageIdx = state.storyPageIndex.clamp(0, total - 1);
    if (TvCastAssetBridge.storyImagePair(story, pageIdx) == null) {
      return const SizedBox.shrink();
    }

    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final showingReal = state.storyImageFlipped;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: notifier.flipStoryImage,
            icon: const Icon(Icons.flip_rounded),
            label: const Text('Tap to Flip Animation (Cartoon ↔ Picture)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            showingReal
                ? 'The TV is showing the real picture. Tap to flip back to the '
                      'cartoon.'
                : 'The TV is showing the cartoon. Tap to flip to the real '
                      'picture on the TV.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Story "Watch in FSL" sign-language clip ───────────

/// A "Watch in FSL" button shown only when the current story page has a
/// sign-language clip. Tapping it plays the clip on the TV (and pauses autoplay
/// so it isn't cut off); tapping again returns to the story text. Mirrors the
/// flashcard "Show Me" button and the in-app Stories "Watch in FSL" button.
/// Independent of the Text-to-Speech setting — Deaf / hard-of-hearing learners
/// run with TTS off yet still need the sign-language path.
class _StoryFslControl extends ConsumerWidget {
  final TvCastSession state;
  const _StoryFslControl({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = SeedStories.all.where((s) => s.id == state.storyId);
    if (stories.isEmpty) return const SizedBox.shrink();
    final story = stories.first;
    final total = story.sentencesEn.length;
    if (total == 0) return const SizedBox.shrink();
    final pageIdx = state.storyPageIndex.clamp(0, total - 1);
    final fslUrl = TvCastAssetBridge.storyFslUrl(story, pageIdx);
    if (fslUrl == null) return const SizedBox.shrink();

    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final active = state.storyFslActive;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => notifier.setStoryFsl(!active),
            icon: Icon(
              active
                  ? Icons.stop_circle_rounded
                  : Icons.sign_language_rounded,
            ),
            label: Text(active ? 'Hide FSL' : 'Watch in FSL'),
            style: FilledButton.styleFrom(
              backgroundColor: active
                  ? AppColors.secondaryDark
                  : AppColors.secondary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active
                ? 'Playing the sign-language video on the TV. Tap to go back to '
                      'the story.'
                : 'Play page ${pageIdx + 1} in Filipino Sign Language on the TV.',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _StoryFslReadyStatus(
            key: ValueKey('${story.id}_$pageIdx'),
            cacheKey: TvCastAssetBridge.storyFslCacheKey(story.id, pageIdx),
          ),
        ],
      ),
    );
  }
}

/// "Preparing video… / Ready" status for the current story page's FSL clip.
/// Re-checks the on-device cache every 1.5s until the clip is ready, then stops.
/// Read-only — the notifier prefetches the clip when the page changes; this just
/// reflects whether it's on disk yet (mirrors [_FslReadyStatus] for flashcards).
class _StoryFslReadyStatus extends StatefulWidget {
  final String cacheKey;
  const _StoryFslReadyStatus({super.key, required this.cacheKey});

  @override
  State<_StoryFslReadyStatus> createState() => _StoryFslReadyStatusState();
}

class _StoryFslReadyStatusState extends State<_StoryFslReadyStatus> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final cached = await FslAssetsService.isUrlCached(widget.cacheKey);
    if (!mounted) return;
    setState(() => _ready = cached);
    if (cached) {
      _timer?.cancel();
    } else {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _check(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (_ready) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 14,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(width: 6),
            Text(
              'Ready to play',
              style: AppTypography.labelSmall.copyWith(
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            'Preparing video…',
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Audio controls ────────────────────────────────────

/// Speech master toggle, a TV-vs-phone output selector, and the optional
/// TV-video-sound toggle. With the TV target the TV browser speaks (Web
/// Speech); the phone is the fallback for older TVs.
class _AudioControls extends ConsumerWidget {
  final TvCastSession state;
  const _AudioControls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final ttsEnabled = ref.watch(settingsProvider.select((s) => s.ttsEnabled));
    final onTv = state.castAudioTarget == CastAudioTarget.tv;

    final String narrateSubtitle;
    if (onTv) {
      narrateSubtitle =
          'The TV speaks each word and story page (English + Filipino).';
    } else {
      narrateSubtitle = ttsEnabled
          ? 'This phone reads each word / story page aloud.'
          : 'Turn on Text-to-Speech in Settings to hear this.';
    }

    // Use a Material (not a decorated Container) as the surface so the
    // SwitchListTiles paint their background/ink on it — a Container's opaque
    // colour would otherwise hide those effects (Flutter asserts on this).
    return Material(
      color: hc.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: state.castAudioEnabled,
            onChanged: notifier.setCastAudioEnabled,
            secondary: const Icon(Icons.record_voice_over_rounded),
            title: Text(
              'Speak words & narrate',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            subtitle: Text(
              narrateSubtitle,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
          if (state.castAudioEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Play sound on',
                    style: AppTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: hc.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      _AudioTargetChip(
                        label: 'TV',
                        icon: Icons.tv_rounded,
                        selected: onTv,
                        onTap: () =>
                            notifier.setCastAudioTarget(CastAudioTarget.tv),
                      ),
                      _AudioTargetChip(
                        label: 'This phone',
                        icon: Icons.smartphone_rounded,
                        selected: !onTv,
                        onTap: () =>
                            notifier.setCastAudioTarget(CastAudioTarget.phone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Live status: when routed to the TV, explain whether the TV
                  // is actually speaking (or why it isn't). For the phone, a
                  // simple static line.
                  if (onTv)
                    _TvAudioStatusLine(
                      status: state.tvAudioStatus,
                      hasViewer: state.connectedViewers > 0,
                    )
                  else
                    Text(
                      'Plays from this phone (or a phone-connected speaker).',
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.volume_up_rounded,
                        size: 16,
                        color: hc.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          onTv
                              ? 'Words play at full volume on the TV — raise the '
                                    'TV\'s own volume so every student, including '
                                    'those who need it louder, can hear clearly.'
                              : 'Words play at full volume — use this phone\'s '
                                    'volume buttons to make them louder.',
                          style: AppTypography.bodySmall.copyWith(
                            color: hc.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: hc.textSecondary.withValues(alpha: 0.15)),
          SwitchListTile(
            value: state.tvVideoSoundEnabled,
            onChanged: notifier.setTvVideoSound,
            secondary: const Icon(Icons.volume_up_rounded),
            title: Text(
              'Play TV video sound',
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: hc.textPrimary,
              ),
            ),
            subtitle: Text(
              'Off by default so signs stay muted (Deaf-friendly). Turn on for '
              'signs that include a spoken voiceover. May not work on older TVs.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// One-line status explaining whether the connected TV is actually speaking
/// the words — driven by what the TV reports about its Web Speech ability
/// ([TvCastSession.tvAudioStatus]). Turns silent failures into a clear,
/// actionable message so the teacher knows why the TV is quiet.
class _TvAudioStatusLine extends StatelessWidget {
  final TvAudioStatus status;
  final bool hasViewer;
  const _TvAudioStatusLine({required this.status, required this.hasViewer});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    const green = Color(0xFF2E7D32);
    const amber = Color(0xFFB26A00);

    final (IconData icon, Color color, String text) = !hasViewer
        ? (
            Icons.hourglass_empty_rounded,
            hc.textSecondary,
            'Waiting for a TV to connect…',
          )
        : switch (status) {
            TvAudioStatus.ready => (
                Icons.check_circle_rounded,
                green,
                'The TV is playing the sound.',
              ),
            TvAudioStatus.needsTap => (
                Icons.touch_app_rounded,
                amber,
                'Press OK on the TV remote once to turn on its sound.',
              ),
            TvAudioStatus.unsupported => (
                Icons.warning_amber_rounded,
                amber,
                'This TV can’t speak words. Tap “This phone” to hear narration '
                    'here instead.',
              ),
            TvAudioStatus.unknown => (
                Icons.hourglass_empty_rounded,
                hc.textSecondary,
                'Getting the TV ready… if it stays silent, press OK on the TV '
                    'remote once.',
              ),
          };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A single TV-vs-phone choice chip for the audio-output selector.
class _AudioTargetChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AudioTargetChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      avatar: Icon(
        icon,
        size: 18,
        color: selected ? Colors.white : AppColors.primary,
      ),
      label: Text(label),
      labelStyle: AppTypography.labelMedium.copyWith(
        color: selected ? Colors.white : AppColors.primary,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      onSelected: (_) => onTap(),
    );
  }
}

// ─── Per-word FSL picker ───────────────────────────────

/// Horizontal strip of the selected category's signs that have a video.
/// Tapping one jumps the TV straight to that sign (and pauses autoplay).
class _FslWordPicker extends ConsumerWidget {
  final TvCastSession state;
  const _FslWordPicker({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hc = HCColor.of(context);
    final category = state.category;
    if (category == null) return const SizedBox.shrink();

    final availability = ref.watch(fslAvailabilityProvider).valueOrNull;
    final cards = SeedData.getByCategory(category);

    // Keep the original category index for each card so jumpToSlide targets
    // the same list the cast server renders from.
    final entries = <(int, Flashcard)>[];
    for (var i = 0; i < cards.length; i++) {
      final hasVideo =
          availability?.hasVideo(cards[i]) ??
          FslAssetsService.hasAnyVideoSource(cards[i]);
      if (hasVideo) entries.add((i, cards[i]));
    }

    if (availability == null) {
      return Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading signs…',
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      );
    }

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hc.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hc.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Text(
          'No FSL videos in this category yet.',
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      );
    }

    final notifier = ref.read(tvCastSessionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tap a sign to show it now',
          style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final (cardIndex, card) = entries[i];
              final selected = state.slideIndex == cardIndex;
              return ActionChip(
                avatar: _FslCachedDot(card: card),
                label: Text(card.wordEnglish),
                labelStyle: AppTypography.labelMedium.copyWith(
                  color: selected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: selected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                onPressed: () => notifier.jumpToSlide(cardIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tiny dot showing whether a sign's video is already cached on-device
/// (green) or still needs downloading (grey cloud). Best-effort, evaluated
/// once per build (no polling).
class _FslCachedDot extends StatelessWidget {
  final Flashcard card;
  const _FslCachedDot({required this.card});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: FslAssetsService.isCached(card),
      builder: (context, snap) {
        final cached = snap.data ?? false;
        return Icon(
          cached ? Icons.check_circle_rounded : Icons.cloud_download_rounded,
          size: 16,
          color: cached ? const Color(0xFF4CAF50) : AppColors.primary,
        );
      },
    );
  }
}

// ─── Live "now showing" preview ────────────────────────

/// Mirrors what the TV is currently displaying so the teacher doesn't have to
/// look up at the screen. Lightweight (emoji + text); the TV does the heavy
/// video rendering.
class _CastPreview extends StatelessWidget {
  final TvCastSession state;
  const _CastPreview({required this.state});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: _buildContent(context, hc),
    );
  }

  Widget _buildContent(BuildContext context, HCColor hc) {
    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final category = state.category;
        if (category == null) {
          return _hint('Pick a category to start.', hc);
        }
        final cards = SeedData.getByCategory(category);
        if (cards.isEmpty) return _hint('No words in this category.', hc);
        final idx = state.slideIndex % cards.length;
        final card = cards[idx];
        return Row(
          children: [
            FlashcardPicture(card: card, extent: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.wordEnglish,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hc.textPrimary,
                    ),
                  ),
                  if (card.wordFilipino.isNotEmpty)
                    Text(
                      card.wordFilipino,
                      style: AppTypography.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: hc.textSecondary,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${idx + 1} / ${cards.length}',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                  if (state.mode == CastMode.fslVideo) ...[
                    const SizedBox(height: 6),
                    _FslReadyStatus(card: card),
                  ],
                ],
              ),
            ),
          ],
        );

      case CastMode.story:
        final story = SeedStories.all.where((s) => s.id == state.storyId);
        if (story.isEmpty) return _hint('Pick a story.', hc);
        final s = story.first;
        final total = s.sentencesEn.length;
        final page = state.storyPageIndex.clamp(0, total - 1);
        final finished = state.storyFinished;
        return Row(
          children: [
            Text(
              finished ? '🎉' : s.emoji,
              style: const TextStyle(fontSize: 40),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.titleEn,
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: hc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    finished
                        ? 'Finished — the TV is showing "The End". '
                              'Back re-reads the last page.'
                        : 'Page ${page + 1} / $total',
                    style: AppTypography.labelSmall.copyWith(
                      color: hc.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case CastMode.progress:
        return Row(
          children: [
            const Icon(
              Icons.leaderboard_rounded,
              color: AppColors.primary,
              size: 32,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.progress.isEmpty
                    ? 'Leaderboard — no student data yet.'
                    : 'Leaderboard — top ${state.progress.length} '
                          'student${state.progress.length == 1 ? '' : 's'}.',
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              ),
            ),
          ],
        );

      case CastMode.live:
        return Row(
          children: [
            const Icon(Icons.quiz_rounded, color: AppColors.primary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.liveActivity == null
                    ? 'Live activity — waiting for a question.'
                    : 'Live activity — ${state.liveResponders} answered.',
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              ),
            ),
          ],
        );

      case CastMode.idle:
        return _hint('Nothing is being cast.', hc);
    }
  }

  Widget _hint(String text, HCColor hc) => Text(
    text,
    style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
  );
}

/// "Preparing video… / Ready" status for the current FSL sign. Re-checks the
/// on-device cache every 1.5s until the clip is ready, then stops.
class _FslReadyStatus extends StatefulWidget {
  final Flashcard card;
  const _FslReadyStatus({required this.card});

  @override
  State<_FslReadyStatus> createState() => _FslReadyStatusState();
}

class _FslReadyStatusState extends State<_FslReadyStatus> {
  bool _ready = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void didUpdateWidget(covariant _FslReadyStatus old) {
    super.didUpdateWidget(old);
    if (old.card.id != widget.card.id) {
      _ready = false;
      _timer?.cancel();
      _check();
    }
  }

  Future<void> _check() async {
    final cached = await FslAssetsService.isCached(widget.card);
    if (!mounted) return;
    setState(() => _ready = cached);
    if (cached) {
      _timer?.cancel();
    } else {
      _timer ??= Timer.periodic(
        const Duration(milliseconds: 1500),
        (_) => _check(),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    if (_ready) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: Color(0xFF4CAF50),
          ),
          const SizedBox(width: 6),
          Text(
            'Ready to play',
            style: AppTypography.labelSmall.copyWith(
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 6),
        Text(
          'Preparing video…',
          style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
        ),
      ],
    );
  }
}
