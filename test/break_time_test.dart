import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/break_time/break_time.dart';
import 'package:pwdpwdpwd/features/break_time/models/break_time_models.dart';
import 'package:pwdpwdpwd/features/break_time/screens/break_time_screen.dart';
import 'package:pwdpwdpwd/features/break_time/widgets/bubble_pop_break.dart';
import 'package:pwdpwdpwd/features/break_time/widgets/breathing_break.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// Fixed-settings notifier so widget tests never read/write Hive (the break
/// feature is intentionally side-effect free; this keeps the test the same).
class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

void main() {
  group('BreakActivity', () {
    test('exposes both options with distinct, non-empty presentation', () {
      expect(BreakActivity.values, hasLength(2));
      expect(BreakActivity.values, contains(BreakActivity.breathing));
      expect(BreakActivity.values, contains(BreakActivity.bubbles));

      for (final a in BreakActivity.values) {
        expect(a.label, isNotEmpty);
        expect(a.description, isNotEmpty);
        expect(a.emoji, isNotEmpty);
      }
      // The two activities must be visually distinguishable.
      expect(
        BreakActivity.breathing.label,
        isNot(BreakActivity.bubbles.label),
      );
      expect(
        BreakActivity.breathing.icon,
        isNot(BreakActivity.bubbles.icon),
      );
    });
  });

  group('BreakTimeScreen', () {
    Widget harness({AppSettings settings = const AppSettings()}) {
      return ProviderScope(
        overrides: [
          settingsProvider.overrideWith(() => _FixedSettings(settings)),
          // Disabled haptics → no platform-channel calls during the test.
          hapticServiceProvider.overrideWithValue(
            HapticService(enabled: false),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BreakTimeScreen(),
        ),
      );
    }

    testWidgets('chooser offers both Breathe and Pop Bubbles, and a way back',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.text('Breathe'), findsOneWidget);
      expect(find.text('Pop Bubbles'), findsOneWidget);
      // Always-available exit so a student is never trapped in the break.
      expect(find.byTooltip('Back to lesson'), findsOneWidget);

      await tester.pumpWidget(const SizedBox()); // unmount → dispose timers
    });

    testWidgets('choosing Breathe starts the breathing activity',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await tester.tap(find.text('Breathe'));
      await tester.pump(); // rebuild into the activity stage

      expect(find.byType(BreathingBreak), findsOneWidget);
      expect(find.text('Pop Bubbles'), findsNothing); // chooser is gone

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox()); // dispose controller + timer
    });

    testWidgets('choosing Pop Bubbles starts the bubble activity',
        (tester) async {
      await tester.pumpWidget(harness());
      await tester.pump();

      await tester.tap(find.text('Pop Bubbles'));
      await tester.pump();

      expect(find.byType(BubblePopBreak), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox()); // dispose ticker + timer
    });
  });

  group('GameBreakButton (floating, in-game)', () {
    testWidgets('pauses, opens the break, then resumes on return',
        (tester) async {
      var holds = 0;
      var resumes = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith(
              () => _FixedSettings(const AppSettings()),
            ),
            hapticServiceProvider.overrideWithValue(
              HapticService(enabled: false),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  const SizedBox.expand(), // stand-in for the game body
                  GameBreakButton(
                    onHold: () => holds++,
                    onResume: () => resumes++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The floating "Break" pill is visible during gameplay.
      expect(find.text('Break'), findsOneWidget);

      await tester.tap(find.text('Break'));
      await tester.pump(); // begin the push
      await tester.pump(const Duration(milliseconds: 400)); // finish transition

      expect(holds, 1); // game paused before the break opened
      expect(find.byType(BreakTimeScreen), findsOneWidget);
      expect(find.text('Breathe'), findsOneWidget); // chooser is up

      // Return to the game.
      await tester.tap(find.byTooltip('Back to lesson'));
      await tester.pump(); // begin the pop
      await tester.pump(const Duration(milliseconds: 400)); // finish pop

      expect(resumes, 1); // game resumed on return
      expect(find.byType(BreakTimeScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('BubblePopBreak (no-fail)', () {
    testWidgets('spawns bubbles and pops one on tap', (tester) async {
      var pops = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: BubblePopBreak(
                  colors: const [Colors.blue, Colors.teal],
                  onPop: () => pops++,
                ),
              ),
            ),
          ),
        ),
      );

      // Drive many frames (each pump is one tick) so the earliest-spawned
      // bubble rises well into view — bubbles start just below the bottom edge.
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The oldest bubble is the first child and is highest on screen.
      final bubbles = find.descendant(
        of: find.byType(BubblePopBreak),
        matching: find.byType(GestureDetector),
      );
      expect(bubbles, findsWidgets);

      await tester.tap(bubbles.first);
      await tester.pump();
      expect(pops, 1); // tapping a bubble pops it — no score, no failure

      await tester.pumpWidget(const SizedBox()); // dispose the ticker
    });
  });
}
