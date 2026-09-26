import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/connectivity_state.dart';
import '../core/utils/reduced_motion.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';

/// Compact connectivity status indicator for app bars and headers.
///
/// Shows a small animated icon that reflects the current network state:
/// - **Online**: hidden (no visual clutter when everything is fine)
/// - **Offline**: pulsing wifi-off icon with an optional tooltip
///
/// Designed to sit alongside other icon buttons in a Row.
class ConnectivityIndicator extends StatefulWidget {
  /// When true, always show the indicator (green dot when online).
  /// When false (default), only show when offline.
  final bool showWhenOnline;

  const ConnectivityIndicator({super.key, this.showWhenOnline = false});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator>
    with SingleTickerProviderStateMixin {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _isOffline = false;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    _onChanged(results);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = isOfflineForDisplay(results);
    // The pulse is started and stopped in build now, from `_isOffline` and
    // the live setting together — this only has to record the state. Doing it
    // here meant the loop could not react to Reduced Motion being toggled
    // while the device stayed offline.
    if (offline != _isOffline) {
      setState(() => _isOffline = offline);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Offline is the only state that pulses; `restAt: 0` keeps the old
    // behaviour of settling the icon back to rest when it stops.
    _pulseController.syncMotionLoop(
      ReducedMotionScope.of(context) || !_isOffline,
      reverse: true,
      restAt: 0,
    );
    if (!_isOffline && !widget.showWhenOnline) {
      return const SizedBox.shrink();
    }

    if (!_isOffline && widget.showWhenOnline) {
      return Tooltip(
        message: _t(context).ciOnline,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(
            Icons.wifi_rounded,
            size: 20,
            color: AppColors.success.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Offline state — pulsing icon
    return Tooltip(
      message: _t(context).ciOffline,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Opacity(
            opacity: 0.5 + (_pulseController.value * 0.5),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: HCColor.of(context).graphic(AppColors.warning),
                ),
                const SizedBox(width: 4),
                Text(
                  _t(context).csxOffline,
                  style: AppTypography.labelSmall.copyWith(
                    color: HCColor.of(context).warningText,
                    fontWeight: FontWeight.w700,
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

/// `AppLocalizations.of` is nullable here, and a screen pumped in a test
/// without the delegate would otherwise throw.
AppLocalizations _t(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();
