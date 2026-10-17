import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/platform_caps.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/enhanced_create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_practice_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/message_media_view.dart';
import 'package:pwdpwdpwd/features/settings/screens/backup_restore_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/widgets/android_app_notice.dart';

import 'support/all_screens.dart';

/// The browser version cannot do everything the Android app does: it has no
/// files, alarms, local server, camera takes or controller bridge. Each
/// feature built on those says so where it is offered, instead of a button
/// that fails or seems to work and does nothing.
///
/// [PlatformCaps.debugWeb] shows the browser version's screens here.
void main() {
  final t = AppLocalizationsEn();

  setUpAll(() => openSweepBoxes('browser_limits'));
  tearDownAll(closeSweepBoxes);
  tearDown(() => PlatformCaps.debugWeb = null);

  Future<void> pump(WidgetTester tester, Widget child, UserRole role) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sweepProfileOverride(role)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls the page's main list until [finder] is built, or to its end.
  Future<bool> scrollTo(WidgetTester tester, Finder finder) async {
    final lists = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    if (finder.evaluate().isNotEmpty) return true;
    if (lists.evaluate().isEmpty) return false;
    final position = tester.state<ScrollableState>(lists.first).position;
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      if (position.extentAfter <= 0) break;
      position.jumpTo(
        (position.pixels + 300).clamp(0.0, position.maxScrollExtent),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return finder.evaluate().isNotEmpty;
  }

  Future<void> unmount(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final screens = <String, (Widget Function(), UserRole, String)>{
    'TV Cast': (() => const TvCastScreen(), UserRole.teacher,
        t.webTvCastNeedsApp),
    'Backup & Restore': (() => const BackupRestoreScreen(), UserRole.student,
        t.webBackupNeedsApp),
    'Settings > Reminders': (() => const SettingsScreen(), UserRole.student,
        t.webRemindersNeedApp),
    'Game Controller': (() => const GamepadSettingsScreen(),
        UserRole.student, t.webControllerNeedsApp),
    'Controller practice': (() => const GamepadPracticeScreen(),
        UserRole.student, t.webControllerNeedsApp),
    'Create a card (picture)': (() => const EnhancedCreateFlashcardScreen(),
        UserRole.student, t.webMediaNeedsApp),
  };

  for (final MapEntry(key: name, value: (build, role, message))
      in screens.entries) {
    testWidgets('$name: the browser version says it needs the Android app',
        (tester) async {
      PlatformCaps.debugWeb = true;
      await pump(tester, build(), role);
      expect(await scrollTo(tester, find.text(message)), isTrue,
          reason: 'the notice is on the screen');
      expect(find.text(t.webGetAndroidApp), findsWidgets,
          reason: 'with the way to get the app');
      await unmount(tester);
    });

    testWidgets('$name: the Android app shows no such notice', (tester) async {
      PlatformCaps.debugWeb = false;
      await pump(tester, build(), role);
      expect(await scrollTo(tester, find.byType(AndroidAppNotice)), isFalse);
      await unmount(tester);
    });
  }

  testWidgets('Backup & Restore in a browser offers the Recovery Code, not '
      'backup files', (tester) async {
    PlatformCaps.debugWeb = true;
    await pump(tester, const BackupRestoreScreen(), UserRole.student);
    expect(find.text(t.brBackUpNow), findsNothing);
    expect(find.text(t.brRestore), findsNothing);
    expect(await scrollTo(tester, find.text(t.settingRecoveryCodeTitle)),
        isTrue);
    await unmount(tester);
  });

  testWidgets('Settings in a browser has no screen-orientation choice (a '
      'browser turns the page itself) and no reminder switches',
      (tester) async {
    PlatformCaps.debugWeb = true;
    await pump(tester, const SettingsScreen(), UserRole.student);
    expect(await scrollTo(tester, find.text(t.webRemindersNeedApp)), isTrue);
    expect(find.text(t.screenOrientation), findsNothing);
    expect(find.text(t.dailyReminder), findsNothing);
    await unmount(tester);

    PlatformCaps.debugWeb = false;
    await pump(tester, const SettingsScreen(), UserRole.student);
    expect(await scrollTo(tester, find.text(t.screenOrientation)), isTrue,
        reason: 'the app keeps it');
    await unmount(tester);
  });

  testWidgets('a photo sent in a message says where it can be seen, instead '
      'of "try again" forever', (tester) async {
    PlatformCaps.debugWeb = true;
    await pump(
      tester,
      Scaffold(
        body: MessageMediaBody(
          message: LocalMessage(
            id: 'm1',
            senderId: 'kid',
            senderName: 'kid',
            recipientId: 'other',
            content: 'shared://m1',
            type: MessageType.photo,
            timestamp: DateTime.now(),
          ),
          isFilipino: false,
        ),
      ),
      UserRole.student,
    );
    expect(find.text(t.webMediaOpensInApp), findsOneWidget);
    expect(find.text("Can't load it yet. Tap to try again."), findsNothing);
    await unmount(tester);
  });
}
