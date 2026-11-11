import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/companion/controllers/companion_controller.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';
import 'package:pwdpwdpwd/features/home/screens/player_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/bottom_nav_shell.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;
import 'support/real_fonts.dart';

/// A floating message over a learner's hub, and the AI Buddy beside it.
///
/// The buddy floats over the whole app; a message rests at the bottom of the
/// hub, where the buddy is. On the Villaon (9 Nov) the buddy covered the OK
/// of "Something went wrong", and a tap on OK opened the tutor instead.
class _Learner extends ProfileNotifier {
  _Learner(this.role, {this.guest = false});
  final UserRole role;
  final bool guest;

  @override
  UserProfile? build() => UserProfile(
    id: 'message-clear',
    name: 'Ana',
    role: role,
    isGuestPlayer: guest,
    disabilityType: DisabilityType.visual,
    createdAt: DateTime(2026),
  );
}

class _QuietTts extends TtsService {
  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakEnglish(String text) async {}
  @override
  Future<void> speakFilipino(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double speed) async {}
  @override
  Future<void> dispose() async {}
}

class _SilentSound implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

GoRouter _router(bool guest) => GoRouter(
  initialLocation: guest ? '/home' : '/games',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          BottomNavShell(state: state, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const PlayerHomeScreen()),
        GoRoute(
          path: '/games',
          builder: (_, _) => const Scaffold(body: SizedBox.expand()),
        ),
      ],
    ),
  ],
);

final _launcher = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_CompanionLauncher',
);

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('message_buddy_clear');
  });
  tearDownAll(closeSweepBoxes);

  const sizes = {
    'phone 360x640': Size(360, 640),
    'Villaon at Largest 320x711': Size(320, 711),
    'Villaon 423x941': Size(423, 941),
    'phone sideways 640x360': Size(640, 360),
    'Honor upright 686x1097': Size(686, 1097),
  };

  for (final guest in const [true, false]) {
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      final who = guest ? 'a guest' : 'a learner with tabs';
      testWidgets('$who, $name: a message and its OK are clear of the buddy', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(bottom: 24);
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (final scale in const [1.0, 1.5]) {
          final where = '$who, $name, ${scale}x';
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final router = _router(guest);
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                profileProvider.overrideWith(
                  () => _Learner(
                    guest ? UserRole.player : UserRole.student,
                    guest: guest,
                  ),
                ),
                routerProvider.overrideWithValue(router),
                ttsServiceProvider.overrideWithValue(_QuietTts()),
                soundServiceProvider.overrideWithValue(_SilentSound()),
              ],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
                builder: (context, child) =>
                    CompanionHost(child: child ?? const SizedBox.shrink()),
              ),
            ),
          );
          for (var t = 0; t < 15; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(_launcher, findsOneWidget, reason: '$where: the buddy');

          // As the app's own error message is shown: from the app's messenger.
          final page = tester.element(find.byType(BottomNavShell));
          ScaffoldMessenger.of(page).showSnackBar(
            SnackBar(
              content: const Text('Something went wrong.'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(minutes: 1),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
          for (var t = 0; t < 10; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final buddy = tester.getRect(_launcher).deflate(1);
          final message = tester.getRect(find.byType(Material).last);
          final ok = tester.getRect(find.widgetWithText(TextButton, 'OK'));
          expect(
            ok.overlaps(buddy),
            isFalse,
            reason: '$where: OK $ok is under the buddy $buddy',
          );
          final snack = tester.getRect(
            find.descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            ).first,
          );
          expect(
            snack.overlaps(buddy),
            isFalse,
            reason: '$where: the message $snack is under the buddy $buddy '
                '($message)',
          );

          // OK closes the message; it does not open the tutor.
          await tester.tap(find.widgetWithText(TextButton, 'OK'));
          for (var t = 0; t < 10; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final container = ProviderScope.containerOf(page);
          expect(
            container.read(companionControllerProvider).isOpen,
            isFalse,
            reason: '$where: OK opened the tutor',
          );
          expect(find.byType(SnackBar), findsNothing, reason: where);

          await tester.pumpWidget(const SizedBox());
          for (var t = 0; t < 3; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      });
    }
  }
}
