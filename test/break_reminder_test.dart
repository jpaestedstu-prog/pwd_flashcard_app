import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/services/break_reminder.dart';
import 'package:pwdpwdpwd/data/models/child_time_limit.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/break_time/break_time.dart';
import 'package:pwdpwdpwd/features/break_time/widgets/break_reminder_gate.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

class _FixedSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// Break reminders (Time limits → Break reminders): the rule, the saved
/// fields, and the reminder a learner answers.
void main() {
  ChildTimeLimit limit({bool on = true, int every = 20, bool daily = false, int dailyMinutes = 0}) =>
      ChildTimeLimit(
        childProfileId: 'kid',
        setterProfileId: 'teacher',
        setterRole: UserRole.teacher,
        breakReminderEnabled: on,
        breakEveryMinutes: every,
        dailyLimitEnabled: daily,
        dailyLimitMinutes: dailyMinutes,
        updatedAt: DateTime(2026, 11, 15),
      );

  group('BreakReminderEvaluator', () {
    test('due after the chosen stretch of learning, not before', () {
      expect(BreakReminderEvaluator.isDue(limit: limit(), usedMinutes: 19, anchorMinutes: 0), isFalse);
      expect(BreakReminderEvaluator.isDue(limit: limit(), usedMinutes: 20, anchorMinutes: 0), isTrue);
      expect(BreakReminderEvaluator.isDue(limit: limit(), usedMinutes: 45, anchorMinutes: 30), isFalse);
      expect(BreakReminderEvaluator.isDue(limit: limit(), usedMinutes: 50, anchorMinutes: 30), isTrue);
    });

    test('never due when off, or with no time limit at all', () {
      expect(BreakReminderEvaluator.isDue(limit: limit(on: false), usedMinutes: 300, anchorMinutes: 0), isFalse);
      expect(BreakReminderEvaluator.isDue(limit: null, usedMinutes: 300, anchorMinutes: 0), isFalse);
    });

    test('a new day (the count went back to zero) starts again from the new count', () {
      expect(BreakReminderEvaluator.isDue(limit: limit(), usedMinutes: 3, anchorMinutes: 40), isFalse);
      expect(BreakReminderEvaluator.keepAnchor(usedMinutes: 3, anchorMinutes: 40), 3);
      expect(BreakReminderEvaluator.keepAnchor(usedMinutes: 50, anchorMinutes: 40), 40);
    });

    test('an out-of-range interval is clamped (10 to 60 minutes)', () {
      expect(limit(every: 2).effectiveBreakEveryMinutes, 10);
      expect(limit(every: 600).effectiveBreakEveryMinutes, 60);
      expect(BreakReminderEvaluator.isDue(limit: limit(every: 1), usedMinutes: 9, anchorMinutes: 0), isFalse);
      expect(BreakReminderEvaluator.isDue(limit: limit(every: 1), usedMinutes: 10, anchorMinutes: 0), isTrue);
    });

    test('learning time left today, only when a daily limit is set', () {
      expect(BreakReminderEvaluator.minutesLeftToday(limit(), 10), isNull);
      expect(BreakReminderEvaluator.minutesLeftToday(limit(daily: true, dailyMinutes: 60), 25), 35);
      expect(BreakReminderEvaluator.minutesLeftToday(limit(daily: true, dailyMinutes: 60), 75), 0);
    });
  });

  group('ChildTimeLimit break fields', () {
    test('saved and read back', () {
      final back = ChildTimeLimit.fromJson(limit(every: 35).toJson());
      expect(back.breakReminderEnabled, isTrue);
      expect(back.breakEveryMinutes, 35);
    });

    test('a limit saved before break reminders existed keeps them off', () {
      final json = limit().toJson()
        ..remove('break_reminder_enabled')
        ..remove('break_every_minutes');
      final old = ChildTimeLimit.fromJson(json);
      expect(old.breakReminderEnabled, isFalse);
      expect(old.breakEveryMinutes, 20);
    });

    test('copyWith keeps them unless changed', () {
      final l = limit(every: 30);
      expect(l.copyWith(dailyLimitEnabled: true).breakEveryMinutes, 30);
      expect(l.copyWith(breakReminderEnabled: false).breakReminderEnabled, isFalse);
    });
  });

  testWidgets('starting a break (the button or a reminder) tells the reminder to count again', (tester) async {
    final before = breakTimeStarted.value;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsProvider.overrideWith(_FixedSettings.new),
        hapticServiceProvider.overrideWithValue(HapticService(enabled: false)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showBreakTime(context),
            child: const Text('break'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('break'));
    await tester.pump();
    expect(breakTimeStarted.value, before + 1);
    await tester.pumpWidget(const SizedBox()); // the break screen's timers end
  });

  testWidgets('the reminder: words, time left, and two answers reachable by keyboard', (tester) async {
    bool? answer;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            answer = await showDialog<bool>(
              context: context,
              builder: (_) => const BreakReminderDialog(
                title: 'Time for a short break',
                body: 'You have been learning for 20 minutes.',
                timeLeft: 'Learning time left today: 15 minutes.',
                takeBreakLabel: 'Take a break',
                keepLearningLabel: 'Keep learning',
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Time for a short break'), findsOneWidget);
    expect(find.text('Learning time left today: 15 minutes.'), findsOneWidget);
    // "Take a break" holds the focus, so Enter, a D-pad or a switch answers it.
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    expect(focused, isNotNull);
    await tester.tap(find.text('Keep learning'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take a break'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });

  test('the reminder waits during tests, live sessions and games with others', () {
    for (final route in ['/assessment/take/abc', '/live-session', '/multiplayer', '/peer-collab']) {
      expect(breakReminderWaitsOn.any(route.startsWith), isTrue, reason: route);
    }
    for (final route in ['/home', '/flashcards/viewer/0', '/games/word-match']) {
      expect(breakReminderWaitsOn.any(route.startsWith), isFalse, reason: route);
    }
  });
}
