import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/help/screens/guide_screen.dart';
import 'package:pwdpwdpwd/features/help/screens/help_center_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(id: 'p-${role.name}', name: 'Test', role: role, createdAt: DateTime(2026));
}

class _Settings extends SettingsNotifier {
  _Settings(this.locale);
  final String locale;
  @override
  AppSettings build() => AppSettings(locale: locale);
}

/// Help & Guides (`/help`, `/help/:guideId`) as each kind of profile sees it.
void main() {
  Future<void> pump(WidgetTester tester, Widget screen,
      {UserRole role = UserRole.student, String locale = 'en', bool screenReader = false}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileProvider.overrideWith(() => _Profile(role)),
        settingsProvider.overrideWith(() => _Settings(locale)),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: screenReader),
          child: child!,
        ),
        home: screen,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Set<String> texts(WidgetTester tester) => {
        for (final t in tester.widgetList<Text>(find.byType(Text)))
          ?(t.data ?? t.textSpan?.toPlainText()),
      };

  testWidgets('a student sees their own guide and every way to use the app, no teacher guides',
      (tester) async {
    await pump(tester, const HelpCenterScreen());
    final seen = texts(tester);
    expect(seen, contains('Help & Guides'));
    for (final title in ['For students', 'Accessibility options', 'Gaze Control', 'Voice commands',
        'Game controller', 'Screen reader (TalkBack)', 'Keyboard and switches', 'Rate & Feedback']) {
      expect(seen, contains(title), reason: title);
    }
    for (final title in ['For teachers', 'For parents', 'TV Cast', 'Time limits, breaks and routines']) {
      expect(seen, isNot(contains(title)), reason: title);
    }
  });

  testWidgets('a teacher sees the teacher guides first', (tester) async {
    await pump(tester, const HelpCenterScreen(), role: UserRole.teacher);
    final teachers = tester.getTopLeft(find.text('For teachers')).dy;
    final students = tester.getTopLeft(find.text('For students')).dy;
    expect(teachers, lessThan(students));
    expect(texts(tester), contains('TV Cast'));
  });

  testWidgets('Filipino profile: the list is in Filipino', (tester) async {
    await pump(tester, const HelpCenterScreen(), locale: 'fil');
    final seen = texts(tester);
    expect(seen, contains('Tulong at mga Gabay'));
    expect(seen, contains('Para sa mag-aaral'));
  });

  testWidgets('a guide shows its numbered steps and offers Read aloud', (tester) async {
    await pump(tester, const GuideScreen(guideId: 'voice'));
    final seen = texts(tester);
    expect(seen, contains('Voice commands'));
    expect(seen, contains('What to say'));
    expect(seen.any((s) => s.contains('Voice only (camera off)')), isTrue);
    expect(find.text('Read aloud'), findsOneWidget);
    expect(find.text('1'), findsWidgets, reason: 'steps are numbered');
  });

  testWidgets('with a screen reader running, Read aloud steps aside (TalkBack reads the page)',
      (tester) async {
    await pump(tester, const GuideScreen(guideId: 'voice'), screenReader: true);
    expect(find.text('Read aloud'), findsNothing);
    expect(texts(tester), contains('What to say'));
  });

  testWidgets('the Rate & Feedback guide has a button to the form', (tester) async {
    await pump(tester, const GuideScreen(guideId: 'feedback'));
    expect(find.text('Open the feedback form'), findsOneWidget);
  });

  testWidgets('an unknown guide says so instead of a blank page', (tester) async {
    await pump(tester, const GuideScreen(guideId: 'nope'));
    expect(find.text('This guide could not be found.'), findsOneWidget);
  });
}
