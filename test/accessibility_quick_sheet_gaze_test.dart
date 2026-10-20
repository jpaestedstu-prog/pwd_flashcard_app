import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart'
    show AppSettings, UserProfile;
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;
import 'package:pwdpwdpwd/widgets/accessibility_quick_sheet.dart';

/// The Child and Guest Player homes have no Settings gear — Settings stays
/// parent-managed — and Settings was the only way into Gaze Control. So a
/// child whose gaze was switched on at setup could never have its sensitivity,
/// hold time, scanning, voice or calibration changed by anyone. The child-safe
/// accessibility sheet those homes do offer now opens Gaze Control too — and
/// the game controller, which had the same gap: a blind child driving the app
/// with one could never swap its A/B buttons or hear its button guide.

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// Keeps changes in memory: no Hive in these tests.
class _MemorySettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
  @override
  void update(AppSettings newSettings) => state = newSettings;
  @override
  void updateLocale(String locale) => state = state.copyWith(locale: locale);
}

class _Signed extends ProfileNotifier {
  _Signed(this.role, {this.guest = false});
  final UserRole role;
  final bool guest;
  @override
  UserProfile? build() => UserProfile(
        id: 'p',
        name: 'P',
        role: role,
        isGuestPlayer: guest,
        createdAt: DateTime(2026),
      );
}

Future<GoRouter> _pumpSheet(WidgetTester tester, ProfileNotifier profile) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAccessibilityQuickSheet(ctx),
              child: const Text('open-sheet'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/gaze-settings',
        builder: (context, state) =>
            const Scaffold(body: Text('gaze-settings-page')),
      ),
      GoRoute(
        path: '/gamepad-settings',
        builder: (context, state) =>
            const Scaffold(body: Text('gamepad-settings-page')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      settingsProvider.overrideWith(_StubAppSettings.new),
      profileProvider.overrideWith(() => profile),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.tap(find.text('open-sheet'));
  await tester.pumpAndSettle();
  return router;
}

Future<void> _open(WidgetTester tester, String title) async {
  final entry = find.text(title);
  await tester.scrollUntilVisible(
    entry,
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

void main() {
  for (final entry in {
    'a Child': () => _Signed(UserRole.child),
    'a guest Player': () => _Signed(UserRole.player, guest: true),
  }.entries) {
    testWidgets('the sheet opens Gaze Control for ${entry.key}',
        (tester) async {
      await _pumpSheet(tester, entry.value());
      await _open(tester, 'Gaze Control (Preview)');
      expect(find.text('gaze-settings-page'), findsOneWidget);
    });

    testWidgets('the sheet opens the Game Controller for ${entry.key}',
        (tester) async {
      await _pumpSheet(tester, entry.value());
      await _open(tester, 'Game Controller');
      expect(find.text('gamepad-settings-page'), findsOneWidget);
    });
  }

  // Settings was also the only place to choose the app's language and to
  // switch spoken navigation, so a Child or a guest could do neither.
  testWidgets('a Child can switch the app to Filipino and back',
      (tester) async {
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(_MemorySettings.new),
      profileProvider.overrideWith(() => _Signed(UserRole.child)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAccessibilityQuickSheet(ctx),
              child: const Text('open-sheet'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    final filipino = find.text('Filipino');
    await tester.scrollUntilVisible(
      filipino,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    // Each choice says what it does to a screen reader.
    final handle = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Use the app in Filipino'), findsOneWidget);
    handle.dispose();
    await tester.tap(filipino);
    await tester.pump();
    expect(container.read(settingsProvider).locale, 'fil');

    // The sheet now reads in Filipino; English is still one tap away.
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pump();
    expect(container.read(settingsProvider).locale, 'en');
  });

  testWidgets('a Child can switch Voice-Guided Navigation', (tester) async {
    final container = ProviderContainer(overrides: [
      settingsProvider.overrideWith(_MemorySettings.new),
      profileProvider.overrideWith(() => _Signed(UserRole.child)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => showAccessibilityQuickSheet(ctx),
              child: const Text('open-sheet'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();
    final row = find.text('Voice-Guided Navigation');
    await tester.scrollUntilVisible(
      row,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(row);
    await tester.pump();
    expect(container.read(settingsProvider).voiceNavigation, isTrue);
  });

  // The sheet sits on learner homes only, but the rule is the profile's: a
  // Teacher or Parent never runs either as their own input.
  testWidgets('offers neither to a Teacher', (tester) async {
    await _pumpSheet(tester, _Signed(UserRole.teacher));
    expect(find.text('Gaze Control (Preview)'), findsNothing);
    expect(find.text('Game Controller'), findsNothing);
    // The display switches are everyone's.
    expect(find.text('High Contrast'), findsOneWidget);
  });
}
