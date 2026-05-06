import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// A global connectivity banner that slides down from the top when the
/// device goes offline and auto-dismisses when connectivity returns.
///
/// Designed to be used inside [MaterialApp.builder] so it overlays
/// all routes without requiring individual screen modifications.
class ConnectivityBanner extends StatefulWidget {
  final Widget child;

  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1), // hidden above screen
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    // Check initial state
    _checkInitialConnectivity();

    // Listen for changes
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _onConnectivityChanged(results);
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.every((r) => r == ConnectivityResult.none);
    if (offline != _isOffline) {
      setState(() => _isOffline = offline);
      if (offline) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual app content
        widget.child,

        // Animated offline banner
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 20, color: HCColor.of(context).textPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'You\'re offline \u2014 everything still works!',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: HCColor.of(context).textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
