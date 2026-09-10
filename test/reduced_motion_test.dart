import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/reduced_motion.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/widgets/tutor_persona.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/accessibility_visual_feedback.dart';
import 'package:pwdpwdpwd/widgets/animated_gradient_background.dart';
import 'package:pwdpwdpwd/widgets/shimmer_loading.dart';

/// Reduced Motion has to stop the motion, and stop it *now*.
///
/// `main.dart` sets [Animate.defaultDuration] to zero when the learner turns
/// the setting on, which is enough for a one-shot entrance — it reads its
/// duration from that global. A `repeat()` does not: it passes its own
/// durations and keeps going, so 32 looping animations across the app carried
/// on for exactly the learners who had asked them to stop.
///
/// Guarding them in `initState` fixed that only for screens built afterwards.
/// On device the setting looked dead until the app was restarted — 78% idle CPU
/// after toggling, 0% after a restart. So the guards now live in `build`, and
/// what these tests check is the *transition*, not just the resting states.
///
/// Two assertions do the work:
///
/// * `pumpAndSettle` returns only when the tree stops scheduling frames, so a
///   still-looping animation makes it time out. That is the honest check for
///   "nothing is animating", and it doubles as a check that the frame can go
///   idle at all — which is what lets the device stop waking the raster thread.
/// * `transientCallbackCount` is the number of scheduled frame callbacks, so it
///   counts *running tickers*. Comparing it across many toggles is how a
///   duplicated controller or a leaked ticker would show up; a count that
///   climbed with each toggle is exactly the lifecycle bug to catch.
void main() {
  final persona = TutorPersona.of(UserRole.student);

  setUp(() => Animate.defaultDuration = const Duration(milliseconds: 300));
  tearDown(() => Animate.defaultDuration = const Duration(milliseconds: 300));

  /// Mirrors `main.dart`: one setting, read once, feeding both mechanisms —
  /// the provider for widgets that hold a `ref`, [ReducedMotionScope] for the
  /// plain `StatefulWidget`s (several of these live in overlays, where
  /// requiring a `ProviderScope` ancestor would be a needless constraint).
  ///
  /// Because the scope is *derived* from the provider, a test flips the
  /// setting the way the settings screen does — mutate, pump — and never
  /// rebuilds the tree by hand. That is what makes these tests about the
  /// transition rather than about two separately-pumped resting states.
  Future<_ToggleSettings> pumpSubject(
    WidgetTester tester,
    Widget child, {
    required bool reduced,
  }) async {
    final settings = _ToggleSettings(reduced);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith(() => settings)],
        child: Consumer(
          builder: (context, ref, _) => ReducedMotionScope(
            reduced: ref.watch(
              settingsProvider.select((s) => s.reducedMotion),
            ),
            child: MaterialApp(home: Scaffold(body: Center(child: child))),
          ),
        ),
      ),
    );
    // Two frames: flutter_animate defers its first play by a zero-duration
    // Future, so a single pump can land before anything has started and make
    // a ticker count read as zero for the wrong reason.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    return settings;
  }

  /// The subjects, one per route into the guard.
  ///
  /// [AnimatedGradientBackground] is the widest loop in the app (10 screens,
  /// and it drives FloatingParticles underneath) and reads the provider;
  /// [ShimmerLoading] is the other provider-reading one; [MicrophoneWaveform]
  /// is a plain `StatefulWidget` that can only see the scope, and it is also
  /// the conditional case — it loops on `isListening` *and* the setting;
  /// [TutorAvatar] is `flutter_animate`, where the fix is a changed key rather
  /// than a stopped controller.
  final subjects = <String, Widget>{
    'gradient background': const AnimatedGradientBackground(
      child: SizedBox.expand(),
    ),
    'loading shimmer': const ShimmerLoading(
      child: SizedBox(width: 100, height: 20),
    ),
    'microphone waveform': const MicrophoneWaveform(isListening: true),
    'tutor avatar': TutorAvatar(persona: persona, size: 48),
  };

  for (final entry in subjects.entries) {
    group(entry.key, () {
      testWidgets('keeps animating while motion is allowed', (tester) async {
        // The other half of the promise: the guard must not flatten the
        // animation for learners who never asked for that. A running loop
        // never settles, so timing out here is the pass condition.
        await pumpSubject(tester, entry.value, reduced: false);

        expect(await _settles(tester), isFalse,
            reason: '${entry.key} should keep animating when motion is on');
      });

      testWidgets('stops the moment Reduced Motion is switched on',
          (tester) async {
        final settings = await pumpSubject(tester, entry.value, reduced: false);
        expect(await _settles(tester), isFalse, reason: 'should start running');

        // Flip it exactly as the settings screen does: no restart, no remount,
        // the same element tree.
        settings.setReduced(true);
        await tester.pumpAndSettle();

        expect(tester.binding.transientCallbackCount, 0,
            reason: '${entry.key} left a ticker running after the toggle');
      });

      testWidgets('resumes when Reduced Motion is switched back off',
          (tester) async {
        final settings = await pumpSubject(tester, entry.value, reduced: true);
        await tester.pumpAndSettle();

        settings.setReduced(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(await _settles(tester), isFalse,
            reason: '${entry.key} did not resume when motion was allowed again');
      });

      testWidgets('toggling repeatedly stacks no extra tickers',
          (tester) async {
        final settings = await pumpSubject(tester, entry.value, reduced: false);
        final baseline = tester.binding.transientCallbackCount;
        expect(baseline, greaterThan(0),
            reason: 'nothing was running to begin with');

        for (var i = 0; i < 5; i++) {
          settings.setReduced(true);
          await tester.pumpAndSettle();
          expect(tester.binding.transientCallbackCount, 0,
              reason: 'a ticker survived toggle ${i + 1}');

          settings.setReduced(false);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
        }

        // A controller started twice, or an Animate whose old controller was
        // never disposed, would show up here as a count above the baseline.
        expect(tester.binding.transientCallbackCount, baseline,
            reason: '${entry.key} accumulated tickers across 5 toggles');
      });
    });
  }
}

/// Pumps for a while and reports whether the tree went idle.
///
/// `pumpAndSettle` throws on timeout rather than returning a verdict, which is
/// what makes "should still be animating" awkward to assert directly.
Future<bool> _settles(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    return true;
  } on FlutterError {
    return false;
  }
}

/// A settings notifier the test can flip, standing in for the real one so no
/// Hive box is needed.
class _ToggleSettings extends SettingsNotifier {
  _ToggleSettings(this._initial);
  final bool _initial;

  @override
  AppSettings build() => AppSettings(reducedMotion: _initial);

  void setReduced(bool value) =>
      state = state.copyWith(reducedMotion: value);
}
