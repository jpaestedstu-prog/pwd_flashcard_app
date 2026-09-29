import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/update_check_service.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/update_available_card.dart';

/// The educator home's "new version" card: only for a real update, in both
/// languages, and with the way to the download page.

const _release = AppRelease(
  version: '1.3.0',
  build: 5,
  date: '2026-10-15',
  pageUrl: 'https://jpaestedstu-prog.github.io/pwd_flashcard_app/#download',
);

Future<void> _pump(
  WidgetTester tester,
  UpdateStatus status, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [updateStatusProvider.overrideWith((ref) async => status)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: UpdateAvailableCard()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/update_available_card');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
  });
  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  testWidgets('a newer version shows the card and the way to get it', (
    tester,
  ) async {
    await _pump(tester, const UpdateAvailable(_release, '1.2.0'));
    expect(find.text('A new version of FlashLearn PWD is ready'), findsOneWidget);
    expect(find.textContaining('Version 1.3.0 is on the website'), findsOneWidget);
    expect(find.text('How to update'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
  });

  testWidgets('up to date, offline or still checking shows nothing', (
    tester,
  ) async {
    for (final status in const <UpdateStatus>[
      UpToDate('1.2.0'),
      UpdateUnknown(),
    ]) {
      await _pump(tester, status);
      expect(find.byType(FilledButton), findsNothing, reason: '$status');
    }
  });

  testWidgets('speaks Filipino when the app does', (tester) async {
    await _pump(
      tester,
      const UpdateAvailable(_release, '1.2.0'),
      locale: const Locale('fil'),
    );
    expect(find.text('May bagong bersyon ng FlashLearn PWD'), findsOneWidget);
    expect(find.text('Paano mag-update'), findsOneWidget);
  });
}
