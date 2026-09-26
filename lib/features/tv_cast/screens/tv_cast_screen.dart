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
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/localized_date.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/pro_surface.dart';
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
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';

/// Vertical gap above a section header, and between a header and its content.
///
/// The screen used to space its sections with hand-written 6 / 8 / 10 / 12 /
/// 16 / 20s that no longer agreed with each other, which is what made a page of
/// perfectly good controls read as a pile. These two constants are the whole
/// rhythm, and they match the educator Home's.
const double _sectionGap = AppSpacing.xl;
const double _headerGap = AppSpacing.sm + AppSpacing.xs;

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
        _t(context).tcWifiLost,
      );
    } else if (boundHost != null && ip != boundHost) {
      _showNetworkWarning(
        _t(context).tcNetChanged,
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
        leading: Icon(
          Icons.wifi_off_rounded,
          color: HCColor.of(context).primary,
        ),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          if (showRestart)
            TextButton(
              onPressed: _restartCast,
              child: Text(_t(context).tcRestart),
            ),
          TextButton(
            onPressed: _clearNetworkWarning,
            child: Text(_t(context).lwDismiss),
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
              _t(context).tcNoWifi,
        );
      }
    } catch (e) {
      if (mounted) {
        debugPrint('TV cast start failed: $e');
        AppSnackBar.error(context, message: _t(context).tcStartFailed);
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
        title: Text(_t(context).tcStopTitle),
        content: Text(
          _t(context).tcStopBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t(context).opStop),
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
      AppSnackBar.success(context, message: _t(context).tcStopped);
    }
    // Leave the cast screen so "shutdown" clearly ends the session instead of
    // silently reverting to the Start card on the same page.
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tvCastSessionProvider);
    final padding = context.pagePadding;
    // Gates the on-demand audio replay (phone-side) for Flashcards / Stories.
    final ttsEnabled = ref.watch(settingsProvider.select((s) => s.ttsEnabled));

    return Scaffold(
      appBar: AppBar(
        title: Text(_t(context).tcTitle),
        actions: [
          if (state.isServerRunning) ...[
            // "Teacher is out" — keeps the cast alive so the TV can show the
            // away screen; tap again to resume. Distinct from Stop below.
            IconButton(
              tooltip: state.isAway
                  ? _t(context).tcTeacherBack
                  : _t(context).tcTeacherOut,
              icon: Icon(
                state.isAway
                    ? Icons.coffee_rounded
                    : Icons.directions_walk_rounded,
                color: state.isAway ? HCColor.of(context).primary : null,
              ),
              onPressed: () => ref
                  .read(tvCastSessionProvider.notifier)
                  .setAway(!state.isAway),
            ),
            IconButton(
              tooltip: _t(context).tcStopCasting,
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
                _StartCard(
                  starting: _starting,
                  onStart: _start,
                  error: state.startError,
                ),
                // Only while idle: mid-cast the educator needs the controls,
                // not a look back at last week.
                const _CastHistory(),
              ] else ...[
                if (state.listenUrl != null)
                  TvCastQrCard(
                    url: state.listenUrl!,
                    code: state.castCode,
                  ),
                const SizedBox(height: AppSpacing.md),
                _ViewerCount(count: state.connectedViewers),
                if (state.isAway) ...[
                  const SizedBox(height: AppSpacing.md),
                  const _AwayNotice(),
                ],
                // Every block below follows the educator Home's rhythm: an
                // uppercase section header, one fixed gap, then a grid or a
                // panel of equal-sized blocks — never a loose Wrap. The two
                // gap constants are what keep that rhythm from drifting the
                // way the hand-written 6/8/10/12/16/20s here had.
                const SizedBox(height: _sectionGap),
                _SectionLabel(
                  _t(context).tcWhatToCast,
                  subtitle: _t(context).tcSwitchesNow,
                ),
                const SizedBox(height: _headerGap),
                _ModePicker(state: state),
                const SizedBox(height: AppSpacing.md),
                _ModeConfig(state: state),
                if (state.mode != CastMode.idle &&
                    state.mode != CastMode.live) ...[
                  const SizedBox(height: _sectionGap),
                  _SectionLabel(_t(context).tcNowShowing),
                  const SizedBox(height: _headerGap),
                  _CastPreview(state: state),
                ],
                // Per-cast pacing toggle for the auto-advanceable modes. Lets
                // the educator stop the slideshow timer and step through items
                // manually (or turn it back on).
                if (state.mode == CastMode.flashcards ||
                    state.mode == CastMode.fslVideo ||
                    state.mode == CastMode.story) ...[
                  const SizedBox(height: _sectionGap),
                  _SectionLabel(_t(context).tcPacing),
                  const SizedBox(height: _headerGap),
                  _AutoAdvanceControl(state: state),
                  // Flashcards can also reveal a real photo by tapping the card
                  // on the TV. This toggles that tap-to-flip on/off.
                  if (state.mode == CastMode.flashcards) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _TapOnlyControl(state: state),
                  ],
                ],
                // The Live Activity panel has its own push controls; the
                // prev/pause/next remote only applies to the slide modes.
                if (state.mode != CastMode.idle &&
                    state.mode != CastMode.live) ...[
                  const SizedBox(height: _sectionGap),
                  _SectionLabel(
                    _t(context).tcPlayback,
                    subtitle: _t(context).tcStepLesson,
                  ),
                  const SizedBox(height: _headerGap),
                  TvCastRemoteControls(
                    isPaused: state.isPaused,
                    onPrev: () =>
                        ref.read(tvCastSessionProvider.notifier).prev(),
                    onPlayPause: () =>
                        ref.read(tvCastSessionProvider.notifier).togglePause(),
                    onNext: () =>
                        ref.read(tvCastSessionProvider.notifier).next(),
                  ),
                ],
                // On-demand audio replay for the current word / page, in either
                // language — plays from this phone so the educator can model
                // pronunciation without advancing the slide. (The TV narrates
                // automatically as slides change.)
                if ((state.mode == CastMode.flashcards ||
                        state.mode == CastMode.story) &&
                    ttsEnabled) ...[
                  const SizedBox(height: _sectionGap),
                  _SectionLabel(
                    _t(context).tcReplayAudio,
                    subtitle: state.mode == CastMode.story
                        ? _t(context).tcReplayPage
                        : _t(context).tcReplayWord,
                  ),
                  const SizedBox(height: _headerGap),
                  LanguageReplayBar(
                    onEnglish: () => ref
                        .read(tvCastSessionProvider.notifier)
                        .replayCurrentWord(filipino: false),
                    onFilipino: () => ref
                        .read(tvCastSessionProvider.notifier)
                        .replayCurrentWord(filipino: true),
                  ),
                ],
                const SizedBox(height: _sectionGap),
                _SectionLabel(
                  _t(context).tcDisplayStyle,
                  subtitle: _t(context).tcDisplayStyleSub,
                ),
                const SizedBox(height: _headerGap),
                _TemplateGallery(current: state.castTheme),
                const SizedBox(height: _sectionGap),
                _SectionLabel(_t(context).tcLessonTimer),
                const SizedBox(height: _headerGap),
                _TimerControl(state: state),
                const SizedBox(height: _sectionGap),
                _SectionLabel(_t(context).tcReadability),
                const SizedBox(height: _headerGap),
                _ReadabilityControls(state: state),
                const SizedBox(height: _sectionGap),
                _SectionLabel(
                  _t(context).tcShowOnTv,
                  subtitle: _t(context).tcShowOnTvSub,
                ),
                const SizedBox(height: _headerGap),
                _CastTitleField(state: state),
                const SizedBox(height: _sectionGap),
                _SectionLabel(_t(context).tcAudio),
                const SizedBox(height: _headerGap),
                _AudioControls(state: state),
                const SizedBox(height: _sectionGap),
                _SectionLabel(_t(context).tcFullscreen),
                const SizedBox(height: _headerGap),
                _FullscreenControl(state: state),
                const SizedBox(height: AppSpacing.sm),
                _BigPictureControl(state: state),
                const SizedBox(height: _sectionGap),
                _SectionLabel(_t(context).tcTvRemote),
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

// ─── Shared button shapes ──────────────────────────────
//
// Every action button on this screen is the same rectangle: the pro kit's 12px
// corners and a 14px vertical rhythm, so "Flip to photo", "Show Me", "Watch in
// FSL" and "Prepare Animals" line up as one column of blocks instead of four
// buttons of three different heights and two different radii.

ButtonStyle _castFilledButtonStyle({Color? background}) =>
    FilledButton.styleFrom(
      backgroundColor: background,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      shape: RoundedRectangleBorder(borderRadius: ProSurface.borderRadius),
    );

/// Takes the accent from [HCColor] rather than [AppColors] so the outline
/// follows the high-contrast and dark schemes, like every panel and tile
/// around it. Identical under the default light theme.
ButtonStyle _castOutlinedButtonStyle(HCColor hc) => OutlinedButton.styleFrom(
  foregroundColor: hc.primary,
  side: BorderSide(color: hc.primary.withValues(alpha: 0.4)),
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: 14,
  ),
  shape: RoundedRectangleBorder(borderRadius: ProSurface.borderRadius),
);

// ─── Start card ────────────────────────────────────────

class _StartCard extends StatelessWidget {
  final bool starting;
  final VoidCallback onStart;

  /// Why the last attempt did not start, or null. Shown under the button.
  final String? error;

  const _StartCard({
    required this.starting,
    required this.onStart,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Container(
      padding: AppSpacing.paddingXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.alphaBlend(
              hc.primary.withValues(alpha: 0.12),
              hc.cardBackground,
            ),
            Color.alphaBlend(
              hc.primary.withValues(alpha: 0.04),
              hc.cardBackground,
            ),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: ProSurface.borderRadius,
        border: Border.all(color: hc.primary.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          // A rounded square, not a circle: the same icon badge every tile on
          // this screen and on the educator Home carries.
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hc.primary.withValues(alpha: 0.16),
              borderRadius: ProSurface.borderRadius,
            ),
            child: Icon(Icons.tv_rounded, size: 36, color: hc.primary),
          ),
          const SizedBox(height: 16),
          Text(
            _t(context).tcAnyTv,
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: hc.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _t(context).tcAnyTvBody,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
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
            label: Text(starting ? _t(context).tcStarting : _t(context).tcStart),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: 14,
              ),
              textStyle: AppTypography.titleMedium,
              shape: RoundedRectangleBorder(
                borderRadius: ProSurface.borderRadius,
              ),
            ),
          ),
          // Why nothing happened. Casting needs a shared network, so with
          // Wi-Fi off the attempt cannot succeed — saying that is the whole
          // point of this block; the button used to fail silently.
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: hc.warning.withValues(alpha: 0.12),
                  borderRadius: ProSurface.borderRadius,
                  border: Border.all(
                    color: hc.warning.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 20, color: hc.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: hc.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        // Flexible so the line wraps instead of running off the edge: at a 2.0x
        // font on a 360dp screen "Waiting for TV to connect…" overflowed the row
        // by 97px, and that line is how the teacher knows whether the TV found
        // the cast at all.
        Flexible(
          child: Text(
            count == 0
                ? _t(context).tcWaitingTv
                : _t(context).tcViewers(count),
            style: AppTypography.labelMedium.copyWith(
              color: HCColor.of(context).readable(color),
            ),
          ),
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
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          hc.primary.withValues(alpha: 0.10),
          hc.cardBackground,
        ),
        borderRadius: ProSurface.borderRadius,
        border: Border.all(color: hc.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.coffee_rounded, size: 20, color: hc.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              _t(context).tcTeacherOutNote,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mode picker (tile grid) ───────────────────────────

/// What the TV shows, as the same big two-column tile grid the educator Home
/// uses for Quick Actions — icon badge, bold label, one-line caption.
///
/// Was a `Wrap` of pill chips of five different widths across two ragged rows.
/// This is the screen's primary decision and the thing a teacher hits fastest
/// mid-lesson, so it gets the Home's largest tap targets and its predictable
/// grid, and each option now says what it does rather than only naming itself.
class _ModePicker extends ConsumerWidget {
  final TvCastSession state;
  const _ModePicker({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final modes = <(CastMode, IconData, String, String, Color)>[
      (
        CastMode.flashcards,
        Icons.style_rounded,
        _t(context).tcFlashcards,
        _t(context).tcFlashcardsSub,
        AppColors.sectionLearning,
      ),
      (
        CastMode.fslVideo,
        Icons.sign_language_rounded,
        _t(context).tcFsl,
        _t(context).tcFslSub,
        AppColors.sectionCommunication,
      ),
      (
        CastMode.story,
        Icons.menu_book_rounded,
        _t(context).tcStories,
        _t(context).tcStoriesSub,
        AppColors.info,
      ),
      (
        CastMode.live,
        Icons.quiz_rounded,
        _t(context).tcLiveActivity,
        _t(context).tcLiveActivitySub,
        AppColors.sectionAssessment,
      ),
      (
        CastMode.progress,
        Icons.leaderboard_rounded,
        _t(context).tcProgress,
        _t(context).tcProgressSub,
        AppColors.success,
      ),
    ];
    return ProActionGrid(
      tiles: [
        for (final m in modes)
          ProActionTile(
            icon: m.$2,
            label: m.$3,
            caption: m.$4,
            accent: m.$5,
            selected: state.mode == m.$1,
            onTap: () => notifier.setMode(m.$1),
          ),
      ],
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
          // Without this the button sizes to the selected item's natural width
          // and the longest category name overflowed it — 59px at a 1.3x font on
          // a 600dp tablet, so the card count was cut off the end.
          isExpanded: true,
          decoration: InputDecoration(
            labelText: _t(context).cfCategory,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.category_rounded),
          ),
          items: FlashcardCategory.values
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(
                    '${c.labelOf(_t(context))}  '
                    '(${SeedData.getByCategory(c).length})',
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
              const SizedBox(height: AppSpacing.md),
              _FslWordPicker(state: state),
              _PrewarmControl(
                targetKey: 'cat:${cat.index}',
                targetLabel: cat.labelOf(_t(context)),
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
                targetLabel: cat.labelOf(_t(context)),
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
            labelText: _t(context).tcStory,
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
        return ProPanel(
          padding: AppSpacing.paddingMd,
          child: Text(
            _t(context).tcPickAbove,
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

    return ProPanel(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MiniLabel(
            icon: Icons.format_size_rounded,
            text: _t(context).tcTextSize,
            hc: hc,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Equal-width cells rather than a Wrap: "Normal / Large / Extra
          // large" are three very different lengths, and as chips they made a
          // ragged line that read as three unrelated buttons instead of one
          // three-way choice.
          ProButtonRow(
            minCellWidth: 104,
            children: [
              for (final s in CastTextSize.values)
                _PrefChip(
                  label: s.labelOf(_t(context)),
                  selected: state.castTextSize == s,
                  onTap: () => notifier.setCastTextSize(s),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _t(context).tcTextSizeNote,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          _MiniLabel(
            icon: Icons.translate_rounded,
            text: _t(context).tcLanguage,
            hc: hc,
          ),
          const SizedBox(height: AppSpacing.sm),
          ProButtonRow(
            minCellWidth: 104,
            children: [
              for (final l in CastLanguage.values)
                _PrefChip(
                  label: l.labelOf(_t(context)),
                  selected: state.castLanguage == l,
                  onTap: () => notifier.setCastLanguage(l),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.castLanguage == CastLanguage.both
                ? _t(context).tcBothLangs
                : _t(context).tcOneLang(state.castLanguage.labelOf(_t(context))),
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// A group label *inside* a panel — the uppercase, letter-spaced style the
/// educator Home uses for "Content" / "Assessments & Progress", with a small
/// leading icon. Sits a level below [_SectionLabel] in the hierarchy.
class _MiniLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final HCColor hc;
  const _MiniLabel({required this.icon, required this.text, required this.hc});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: hc.primary),
        const SizedBox(width: AppSpacing.sm),
        // Expanded + ellipsis: "Text size on TV" at a 2.0x font is wider than a
        // 360dp phone's panel once the icon and padding are taken out.
        Expanded(
          child: Text(
            text.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(
              color: hc.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
}

/// One segment of a two- or three-way preference row.
///
/// A rectangle rather than a pill, with the pro kit's 12px corners and
/// hairline border, so it sits in a [ProButtonRow] cell and lines up with the
/// tile grids above it. Stretches to its cell — the label centres and wraps
/// inside, so "Extra large" at a 2.0x font stays in its own column.
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
    final hc = HCColor.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? hc.primary
            : Color.alphaBlend(
                hc.primary.withValues(alpha: 0.06),
                hc.cardBackground,
              ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: ProSurface.borderRadius,
          side: BorderSide(
            color: selected
                ? hc.primary
                : hc.primary.withValues(alpha: 0.25),
            width: selected ? 2 : ProSurface.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 12,
            ),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMedium.copyWith(
                  color: selected ? Colors.white : hc.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: hc.cardBackground,
        borderRadius: ProSurface.borderRadius,
        border: Border.all(
          color: finished
              ? const Color(0xFF2E7D32).withValues(alpha: 0.55)
              : hc.border,
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
                size: 20,
                color: finished ? const Color(0xFF2E7D32) : hc.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  finished ? _t(context).tcReadyOffline : _t(context).tcPrepare,
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
                ? '${_t(context).tcDownloading(prewarm.done + 1, prewarm.total)}'
                      '${prewarm.label.isEmpty ? '' : ' — ${prewarm.label}'}'
                : finished
                ? _doneMessage(context, prewarm)
                : _t(context).tcDownloadAll(targetLabel),
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
          if (running) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: prewarm.fraction,
                minHeight: 8,
                backgroundColor: hc.primary.withValues(alpha: 0.12),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (running)
            OutlinedButton.icon(
              style: _castOutlinedButtonStyle(hc),
              onPressed: notifier.cancel,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text(_t(context).tcStopDownloading),
            )
          else
            FilledButton.icon(
              style: _castFilledButtonStyle(),
              onPressed: prewarm.isRunning ? null : onStart,
              icon: Icon(
                finished ? Icons.refresh_rounded : Icons.download_rounded,
                size: 18,
              ),
              label: Text(finished ? _t(context).tcCheckAgain : _t(context).tcPrepareTarget(targetLabel)),
            ),
        ],
      ),
    );
  }

  String _doneMessage(BuildContext context, TvCastPrewarmState p) {
    final t = _t(context);
    if (p.total == 0) return t.tcNothingToDownload(targetLabel);
    if (p.failed > 0) {
      return t.tcSomeFailed(p.total - p.failed, p.total, p.failed);
    }
    return t.tcAllReady(p.total, targetLabel);
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
    final notifier = ref.read(tvCastSessionProvider.notifier);

    IconData iconFor(CastProgressView v) => v == CastProgressView.classWins
        ? Icons.groups_rounded
        : Icons.leaderboard_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProActionGrid(
          tiles: [
            for (final v in CastProgressView.values)
              ProActionTile(
                icon: iconFor(v),
                label: v.labelOf(_t(context)),
                caption: v.descriptionOf(_t(context)),
                accent: v == CastProgressView.classWins
                    ? AppColors.success
                    : AppColors.warning,
                selected: state.castProgressView == v,
                onTap: () => notifier.setCastProgressView(v),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _PickerNote(
          icon: iconFor(state.castProgressView),
          text: _t(context).tcUpdatesItself(
            state.castProgressView.descriptionOf(_t(context)),
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
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final subtitle = state.fullscreenOnTv
        ? _t(context).tcFsOnNote
        : _t(context).tcFsOffNote;

    return ProSwitchTile(
      icon: Icons.fullscreen_rounded,
      label: _t(context).tcFsOnTv,
      caption: subtitle,
      value: state.fullscreenOnTv,
      onChanged: notifier.setFullscreenOnTv,
    );
  }
}

// ─── Fullscreen picture & video ─────────────────────────

/// Fills the TV with the current picture / GIF / FSL sign clip instead of
/// showing it inside the flashcard (or story) frame.
///
/// The companion to [_FullscreenControl]: that one removes the *browser's*
/// chrome, this one removes the *cast page's*. The category badge, accent strip
/// and example sentence come off and the media grows to roughly 2.5x the width
/// it has in the card, fitted rather than cropped so nothing runs off the
/// edges. The word (and, in a story, the sentence) stay on screen — the point is
/// a bigger picture, not a wordless one.
///
/// Off by default, because it deliberately hides detail some lessons rely on.
/// The switch is disabled in the two modes it cannot help — a live activity and
/// the progress board are text, and blowing up their media would push the answer
/// options off the screen.
class _BigPictureControl extends ConsumerWidget {
  final TvCastSession state;
  const _BigPictureControl({required this.state});

  /// Whether the current cast mode actually shows a picture / clip.
  bool get _appliesToMode =>
      state.mode == CastMode.flashcards ||
      state.mode == CastMode.fslVideo ||
      state.mode == CastMode.story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    final applies = _appliesToMode;

    final String subtitle;
    if (!applies) {
      subtitle =
          _t(context).tcBigPicNa;
    } else if (state.bigPictureOnTv) {
      subtitle =
          _t(context).tcBigPicOn;
    } else {
      subtitle =
          _t(context).tcBigPicOff;
    }

    return ProSwitchTile(
      icon: Icons.zoom_out_map_rounded,
      label: _t(context).tcBigPic,
      caption: subtitle,
      value: state.bigPictureOnTv,
      // Null greys the whole row out (title included) — the caption above then
      // explains which modes it works in.
      onChanged: applies ? notifier.setBigPictureOnTv : null,
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
      padding: const EdgeInsets.only(top: _sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The header's own trailing slot, so "Clear" sits on the header
          // baseline like "View All" does on the educator Home — a Row with a
          // Spacer put it a few pixels off and let a long title shove it out.
          ProSectionHeader(
            title: _t(context).tcRecent,
            trailing: TextButton(
              onPressed: () => _confirmClear(context, ref, profile.id),
              child: Text(_t(context).tcClear),
            ),
          ),
          const SizedBox(height: _headerGap),
          Material(
            color: hc.cardBackground,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: ProSurface.borderRadius,
              side: BorderSide(color: hc.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                      color: hc.border,
                    ),
                  _CastHistoryRow(summary: shown[i]),
                ],
              ],
            ),
          ),
          if (history.length > shown.length) ...[
            const SizedBox(height: 6),
            Text(
              _t(context).tcOlderCasts(history.length - shown.length),
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
        title: Text(_t(context).tcClearTitle),
        content: Text(
          _t(context).tcClearBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_t(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_t(context).tcClear),
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
  String _when(BuildContext context, DateTime? at) {
    final t = _t(context);
    if (at == null) return t.tcEarlier;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    final diff = today.difference(day).inDays;
    if (diff == 0) return t.tcToday('$hh:$mm');
    if (diff == 1) return t.tcYesterday('$hh:$mm');
    return '${LocalizedDate.weekdayShort(at.weekday, t)} '
        '${LocalizedDate.dayMonth(at, t)}';
  }

  String _modeLabel(BuildContext context, CastMode m) => switch (m) {
    CastMode.flashcards => _t(context).tcFlashcards,
    CastMode.fslVideo => _t(context).tcFsl,
    CastMode.story => _t(context).tcStories,
    CastMode.progress => _t(context).tcProgress,
    CastMode.live => _t(context).tcLive,
    CastMode.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final d = summary.duration;
    final mins = d.inMinutes < 1
        ? _t(context).tcUnderMinute
        : _t(context).abMinutes(d.inMinutes);

    final bits = <String>[];
    if (summary.cardsShown > 0) bits.add(_t(context).tcCards(summary.cardsShown));
    if (summary.storyPagesShown > 0) {
      bits.add(_t(context).tcPages(summary.storyPagesShown));
    }
    if (summary.liveQuestionsPushed > 0) {
      bits.add(
        _t(context).tcQsAnswers(summary.liveQuestionsPushed, summary.liveAnswers),
      );
    }

    final modes = summary.modesUsed
        .map((m) => _modeLabel(context, m))
        .where((s) => s.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_rounded, size: 18, color: hc.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_when(context, summary.startedAt)} · $mins',
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

  String _duration(BuildContext context, Duration d) {
    final t = _t(context);
    if (d.inMinutes < 1) return t.tcSeconds(d.inSeconds);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return t.tcHoursMinutes(h, m);
    return t.abMinutes(d.inMinutes);
  }

  String _modeLabel(BuildContext context, CastMode m) => switch (m) {
    CastMode.flashcards => _t(context).tcFlashcards,
    CastMode.fslVideo => _t(context).tcFslSigns,
    CastMode.story => _t(context).tcStories,
    CastMode.progress => _t(context).tcProgress,
    CastMode.live => _t(context).tcLiveActivity,
    CastMode.idle => '',
  };

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    final rows = <(IconData, String)>[
      (
        Icons.schedule_rounded,
        _t(context).tcOfCasting(_duration(context, summary.duration)),
      ),
      if (summary.modesUsed.isNotEmpty)
        (
          Icons.cast_rounded,
          summary.modesUsed.map((m) => _modeLabel(context, m)).join(' · '),
        ),
      if (summary.cardsShown > 0)
        (Icons.style_rounded, _t(context).tcCardsSigns(summary.cardsShown)),
      if (summary.storyPagesShown > 0)
        (Icons.menu_book_rounded, _t(context).tcStoryPages(summary.storyPagesShown)),
      if (summary.liveQuestionsPushed > 0)
        (
          Icons.quiz_rounded,
          _t(context).tcLiveQs(summary.liveQuestionsPushed, summary.liveAnswers),
        ),
      if (summary.peakViewers > 0)
        (
          Icons.tv_rounded,
          _t(context).tcTvsAtOnce(summary.peakViewers),
        ),
    ];

    return AlertDialog(
      title: Text(_t(context).tcLessonCast),
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
                  Icon(icon, size: 18, color: hc.primary),
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
          child: Text(_t(context).done),
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

  static const _presets = [1, 3, 5, 10];

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

    // The four presets, as equal-width cells on one line (two lines on a
    // narrow phone). They were a Wrap, so "1 min" and "10 min" drew different
    // widths and the row read as four unrelated buttons rather than one scale.
    final presetRow = ProButtonRow(
      minCellWidth: 96,
      children: [
        for (final p in _presets)
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: hc.primary,
              side: BorderSide(
                color: hc.primary.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: ProSurface.borderRadius,
              ),
            ),
            onPressed: () =>
                notifier.startTimer(Duration(minutes: p)),
            child: Text(
              _t(context).abMinutes(p),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );

    return ProPanel(
      padding: AppSpacing.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // No inner label here: the "Lesson timer" section header sits
          // directly above this panel, and printing it twice is what the
          // uppercase headers were meant to remove.
          if (left == null) ...[
            Text(
              _t(context).tcTimerNote,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            presetRow,
          ] else ...[
            Row(
              children: [
                // Flexible + FittedBox: at a 2.0x font "Time’s up" plus the
                // two icon buttons is wider than a 360dp panel.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      finished ? _t(context).tcTimesUp : _clock(left),
                      maxLines: 1,
                      style: AppTypography.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: finished
                            ? const Color(0xFFC62828)
                            : hc.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                if (paused && !finished) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'paused',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: hc.textSecondary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (!finished)
                  IconButton(
                    tooltip: paused ? _t(context).tcResumeTimer : _t(context).tcPauseTimer,
                    onPressed: paused
                        ? notifier.resumeTimer
                        : notifier.pauseTimer,
                    icon: Icon(
                      paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    ),
                  ),
                IconButton(
                  tooltip: _t(context).tcClearTimer,
                  onPressed: notifier.clearTimer,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              finished
                  ? _t(context).tcTimesUpNote
                  : _t(context).tcTimerShowing,
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            presetRow,
          ],
        ],
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
    final notifier = ref.read(tvCastSessionProvider.notifier);

    return ProSwitchTile(
      icon: Icons.settings_remote_rounded,
      label: _t(context).tcRemoteLabel,
      value: state.tvRemoteEnabled,
      onChanged: notifier.setTvRemoteEnabled,
      caption: state.tvRemoteEnabled
          ? _t(context).tcRemoteOn
          : _t(context).tcRemoteOff,
    );
  }
}

// ─── Troubleshoot panel ────────────────────────────────

class _TroubleshootPanel extends StatelessWidget {
  const _TroubleshootPanel();

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    // Boxed in the pro kit's hairline card so the last block on the screen has
    // the same edge as everything above it — an unboxed ExpansionTile floated
    // on the background and read as an afterthought.
    return Material(
      color: hc.cardBackground,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: ProSurface.borderRadius,
        side: BorderSide(color: hc.border),
      ),
      child: ExpansionTile(
        // "Troubleshooting" is one 15-character word, and an ExpansionTile
        // title sits between a leading icon and the expand arrow — the
        // narrowest kind of text box in the app. At a 2.0x font on a 360dp
        // screen it wrapped INSIDE the word ("Troubleshoot / ing"), which is
        // the one thing a learner or educator reading at 2.0x cannot afford.
        // Shorter, and plainer English for this audience besides. See the
        // game-card titles for the same shape.
        title: Text(
          _t(context).tcTrouble,
          style: AppTypography.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            color: hc.textPrimary,
          ),
        ),
        // The tile paints its own divider lines, which would double up with
        // the card's border now that it's boxed.
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.help_outline_rounded),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          _Tip(text: _t(context).tcTipSameWifi),
          _Tip(
            text:
                _t(context).tcTipApIsolation,
          ),
          _Tip(text: _t(context).tcTipSamsung),
          _Tip(text: _t(context).tcTipLg),
          _Tip(text: _t(context).tcTipFire),
          _Tip(
            text:
                _t(context).tcTipChromecast,
          ),
          _Tip(
            text: _t(context).tcTipApple,
          ),
          _Tip(
            text:
                _t(context).tcTipFullscreen,
          ),
          _Tip(
            text:
                _t(context).tcTipLeave,
          ),
          _Tip(
            text:
                _t(context).tcTipPrivate,
          ),
          _Tip(
            text:
                _t(context).tcTipQuiet,
          ),
        ],
      ),
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

/// The screen's one section heading, matching the educator Home's
/// [ProSectionHeader] (uppercase, letter-spaced, optional one-line subtitle)
/// rather than the playful sentence-case titles of the learner surfaces — this
/// is a teacher/parent screen and should read as part of that dashboard.
class _SectionLabel extends StatelessWidget {
  final String text;
  final String? subtitle;
  const _SectionLabel(this.text, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ProSectionHeader(title: text, subtitle: subtitle);
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
  CastTheme.dyslexia: (Icons.menu_book_rounded, Color(0xFFFAF0D7)),
};

class _TemplateGallery extends ConsumerWidget {
  final CastTheme current;
  const _TemplateGallery({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(tvCastSessionProvider.notifier);
    // Surface classroom first (the recommended lit-room default), then the
    // rest, with the two accessibility templates last as a pair.
    const order = [
      CastTheme.classroom,
      CastTheme.dark,
      CastTheme.light,
      CastTheme.playful,
      CastTheme.calm,
      CastTheme.seasonal,
      CastTheme.highContrast,
      CastTheme.dyslexia,
    ];
    // Eight full-width stacked rows used to run past two screen-heights on
    // their own. As the Home's compact "More" grid they fit in three rows and
    // stay comparable side by side, which is how you actually choose a look.
    //
    // `caption` is still passed on these compact tiles: it is hidden visually
    // (that's what compact means) but [ProActionTile] still speaks it, so a
    // screen-reader user keeps the full "Crisp and neutral — maximum
    // readability" description that the old stacked rows showed. Sighted users
    // get it for the current choice in the note below the grid.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProActionGrid(
          compact: true,
          tiles: [
            for (final t in order)
              ProActionTile(
                compact: true,
                icon: _templateStyle[t]?.$1 ?? Icons.tv_rounded,
                label: t.labelOf(_t(context)),
                caption: t.descriptionOf(_t(context)),
                accent: _templateSwatchFor(context, t),
                selected: current == t,
                onTap: () => notifier.setCastTheme(t),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _PickerNote(
          icon: _templateStyle[current]?.$1 ?? Icons.tv_rounded,
          text:
              '${current.labelOf(_t(context))} — '
              '${current.descriptionOf(_t(context))}',
        ),
      ],
    );
  }
}

/// A one-line explanation of the option currently chosen in a picker above it.
///
/// Shared by the display-style and progress-view grids so the compact tiles can
/// stay short without losing the sentence that tells a teacher what they just
/// picked. Marked as a live region: the text is the only feedback for a change
/// made two taps up the screen.
class _PickerNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PickerNote({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final hc = HCColor.of(context);
    return Semantics(
      liveRegion: true,
      child: ProPanel(
        padding: AppSpacing.paddingMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: hc.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: AppTypography.bodySmall.copyWith(
                  color: hc.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The swatch colour for a template's tile accent.
///
/// The raw swatches are what the *TV* looks like, so two of them (Light's near
/// white, High contrast's black) have no contrast against one or other app
/// theme's card. Those two fall back to a readable neutral, since the tile's
/// job is to be legible on the tablet — the description is what promises the
/// look on the TV.
Color _templateSwatchFor(BuildContext context, CastTheme theme) {
  final hc = HCColor.of(context);
  final swatch = _templateStyle[theme]?.$2 ?? hc.primary;
  return switch (theme) {
    CastTheme.light || CastTheme.dyslexia => hc.isDark ? swatch : hc.primary,
    CastTheme.dark || CastTheme.highContrast => hc.isDark
        ? hc.textSecondary
        : swatch,
    _ => swatch,
  };
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
        hintText: _t(context).tcNameHint,
        prefixIcon: const Icon(Icons.badge_rounded),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: _t(context).tcClear,
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
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final noun = switch (state.mode) {
      CastMode.story => _t(context).tcNounPage,
      CastMode.fslVideo => _t(context).tcNounSign,
      _ => _t(context).tcNounCard,
    };
    final subtitle = state.autoAdvanceEnabled
        ? _t(context).tcAdvanceOn(noun)
        : _t(context).tcAdvanceOff(noun);

    return ProSwitchTile(
      icon: Icons.slideshow_rounded,
      label: _t(context).tcAutoAdvance,
      caption: subtitle,
      value: state.autoAdvanceEnabled,
      onChanged: notifier.setAutoAdvanceEnabled,
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
    final notifier = ref.read(tvCastSessionProvider.notifier);

    final subtitle = state.flipTapOnly
        ? _t(context).tcTapOnlyOn
        : _t(context).tcTapOnlyOff;

    return ProSwitchTile(
      icon: Icons.touch_app_rounded,
      label: _t(context).tcTapOnly,
      caption: subtitle,
      value: state.flipTapOnly,
      onChanged: notifier.setFlipTapOnly,
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: notifier.flipCard,
            icon: const Icon(Icons.flip_rounded),
            label: Text(flipped ? _t(context).tcShowEmoji : _t(context).tcFlipPhoto),
            style: _castOutlinedButtonStyle(hc),
          ),
          const SizedBox(height: 6),
          Text(
            flipped
                ? _t(context).tcPhotoShowing
                : _t(context).tcFlipWord(card.wordEnglish),
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
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
            label: Text(active ? _t(context).tcHideClip : _t(context).tcShowMe),
            style: _castFilledButtonStyle(
              background: active
                  ? AppColors.secondaryDark
                  : AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active
                ? _t(context).tcClipPlaying
                : _t(context).tcPlayClip(card.wordEnglish),
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: notifier.flipStoryImage,
            icon: const Icon(Icons.flip_rounded),
            label: Text(_t(context).tcFlipAnim),
            style: _castOutlinedButtonStyle(hc),
          ),
          const SizedBox(height: 6),
          Text(
            showingReal
                ? _t(context).tcPictureShowing
                : _t(context).tcCartoonShowing,
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
      padding: const EdgeInsets.only(top: AppSpacing.md),
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
            label: Text(active ? _t(context).tcHideFsl : _t(context).tcWatchFsl),
            style: _castFilledButtonStyle(
              background: active
                  ? AppColors.secondaryDark
                  : AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active
                ? _t(context).tcFslPlaying
                : _t(context).tcPlayPageFsl(pageIdx + 1),
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
            // Flexible for the same reason as its flashcard twin below: the
            // row overflowed a narrow phone at a 2.0x font.
            Flexible(
              child: Text(
                _t(context).tcReadyToPlay,
                style: AppTypography.labelSmall.copyWith(
                  color: HCColor.of(context).readableOver(const Color(0xFF4CAF50), const Color(0xFF4CAF50).withValues(alpha: 0.15)),
                ),
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
          Flexible(
            child: Text(
              _t(context).tcPreparingVideo,
              style: AppTypography.labelSmall.copyWith(
                color: hc.textSecondary,
              ),
            ),
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
          _t(context).tcTvSpeaks;
    } else {
      narrateSubtitle = ttsEnabled
          ? _t(context).tcPhoneReads
          : _t(context).tcTurnOnTts;
    }

    // One bordered panel holding both switches and the output picker, so the
    // whole of "Audio" reads as a single block on the educator surface rather
    // than three cards of three different shapes. `standalone: false` on the
    // switches suppresses their own borders inside it.
    return ProPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ProSwitchTile(
            standalone: false,
            icon: Icons.record_voice_over_rounded,
            label: _t(context).tcSpeakWords,
            caption: narrateSubtitle,
            value: state.castAudioEnabled,
            onChanged: notifier.setCastAudioEnabled,
          ),
          if (state.castAudioEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MiniLabel(
                    icon: Icons.speaker_rounded,
                    text: _t(context).tcPlaySoundOn,
                    hc: hc,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Two equal cells: "TV" and "This phone" are wildly different
                  // lengths, so as chips the pair looked like a small button
                  // beside a big one rather than one either/or choice.
                  ProButtonRow(
                    minCellWidth: 120,
                    maxPerRow: 2,
                    children: [
                      _AudioTargetChip(
                        label: 'TV',
                        icon: Icons.tv_rounded,
                        selected: onTv,
                        onTap: () =>
                            notifier.setCastAudioTarget(CastAudioTarget.tv),
                      ),
                      _AudioTargetChip(
                        label: _t(context).tcThisPhone,
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
                      _t(context).tcPhoneSound,
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
                              ? _t(context).tcTvVolume
                              : _t(context).tcPhoneVolume,
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
          Divider(height: 1, color: hc.border),
          ProSwitchTile(
            standalone: false,
            icon: Icons.volume_up_rounded,
            label: _t(context).tcVideoSound,
            caption:
                _t(context).tcVideoSoundNote,
            value: state.tvVideoSoundEnabled,
            onChanged: notifier.setTvVideoSound,
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
            _t(context).tcWaitingATv,
          )
        : switch (status) {
            TvAudioStatus.ready => (
                Icons.check_circle_rounded,
                green,
                _t(context).tcTvPlaying,
              ),
            TvAudioStatus.needsTap => (
                Icons.touch_app_rounded,
                amber,
                _t(context).tcPressOk,
              ),
            TvAudioStatus.unsupported => (
                Icons.warning_amber_rounded,
                amber,
                _t(context).tcTvCantSpeak,
              ),
            TvAudioStatus.unknown => (
                Icons.hourglass_empty_rounded,
                hc.textSecondary,
                _t(context).tcTvGettingReady,
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

/// A single TV-vs-phone segment for the audio-output selector — the same
/// rectangle as [_PrefChip], with a leading icon.
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
    final hc = HCColor.of(context);
    final fg = selected ? Colors.white : hc.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? hc.primary
            : Color.alphaBlend(
                hc.primary.withValues(alpha: 0.06),
                hc.cardBackground,
              ),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: ProSurface.borderRadius,
          side: BorderSide(
            color: selected
                ? hc.primary
                : hc.primary.withValues(alpha: 0.25),
            width: selected ? 2 : ProSurface.borderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.sm),
                // Flexible, not Expanded: the icon + label stay centred as a
                // pair, and "This phone" still wraps inside its own cell at a
                // 2.0x font instead of running under the icon.
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMedium.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
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
            _t(context).tcLoadingSigns,
            style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
          ),
        ],
      );
    }

    if (entries.isEmpty) {
      return ProPanel(
        padding: AppSpacing.paddingMd,
        child: Text(
          _t(context).tcNoFsl,
          style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
        ),
      );
    }

    final notifier = ref.read(tvCastSessionProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t(context).tcTapSign,
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
                  color: selected ? Colors.white : hc.primary,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: selected
                    ? hc.primary
                    : hc.primary.withValues(alpha: 0.08),
                // Squared off to match the rest of the screen. This strip
                // stays a horizontal scroller rather than a grid: a category
                // can carry a dozen signs, and a grid of them would push the
                // controls below off the screen.
                shape: RoundedRectangleBorder(
                  borderRadius: ProSurface.borderRadius,
                  side: BorderSide(
                    color: selected
                        ? hc.primary
                        : hc.primary.withValues(alpha: 0.25),
                    width: selected ? 2 : ProSurface.borderWidth,
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
          color: cached
              ? const Color(0xFF4CAF50)
              : HCColor.of(context).primary,
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
    return ProPanel(
      padding: AppSpacing.paddingMd,
      child: _buildContent(context, hc),
    );
  }

  Widget _buildContent(BuildContext context, HCColor hc) {
    switch (state.mode) {
      case CastMode.flashcards:
      case CastMode.fslVideo:
        final category = state.category;
        if (category == null) {
          return _hint(_t(context).tcPickCategory, hc);
        }
        final cards = SeedData.getByCategory(category);
        if (cards.isEmpty) return _hint(_t(context).tcNoWords, hc);
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
        if (story.isEmpty) return _hint(_t(context).tcPickStory, hc);
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
                        ? _t(context).tcFinished
                        : _t(context).tcPageOf(page + 1, total),
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
            Icon(Icons.leaderboard_rounded, color: hc.primary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.progress.isEmpty
                    ? _t(context).tcNoLeaderboard
                    : _t(context).tcLeaderboardTop(state.progress.length),
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              ),
            ),
          ],
        );

      case CastMode.live:
        return Row(
          children: [
            Icon(Icons.quiz_rounded, color: hc.primary, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                state.liveActivity == null
                    ? _t(context).tcLiveWaiting
                    : _t(context).tcLiveAnswered(state.liveResponders),
                style: AppTypography.bodyMedium.copyWith(color: hc.textPrimary),
              ),
            ),
          ],
        );

      case CastMode.idle:
        return _hint(_t(context).tcNothingCast, hc);
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
          // Flexible so the label wraps instead of running off the card: at a
          // 2.0x font on a 360dp phone this row overflowed by 58px, and it is
          // how the teacher knows the sign clip is downloaded.
          Flexible(
            child: Text(
              _t(context).tcReadyToPlay,
              style: AppTypography.labelSmall.copyWith(
                color: HCColor.of(context).readableOver(const Color(0xFF4CAF50), const Color(0xFF4CAF50).withValues(alpha: 0.15)),
              ),
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
        Flexible(
          child: Text(
            _t(context).tcPreparingVideo,
            style: AppTypography.labelSmall.copyWith(color: hc.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
