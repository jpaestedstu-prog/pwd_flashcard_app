import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/onboarding/widgets/profile_setup_form.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

/// Pumps [ProfileSetupForm] inside a localized Form and returns the form key
/// so the test can trigger validation directly.
Future<GlobalKey<FormState>> _pumpForm(
  WidgetTester tester, {
  required UserRole role,
  required TextEditingController nameController,
  bool showBirthDate = false,
}) async {
  final formKey = GlobalKey<FormState>();
  final pinController = TextEditingController();
  final pinConfirmController = TextEditingController();
  addTearDown(pinController.dispose);
  addTearDown(pinConfirmController.dispose);

  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: ProfileSetupForm(
              role: role,
              nameController: nameController,
              selectedAvatarIndex: 0,
              onAvatarSelected: (_) {},
              showBirthDate: showBirthDate,
              enablePin: false,
              onTogglePin: (_) {},
              pinController: pinController,
              pinConfirmController: pinConfirmController,
            ),
          ),
        ),
      ),
    ),
  );
  // Let the one-shot entrance animations settle without hanging (no looping
  // animations live in this widget).
  await tester.pump(const Duration(milliseconds: 500));
  return formKey;
}

void main() {
  group('ProfileSetupForm validation', () {
    testWidgets('rejects an empty name with a localized error',
        (tester) async {
      final nameController = TextEditingController();
      addTearDown(nameController.dispose);

      final formKey = await _pumpForm(
        tester,
        role: UserRole.player,
        nameController: nameController,
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please enter a name'), findsOneWidget);
    });

    testWidgets('rejects a one-character name', (tester) async {
      final nameController = TextEditingController(text: 'A');
      addTearDown(nameController.dispose);

      final formKey = await _pumpForm(
        tester,
        role: UserRole.teacher,
        nameController: nameController,
      );

      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    });

    testWidgets('accepts a valid name (no errors)', (tester) async {
      final nameController = TextEditingController(text: 'Maria');
      addTearDown(nameController.dispose);

      final formKey = await _pumpForm(
        tester,
        role: UserRole.parent,
        nameController: nameController,
      );

      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Please enter a name'), findsNothing);
      expect(find.text('Name must be at least 2 characters'), findsNothing);
    });

    testWidgets('requires a birth date when showBirthDate is true',
        (tester) async {
      final nameController = TextEditingController(text: 'Junior');
      addTearDown(nameController.dispose);

      final formKey = await _pumpForm(
        tester,
        role: UserRole.student,
        nameController: nameController,
        showBirthDate: true,
      );

      // Name is valid but the (untouched) birth date should fail validation.
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please select a birth date'), findsOneWidget);
    });
  });

  group('Welcome carousel gate (HiveService)', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/welcome_gate');
      if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
      if (!Hive.isBoxOpen('progress')) await Hive.openBox('progress');
      if (!Hive.isBoxOpen('profiles')) await Hive.openBox('profiles');
    });

    setUp(() async {
      await Hive.box('settings').clear();
    });

    test('defaults to not-seen, then markWelcomeSeen flips it', () async {
      expect(HiveService.hasSeenWelcome(), isFalse);
      await HiveService.markWelcomeSeen();
      expect(HiveService.hasSeenWelcome(), isTrue);
    });
  });

  group('Splash first-run routing decision', () {
    // Mirrors the branch logic in SplashScreen._scheduleNavigation so the
    // welcome carousel is only inserted on a true first run.
    String decideRoute({
      required int profileCount,
      required bool hasActiveId,
      required bool seenWelcome,
    }) {
      if (profileCount > 1) return '/profile-switcher';
      if (profileCount > 0 && hasActiveId) return '/home';
      if (!seenWelcome) return '/welcome';
      return '/profile';
    }

    test('first launch, nothing seen -> welcome', () {
      expect(
        decideRoute(profileCount: 0, hasActiveId: false, seenWelcome: false),
        '/welcome',
      );
    });

    test('welcome already seen, still no profile -> profile picker', () {
      expect(
        decideRoute(profileCount: 0, hasActiveId: false, seenWelcome: true),
        '/profile',
      );
    });

    test('single active profile -> home (never welcome)', () {
      expect(
        decideRoute(profileCount: 1, hasActiveId: true, seenWelcome: false),
        '/home',
      );
    });

    test('multiple profiles -> switcher', () {
      expect(
        decideRoute(profileCount: 2, hasActiveId: true, seenWelcome: true),
        '/profile-switcher',
      );
    });
  });
}
