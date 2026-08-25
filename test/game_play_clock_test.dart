import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/games/timed_game_mixin.dart';

/// The play clock behind `GameScore.durationSeconds`.
///
/// It measures **time on task**, not time on screen: a learner who opens a
/// game, pauses for a calming break and comes back twenty minutes later has
/// not practised for twenty minutes, and the parent/teacher dashboard and the
/// research export both report this figure.
///
/// Deliberately free of Hive — mixing `testWidgets` with a real `box.put`
/// poisons the box's write queue for the whole file. The persistence half
/// lives in `game_bests_test.dart` as plain `test()` cases.
void main() {
  testWidgets('starts on mount, even for a game that never calls '
      'startTimerIfNeeded', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ClockHost()));
    final host = tester.state<_ClockHostState>(find.byType(_ClockHost));

    // The two FSL practice modes and the multiplayer quiz mix the timer in
    // but never start a countdown; their time on task still has to be counted.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    expect(host.millis, greaterThan(0));
  });

  testWidgets('excludes the stretch the game is paused for', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _ClockHost()));
    final host = tester.state<_ClockHostState>(find.byType(_ClockHost));

    // Wall-clock, so drive it with real time rather than pumped frames.
    await tester.runAsync(() async {
      host.pause();
      final atPause = host.millis;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(
        host.millis,
        atPause,
        reason: 'the clock kept running while the game was paused',
      );

      host.resume();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(
        host.millis,
        greaterThan(atPause),
        reason: 'the clock did not restart on resume',
      );
    });
  });

  testWidgets('resumes for an untimed game too', (tester) async {
    // resumeTimer() returns early when the game is not in timed mode. The
    // play clock has to restart before that guard, or every untimed game
    // would report only the seconds before its first pause.
    await tester.pumpWidget(const MaterialApp(home: _ClockHost()));
    final host = tester.state<_ClockHostState>(find.byType(_ClockHost));

    await tester.runAsync(() async {
      host.startTimerIfNeeded(false); // untimed
      host.pause();
      final atPause = host.millis;
      host.resume();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(host.millis, greaterThan(atPause));
    });
  });

  testWidgets('Play Again starts a fresh run rather than accumulating', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _ClockHost()));
    final host = tester.state<_ClockHostState>(find.byType(_ClockHost));

    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(host.millis, greaterThan(100));

      // Every game routes its restart through startTimerIfNeeded.
      host.startTimerIfNeeded(false);
      expect(
        host.millis,
        lessThan(50),
        reason: "the second run inherited the first run's minutes",
      );
    });
  });
}

/// Minimal host so the mixin can be exercised without standing up a game.
class _ClockHost extends StatefulWidget {
  const _ClockHost();

  @override
  State<_ClockHost> createState() => _ClockHostState();
}

class _ClockHostState extends State<_ClockHost> with TimedGameMixin {
  int get millis => elapsedMilliseconds;

  // pauseTimer / resumeTimer are @protected. These stand in for the calls a
  // real game makes from its pause overlay, break button and lifecycle hook.
  void pause() => pauseTimer();
  void resume() => resumeTimer();

  @override
  void onTimeUp() {}

  @override
  void dispose() {
    disposeTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
