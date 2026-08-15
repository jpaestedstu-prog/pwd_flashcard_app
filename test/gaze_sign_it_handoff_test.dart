import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/hands_free_pause_notice.dart';

/// FSL "Sign It!" is the one activity Gaze Control genuinely cannot drive: it
/// records the learner signing, and `startVideoRecording` cannot share a
/// `CameraController` with the gaze detector's image stream. It is also, by
/// definition, an activity you perform *with your hands*.
///
/// So the decision is not to fake hands-free support and not to hide it, but to
/// state the trade plainly and let the learner choose — with the choice itself
/// reachable hands-free, because the dialog is shown from the hub where the
/// focus-traversal fallback is live.

class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

void main() {
  Future<bool?> showNotice(
    WidgetTester tester, {
    required bool voiceAvailable,
  }) async {
    bool? answer;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gazeSettingsProvider.overrideWith(
              () => _FixedSettings(const GazeSettings(enabled: true))),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    answer = await confirmHandsFreePause(
                      context,
                      activityName: 'Sign It!',
                      voiceAvailable: voiceAvailable,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('the notice says what will happen and offers a real choice',
      (tester) async {
    await showNotice(tester, voiceAvailable: false);

    expect(find.textContaining('uses the camera'), findsOneWidget);
    expect(find.textContaining('Head control will pause'), findsOneWidget);
    // Both ways out are offered — this is a choice, not a block.
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Open anyway'), findsOneWidget);
  });

  testWidgets('without voice it explains how to get one', (tester) async {
    await showNotice(tester, voiceAvailable: false);
    // A head-only learner has no gaze *and* no spoken exit inside Sign It, so
    // the honest instruction is how to arrange one before going in.
    expect(find.textContaining('Voice commands in Settings'), findsOneWidget);
  });

  testWidgets('with voice on it names the escape hatch', (tester) async {
    await showNotice(tester, voiceAvailable: true);
    expect(find.textContaining('say "go back"'), findsOneWidget);
    expect(find.textContaining('Voice commands in Settings'), findsNothing);
  });

  testWidgets('"Not now" returns false and leaves the learner put',
      (tester) async {
    bool? answer;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    answer = await confirmHandsFreePause(
                      context,
                      activityName: 'Sign It!',
                      voiceAvailable: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(answer, isFalse);
  });

  testWidgets('"Open anyway" returns true', (tester) async {
    bool? answer;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    answer = await confirmHandsFreePause(
                      context,
                      activityName: 'Sign It!',
                      voiceAvailable: true,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open anyway'));
    await tester.pumpAndSettle();
    expect(answer, isTrue);
  });
}
