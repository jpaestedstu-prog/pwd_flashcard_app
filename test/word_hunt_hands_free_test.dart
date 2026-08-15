import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/object_scan/word_hunt_entry.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// Word Hunt points the **back** camera at the world, so the shell's head-
/// control camera stands down for as long as it is open — the same trade FSL
/// "Sign It!" makes. A learner who navigated there by gaze must be told before
/// their only input disappears, and must be told what still works: unlike Sign
/// It, Word Hunt keeps the microphone, so voice drives the whole activity.
///
/// Both learner hubs route the tile through [openWordHunt] so they can never
/// drift apart on this.

class _FixedGaze extends GazeSettingsNotifier {
  _FixedGaze(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

void main() {
  Future<void> pumpHub(
    WidgetTester tester, {
    required GazeSettings gaze,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => openWordHunt(context, ref),
                  child: const Text('Word Hunt'),
                ),
              ),
            ),
          ),
        ),
        GoRoute(path: '/object-scan', builder: (_, _) => const Text('scanner')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gazeSettingsProvider.overrideWith(() => _FixedGaze(gaze)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Word Hunt'));
    await tester.pumpAndSettle();
  }

  testWidgets('with gaze off it opens the scanner straight away',
      (tester) async {
    await pumpHub(tester, gaze: const GazeSettings());
    expect(find.text('scanner'), findsOneWidget);
    expect(find.text('Open anyway'), findsNothing);
  });

  testWidgets('with gaze on it warns first and offers a real choice',
      (tester) async {
    await pumpHub(tester, gaze: const GazeSettings(enabled: true));

    expect(find.text('scanner'), findsNothing);
    expect(find.textContaining('Word Hunt uses the camera'), findsOneWidget);
    expect(find.textContaining('points the camera at the world'), findsOneWidget);
    expect(find.textContaining('Head control will pause'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.text('Open anyway'), findsOneWidget);
  });

  testWidgets('"Not now" leaves the learner on the hub', (tester) async {
    await pumpHub(tester, gaze: const GazeSettings(enabled: true));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.text('scanner'), findsNothing);
    expect(find.text('Word Hunt'), findsOneWidget);
  });

  testWidgets('"Open anyway" goes in', (tester) async {
    await pumpHub(tester, gaze: const GazeSettings(enabled: true));
    await tester.tap(find.text('Open anyway'));
    await tester.pumpAndSettle();
    expect(find.text('scanner'), findsOneWidget);
  });

  testWidgets('with voice on it names what voice can still do', (tester) async {
    await pumpHub(
      tester,
      gaze: const GazeSettings(enabled: true, voiceCommands: true),
    );
    // Not just an exit: the shutter and picking a found word are spoken too,
    // which is what makes Word Hunt genuinely drivable hands-free.
    expect(find.textContaining('take a photo'), findsOneWidget);
    expect(find.textContaining('go back'), findsOneWidget);
  });

  testWidgets('without voice it explains how to arrange an exit',
      (tester) async {
    await pumpHub(tester, gaze: const GazeSettings(enabled: true));
    expect(find.textContaining('Voice commands in Settings'), findsOneWidget);
  });
}
