import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/achievements.dart';
import '../../../providers/app_providers.dart' show profileProvider;
import '../../../widgets/achievement_overlay.dart';
import '../controllers/gaze_controller.dart';
import '../logic/gaze_focus_driver.dart';
import '../models/gaze_models.dart';
import '../models/gaze_settings.dart';
import '../providers/gaze_camera_owners.dart';
import '../providers/gaze_home_grid.dart';
import '../providers/gaze_settings_provider.dart';
import '../widgets/voice_control_mixin.dart';

/// **Debug-only** remote control for Gaze Control, so the whole feature can be
/// exercised on a real tablet without a person moving their head in front of
/// it: the VM-service extension `ext.flashlearn.gaze`.
///
/// It stands in for the learner, not for the code under test. A `look` or
/// `pose` replaces the head pose the camera saw — raw angles, before the
/// learner's calibration — and the real resolver, hold timer, sensitivity and
/// blink detector all run on it, frame by frame, exactly as for a learner.
/// `zone` / `blink` skip the hold for speed; `voice` delivers a phrase as if
/// the recogniser had heard it; `state` reports what every scope, the hub
/// grid and the focus ring are doing, so a test can assert without a
/// screenshot.
///
/// Registered from `main` only when not in release mode; release builds have
/// no VM service and compile all of this out.
abstract final class GazeDebugBridge {
  static bool _installed = false;
  static ({double yaw, double pitch, double leftEye, double rightEye})? _pose;
  static DateTime? _poseUntil;

  /// While on, the camera's own view is replaced by a still, eyes-open head
  /// between injected gestures — so a person who happens to be in front of
  /// the tablet (looking at a laptop beside it, say) cannot move anything
  /// during a scripted run.
  static bool _hold = false;
  static const _neutral = (yaw: 0.0, pitch: 0.0, leftEye: 1.0, rightEye: 1.0);

  /// Set by the navigation shell (debug builds only): shows its real level-up
  /// celebration for [level], so the overlay can be tested by gaze without
  /// awarding a learner XP they can never lose again.
  static void Function(int level)? levelUpHook;

  /// [contextOf] returns a context under the app's `ProviderScope` and router
  /// (the root navigator's), read fresh on every call.
  static void install({required BuildContext? Function() contextOf}) {
    if (kReleaseMode || _installed) return;
    _installed = true;
    GazeController.debugPoseSource = _currentPose;
    developer.registerExtension('ext.flashlearn.gaze', (method, params) async {
      try {
        final result = _handle(params, contextOf());
        return developer.ServiceExtensionResponse.result(jsonEncode(result));
      } catch (e) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          '$e',
        );
      }
    });
  }

  static ({double yaw, double pitch, double leftEye, double rightEye})?
  _currentPose() {
    final until = _poseUntil;
    if (_pose != null && until != null) {
      if (!DateTime.now().isAfter(until)) return _pose;
      _pose = null;
      _poseUntil = null;
    }
    return _hold ? _neutral : null;
  }

  static double _num(Map<String, String> p, String key, double fallback) =>
      double.tryParse(p[key] ?? '') ?? fallback;

  static GazeController? get _newestController =>
      GazeController.debugLive.isEmpty ? null : GazeController.debugLive.last;

  static Map<String, Object?> _handle(
    Map<String, String> p,
    BuildContext? context,
  ) {
    final cmd = p['cmd'] ?? 'state';
    switch (cmd) {
      case 'state':
        return _state(context);
      case 'pose':
        // Raw ML Kit angles: yaw = headEulerAngleY, pitch = headEulerAngleX.
        _setPose(
          yaw: _num(p, 'yaw', 0),
          pitch: _num(p, 'pitch', 0),
          leftEye: _num(p, 'left', 1),
          rightEye: _num(p, 'right', 1),
          ms: _num(p, 'ms', 2500).round(),
        );
        return {'ok': true};
      case 'look':
        // The learner's own direction, turned into the raw pose the camera
        // would report under the *current* calibration.
        final settings = _settingsOf(context);
        final deg = _num(p, 'deg', 30);
        final dir = p['dir'] ?? 'none';
        final mirror = settings?.mirrorHorizontal ?? true;
        final invert = settings?.invertVertical ?? false;
        final turn = switch (dir) {
          'left' => -deg,
          'right' => deg,
          _ => 0.0,
        };
        final tilt = switch (dir) {
          'up' => deg,
          'down' => -deg,
          _ => 0.0,
        };
        _setPose(
          yaw: mirror ? -turn : turn,
          pitch: invert ? -tilt : tilt,
          leftEye: 1,
          rightEye: 1,
          ms: _num(p, 'ms', 2500).round(),
        );
        return {'ok': true, 'turn': turn, 'tilt': tilt};
      case 'closeEyes':
        // A real long blink: eyes shut, head still, for long enough that the
        // blink detector's hold completes.
        _setPose(
          yaw: 0,
          pitch: 0,
          leftEye: 0.02,
          rightEye: 0.02,
          ms: _num(p, 'ms', 900).round(),
        );
        return {'ok': true};
      case 'clear':
        _pose = null;
        _poseUntil = null;
        return {'ok': true};
      case 'hold':
        _hold = p['on'] != '0';
        return {'ok': true, 'hold': _hold};
      case 'zone':
        final controller = _newestController;
        if (controller == null) return {'ok': false, 'error': 'no camera'};
        final zone = GazeZone.values.firstWhere(
          (z) => z.name == p['zone'],
          orElse: () => GazeZone.none,
        );
        controller.debugSelect(zone);
        return {'ok': true, 'zone': zone.name};
      case 'blink':
        final controller = _newestController;
        if (controller == null) return {'ok': false, 'error': 'no camera'};
        return {'ok': controller.debugBlink()};
      case 'voice':
        final text = p['text'] ?? '';
        final force = p['force'] == '1';
        final scopes = VoiceControlMixin.debugScopes
            .where((s) => s.mounted && (force || s.voiceActive))
            .toList();
        if (scopes.isEmpty) return {'ok': false, 'error': 'nobody listening'};
        final scope = scopes.last;
        scope.onVoiceCommand(text);
        return {'ok': true, 'to': '${scope.runtimeType}'};
      case 'overlay':
        // The two in-screen celebrations, shown for real but without changing
        // anyone's progress: the shell's level-up overlay, and a game-result
        // style page with the achievement card over its buttons.
        switch (p['kind']) {
          case 'levelup':
            final hook = levelUpHook;
            if (hook == null) return {'ok': false, 'error': 'no shell'};
            hook(int.tryParse(p['level'] ?? '') ?? 2);
            return {'ok': true};
          case 'achievement':
            if (context == null) return {'ok': false, 'error': 'no context'};
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const _DebugResultPage()),
            );
            return {'ok': true};
          default:
            return {'ok': false, 'error': 'kind = levelup | achievement'};
        }
      case 'settings':
        if (context == null) return {'ok': false, 'error': 'no context'};
        final container = ProviderScope.containerOf(context, listen: false);
        final notifier = container.read(gazeSettingsProvider.notifier);
        final current = container.read(gazeSettingsProvider).toMap();
        final patch = (jsonDecode(p['json'] ?? '{}') as Map)
            .cast<String, Object?>();
        notifier.update(GazeSettings.fromMap({...current, ...patch}));
        return {
          'ok': true,
          'settings': container.read(gazeSettingsProvider).toMap(),
        };
      default:
        return {'ok': false, 'error': 'unknown cmd $cmd'};
    }
  }

  static void _setPose({
    required double yaw,
    required double pitch,
    required double leftEye,
    required double rightEye,
    required int ms,
  }) {
    _pose = (yaw: yaw, pitch: pitch, leftEye: leftEye, rightEye: rightEye);
    _poseUntil = DateTime.now().add(Duration(milliseconds: ms));
  }

  static GazeSettings? _settingsOf(BuildContext? context) {
    if (context == null) return null;
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(gazeSettingsProvider);
  }

  static Map<String, Object?> _state(BuildContext? context) {
    String? location;
    Map<String, Object?>? profile;
    Map<String, Object?>? settings;
    if (context != null) {
      try {
        location = GoRouter.of(context).state.uri.toString();
      } catch (_) {}
      final container = ProviderScope.containerOf(context, listen: false);
      final p = container.read(profileProvider);
      if (p != null) {
        profile = {
          'id': p.id,
          'name': p.name,
          'role': p.role.name,
          'disability': p.disabilityType.name,
          'guest': p.isGuestPlayer,
        };
      }
      settings = container.read(gazeSettingsProvider).toMap();
    }
    final focus = GazeFocusDriver.focused;
    final rect = GazeFocusDriver.focusedRect;
    return {
      'location': location,
      'hold': _hold,
      'profile': profile,
      'settings': settings,
      'cameraOwners': gazeCameraOwners.count,
      'controllers': [
        for (final c in GazeController.debugLive) c.debugDescribe(),
      ],
      'scopes': [
        for (final s in VoiceControlMixin.debugScopes)
          if (s.mounted) {...s.debugDescribe(), 'voice': s.voiceActive},
      ],
      'grid': {
        'rows': [
          for (final row in gazeHomeGrid.rows) [for (final c in row) c.label],
        ],
        'focus': [gazeHomeGrid.focusRow, gazeHomeGrid.focusCol],
      },
      'focus': focus == null
          ? null
          : {
              'node': focus.debugLabel ?? '${focus.runtimeType}',
              'text': _textUnder(focus.context),
              'label': _semanticsLabel(focus.context),
              if (rect != null)
                'rect': [
                  rect.left.round(),
                  rect.top.round(),
                  rect.right.round(),
                  rect.bottom.round(),
                ],
            },
    };
  }

  /// What a screen reader would call the focused control — its own label or
  /// tooltip, or the nearest one above it (an icon button's tooltip sits on a
  /// widget wrapping the button). Needs the semantics tree, i.e. an
  /// accessibility service running on the device.
  static String? _semanticsLabel(BuildContext? context) {
    RenderObject? node = context?.findRenderObject();
    for (var i = 0; node != null && i < 14; i++) {
      final semantics = node.debugSemantics;
      if (semantics != null) {
        if (semantics.label.isNotEmpty) return semantics.label;
        if (semantics.tooltip.isNotEmpty) return semantics.tooltip;
      }
      node = node.parent;
    }
    return null;
  }

  /// The first few words of text under the focused control — enough to tell
  /// "Resume" from "Quit to Hub" without a screenshot.
  static String? _textUnder(BuildContext? context) {
    if (context is! Element) return null;
    final parts = <String>[];
    void visit(Element e, int depth) {
      if (parts.length >= 3 || depth > 40) return;
      final w = e.widget;
      if (w is RichText) {
        final s = w.text.toPlainText().trim();
        if (s.isNotEmpty) parts.add(s);
      }
      e.visitChildElements((child) => visit(child, depth + 1));
    }

    visit(context, 0);
    return parts.isEmpty ? null : parts.join(' | ');
  }
}

/// Stands in for a game's result screen: the result buttons, and the
/// achievement card drawn over them in the same Stack — exactly how the games
/// show it (no gaze scope of their own; the shell drives it by traversal).
class _DebugResultPage extends StatefulWidget {
  const _DebugResultPage();

  @override
  State<_DebugResultPage> createState() => _DebugResultPageState();
}

class _DebugResultPageState extends State<_DebugResultPage> {
  bool _showAchievement = true;
  String _pressed = 'none';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('debug-result pressed=$_pressed'),
                ElevatedButton(
                  onPressed: () => setState(() => _pressed = 'play-again'),
                  child: const Text('Play Again'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Exit'),
                ),
              ],
            ),
          ),
          if (_showAchievement)
            AchievementUnlockedOverlay(
              achievements: [Achievements.firstWord, Achievements.tenWords],
              onDismiss: () => setState(() => _showAchievement = false),
            ),
        ],
      ),
    );
  }
}
