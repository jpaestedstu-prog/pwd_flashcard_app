import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;
import 'package:pwdpwdpwd/widgets/accessibility_quick_sheet.dart';

/// The Child and Guest Player homes have no Settings gear — Settings stays
/// parent-managed — and Settings was the only way into Gaze Control. So a
/// child whose gaze was switched on at setup could never have its sensitivity,
/// hold time, scanning, voice or calibration changed by anyone. The child-safe
/// accessibility sheet those homes do offer now opens Gaze Control too.

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  testWidgets('the child-safe accessibility sheet opens Gaze Control',
      (tester) async {
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
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [settingsProvider.overrideWith(_StubAppSettings.new)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.tap(find.text('open-sheet'));
    await tester.pumpAndSettle();

    final entry = find.text('Gaze Control (Preview)');
    await tester.scrollUntilVisible(
      entry,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('gaze-settings-page'), findsOneWidget);
  });
}
