import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/flashcard_emojis.dart';
import '../../../core/services/fsl_assets_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_snack_bar.dart';
import '../models/tv_cast_session.dart';
import '../providers/tv_cast_provider.dart';
import '../services/tv_cast_ip_discovery.dart';
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
    try {
      await ref.read(tvCastSessionProvider.notifier).stopServer();
    } catch (_) {
      // The session state still resets even if closing the socket throws.
    }
    if (!mounted) return;
    AppSnackBar.success(context, message: 'Casting stopped');
    // Leave the cast screen so "shutdown" clearly ends the session instead of
    // silently reverting to the Start card on the same page.
    if (router.canPop()) router.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tvCastSessionProvider);
    final hc = HCColor.of(context);
    final padding = context.pagePadding;

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
              if (!state.isServerRunning)
                _StartCard(starting: _starting, onStart: _start)
              else ...[
                if (state.listenUrl != null)
                  TvCastQrCard(url: state.listenUrl!),
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
                const SizedBox(height: 20),
                const _SectionLabel('TV display style'),
                const SizedBox(height: 10),
                _TemplateGallery(current: state.castTheme),
                const SizedBox(height: 16),
                const _SectionLabel('Show on TV'),
                const SizedBox(height: 8),
                _CastTitleField(state: state),
                const SizedBox(height: 20),
                const _SectionLabel('Audio'),
                const SizedBox(height: 6),
                _AudioControls(state: state),
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
            'or any laptop plugged into HDMI.',
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dropdown,
              const SizedBox(height: 12),
              _FslWordPicker(state: state),
            ],
          );
        }
        return dropdown;

      case CastMode.story:
        final all = SeedStories.all;
        return DropdownButtonFormField<String>(
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

      case CastMode.progress:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.leaderboard_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Showing the top 10 students by stars. Tap Next to refresh.',
                  style: AppTypography.bodySmall.copyWith(
                    color: hc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );

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
              'Keep this screen open while casting — the server runs from '
              'this screen.',
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
                  const SizedBox(height: 6),
                  Text(
                    onTv
                        ? 'On older TVs, press OK once to allow sound — or '
                              'switch to This phone.'
                        : 'Plays from this phone (or a phone-connected speaker).',
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
                              ? 'Speech is at max volume — turn up the TV\'s '
                                    'volume to make it louder.'
                              : 'Speech is at max volume — use this phone\'s '
                                    'volume buttons to make it louder.',
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
              'For signs that include a voiceover. May not work on older TVs.',
              style: AppTypography.bodySmall.copyWith(color: hc.textSecondary),
            ),
          ),
        ],
      ),
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
            Text(
              FlashcardEmojis.forId(card.id),
              style: const TextStyle(fontSize: 40),
            ),
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
        return Row(
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 40)),
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
                    'Page ${page + 1} / $total',
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
