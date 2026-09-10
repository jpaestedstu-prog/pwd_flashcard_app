import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/haptic_service.dart'
    show hapticServiceProvider;
import '../../../core/accessibility/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/app_providers.dart' show settingsProvider;
import '../logic/gamepad_actions.dart';
import '../logic/gamepad_speech.dart';
import '../models/gamepad_button.dart';
import '../providers/gamepad_practice.dart';
import '../providers/gamepad_settings_provider.dart';
import '../providers/gamepad_status_provider.dart';
import '../services/gamepad_announcer.dart';
import '../../../core/widgets/fit_text.dart';

/// A place to press every button and be told what it does, with nothing at
/// stake.
///
/// Learning a controller by using it means discovering R1 by opening something
/// unexpected, and discovering L1 by leaving the screen you were on. For a
/// learner who cannot see where they ended up, that is not learning — it is
/// getting lost. Here the app stands down completely ([gamepadPractice]) and
/// every press only produces its own name and its own job.
///
/// **L1 is the way out, and it takes two presses.** Pressed once it is
/// announced like any other button; pressed again within a few seconds it
/// leaves. Without that pause a learner exploring what L1 does would be
/// ejected by the very press they were trying to learn about.
///
/// The counting lives in `GamepadHost`, not here — the host is always alive, so
/// the exit cannot be lost if this screen ever stops receiving events. This
/// screen only says that a second press will leave.
class GamepadPracticeScreen extends ConsumerStatefulWidget {
  const GamepadPracticeScreen({super.key});

  @override
  ConsumerState<GamepadPracticeScreen> createState() =>
      _GamepadPracticeScreenState();
}

class _GamepadPracticeScreenState extends ConsumerState<GamepadPracticeScreen> {
  StreamSubscription<GamepadEvent>? _sub;
  GamepadAnnouncer? _announcer;

  /// Controls pressed at least once, so the learner can be told how much of the
  /// pad they have explored.
  final Set<GamepadButton> _tried = {};

  GamepadButton? _last;
  String _lastAction = '';

  /// When back was last announced, so the exit press stays quiet.
  DateTime? _lastBackAt;


  /// The controls worth practising — everything except the pad's own HID-mode
  /// button, which the app deliberately ignores.
  static final List<GamepadButton> _practiceable = [
    for (final b in GamepadButton.values)
      if (b != GamepadButton.mode) b,
  ];

  @override
  void initState() {
    super.initState();
    gamepadPractice.value = true;
    scheduleMicrotask(_start);
  }

  @override
  void dispose() {
    gamepadPractice.value = false;
    _sub?.cancel();
    super.dispose();
  }

  void _start() {
    if (!mounted) return;
    final service = ref.read(gamepadServiceProvider);
    service.start();
    _announcer = GamepadAnnouncer(ref.read(ttsServiceProvider))
      ..enabled = ref.read(gamepadSettingsProvider).speak
      ..locale = _phrases.locale
      ..rate = _rate;
    _sub = service.buttons.listen(_onButton);
    _announcer?.say(_phrases.practiceIntro);
  }

  GamepadPhrases get _phrases {
    try {
      return GamepadPhrases(ref.read(settingsProvider).locale);
    } catch (_) {
      return const GamepadPhrases('en');
    }
  }

  double get _rate {
    try {
      return ref.read(settingsProvider).ttsSpeed;
    } catch (_) {
      return 0.5;
    }
  }

  void _onButton(GamepadEvent event) {
    if (!mounted || !event.pressed) return;
    final button = event.button;
    final action = resolveGamepadAction(button);
    final phrases = _phrases;

    // The *second* back press is the one the host acts on, and it already says
    // "Going back". Naming the button again on the way out leaves the learner
    // hearing "Going back. L1. Go back. Press L1 again to leave." as the screen
    // disappears. Mirror the host's window just closely enough to stay quiet.
    if (action == GamepadAction.back) {
      final now = DateTime.now();
      final previous = _lastBackAt;
      _lastBackAt = now;
      if (previous != null &&
          now.difference(previous) <= const Duration(seconds: 4)) {
        return;
      }
    }

    try {
      ref.read(hapticServiceProvider).selectionClick();
    } catch (_) {
      // No vibrator; the announcement is the feedback that matters.
    }

    final wasNew = _tried.add(button);
    setState(() {
      _last = button;
      _lastAction = phrases.actionName(action);
    });

    final name = phrases.buttonName(button);
    // The host counts the two presses; this only has to say so. Announced on
    // every back press, because the first one is exactly when the learner needs
    // to know the second will leave.
    final leaveHint = action == GamepadAction.back
        ? (phrases.locale == 'fil'
            ? ' Pindutin muli ang L1 para umalis.'
            : ' Press L1 again to leave.')
        : '';

    var line = '$name. $_lastAction$leaveHint';
    // Progress is only worth saying when it changed, and only occasionally —
    // after every press it would drown out the thing being practised.
    if (wasNew) {
      if (_tried.length == _practiceable.length) {
        line = '$line ${phrases.practiceComplete}';
      } else if (_tried.length % 5 == 0) {
        line =
            '$line ${phrases.practiceProgress(_tried.length, _practiceable.length)}';
      }
    }
    _announcer?.say(line);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(gamepadStatusProvider);
    final phrases = _phrases;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('🎮  Practice')),
      body: SafeArea(
        // Scrollable, but still an `Expanded` layout when there is room.
        //
        // The read-out and the button grid are meant to share whatever height
        // is left, which is right on a normal screen and impossible at 2x: the
        // fixed banner, chips and spacings alone are taller than a phone, so
        // the flexible children were handed nothing and the column ran 185 px
        // off the bottom. `IntrinsicHeight` inside the scroll view lets the
        // Expandeds keep working while the whole thing can scroll when it must.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!status.connected)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_disabled_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No controller connected. Switch it on and it will '
                          'start responding here.',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),

              // The big read-out: what was just pressed, and what it does.
              Expanded(
                flex: 3,
                child: Semantics(
                  liveRegion: true,
                  label: _last == null
                      ? 'Press any button on the controller'
                      : '${phrases.buttonName(_last!)}. $_lastAction',
                  excludeSemantics: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _last == null
                              ? 'Press any button'
                              : phrases.buttonName(_last!),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _last == null
                              ? 'I will tell you what it does. Nothing else '
                                  'will happen.'
                              : _lastAction,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tried ${_tried.length} of ${_practiceable.length}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (_tried.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => setState(_tried.clear),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Start over'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _tried.length / _practiceable.length,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),

              const SizedBox(height: 16),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final button in _practiceable)
                        _ControlChip(
                          label: phrases.buttonName(button),
                          tried: _tried.contains(button),
                          active: _last == button,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Press L1 twice to leave.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlChip extends StatelessWidget {
  final String label;
  final bool tried;
  final bool active;

  const _ControlChip({
    required this.label,
    required this.tried,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final base = tried ? AppColors.success : Theme.of(context).hintColor;
    final color = active ? AppColors.primary : base;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active ? 0.22 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tried) ...[
            Icon(Icons.check_rounded, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            // `fittedStyle`, not `FitText`: the body below is wrapped in an
            // `IntrinsicHeight` so its `Expanded` children survive inside a
            // scroll view, and a `LayoutBuilder` cannot report intrinsics.
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fittedStyle(
                context,
                label,
                TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
                longWord: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
