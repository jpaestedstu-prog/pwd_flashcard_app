import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/profile_selection_screen.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/role_setup_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// Verifies the two Player profile types and the PWD-awareness entry without
/// needing the native build (which fails on this machine's long project path).
/// Nothing here taps Submit, so no Hive write is triggered.
Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );

void main() {
  testWidgets(
      'Profile selection groups roles (Player Profiles / Classroom / Family '
      'Group) and offers Guest + With-Progress players and a PWD-awareness '
      'entry', (tester) async {
    await tester.pumpWidget(_wrap(const ProfileSelectionScreen()));
    await tester.pump(const Duration(milliseconds: 600)); // settle entrance anims

    expect(find.text('Guest Player'), findsOneWidget);
    expect(find.text('Player (with Progress)'), findsOneWidget);
    expect(find.text('Learn about PWD awareness'), findsOneWidget);
    // Grouped section headers
    expect(find.text('Player Profiles'), findsOneWidget);
    expect(find.text('Classroom'), findsOneWidget);
    expect(find.text('Family Group'), findsOneWidget);
  });

  testWidgets(
      'Player (With Progress) setup collects a birth date, like Student/Child',
      (tester) async {
    await tester.pumpWidget(
      _wrap(const RoleSetupScreen(role: UserRole.player, guestPlayer: false)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The birth-date field is identified by its unique cake prefix icon.
    expect(find.byIcon(Icons.cake_rounded), findsOneWidget);
  });

  testWidgets('Player (Guest) setup stays minimal — no birth-date field',
      (tester) async {
    await tester.pumpWidget(
      // guestPlayer: true is the default, but stated explicitly to mirror the
      // "with progress" case above and document the intent of this test.
      // ignore: avoid_redundant_argument_values
      _wrap(const RoleSetupScreen(role: UserRole.player, guestPlayer: true)),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byIcon(Icons.cake_rounded), findsNothing);
  });
}
