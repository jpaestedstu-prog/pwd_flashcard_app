import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/voice_navigation_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/teacher_analytics/screens/teacher_analytics_screen.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/parent_provider.dart';

/// Teacher and Parent share one implementation of every educator surface, so
/// the only thing that can drift is the copy — and it did. A Parent opening
/// Analytics was shown "Class Analytics", a "Students" counter, and a "Share
/// Class Code" button that pushed `/classroom-manage`, a screen that is not
/// theirs.
///
/// These tests hold the wording to the audience, and the CTA to the audience's
/// own manage route.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.role);
  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: role == UserRole.parent ? 'Mommy' : 'Sir Kevin',
    role: role,
    createdAt: DateTime(2026),
  );
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

Widget _analytics(UserRole role, {String locale = 'en'}) => ProviderScope(
  overrides: [
    profileProvider.overrideWith(() => _StubProfileNotifier(role)),
    settingsProvider.overrideWith(
      () => _FixedSettings(
        AppSettings(reducedMotion: true, locale: locale),
      ),
    ),
    // Empty roster: the empty state is where the wrong route lived.
    educatorRosterProvider.overrideWith((ref, id) async => const []),
  ],
  child: const MaterialApp(home: TeacherAnalyticsScreen()),
);

Widget _dashboard(UserRole role, {String locale = 'en'}) => ProviderScope(
  overrides: [
    profileProvider.overrideWith(() => _StubProfileNotifier(role)),
    settingsProvider.overrideWith(
      () => _FixedSettings(AppSettings(reducedMotion: true, locale: locale)),
    ),
    parentDashboardProvider.overrideWithValue(
      ParentDashboardSnapshot(timestamp: DateTime(2026), children: const []),
    ),
  ],
  child: MaterialApp(
    home: EducatorDashboardScreen(
      audience: role == UserRole.parent
          ? EducatorAudience.parent
          : EducatorAudience.teacher,
    ),
  ),
);

/// The analytics screen's backdrop animates forever, so `pumpAndSettle`
/// never returns here. Pump fixed steps instead and unmount explicitly.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  // Reading `voiceNavigationProvider` builds a real TtsService, and disposing
  // the container calls through to `flutter_tts`. Nothing here speaks, but the
  // teardown still needs a channel to talk to.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => 1,
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  group('EducatorAudience copy', () {
    test('every learner noun flips with the audience', () {
      const parent = EducatorAudience.parent;
      const teacher = EducatorAudience.teacher;

      expect(parent.learnerNounPlural, 'children');
      expect(parent.learnerNounPluralCap, 'Children');
      expect(parent.allLearnersTitle, 'All Children');
      expect(teacher.allLearnersTitle, 'All Students');

      // Irregular plural: "childs" is the failure this getter exists to stop.
      expect(parent.learnerNounPluralCap, isNot(contains('Childs')));
    });

    test('the manage route matches the audience, in both locales', () {
      expect(EducatorAudience.parent.manageRoute, '/home-group-manage');
      expect(EducatorAudience.teacher.manageRoute, '/classroom-manage');

      for (final filipino in [true, false]) {
        expect(
          EducatorAudience.parent.shareCodeLabel(filipino: filipino),
          contains('Home Group'),
        );
        expect(
          EducatorAudience.teacher.shareCodeLabel(filipino: filipino),
          contains('Class'),
        );
      }
    });

    test('a teacher never calls a student "your child"', () {
      expect(EducatorAudience.teacher.learnerPossessive, isNot(contains('child')));
      expect(EducatorAudience.parent.learnerPossessive, 'your child');
    });

    test('bilingual strings are filled in for both audiences', () {
      for (final audience in EducatorAudience.values) {
        for (final filipino in [true, false]) {
          expect(audience.analyticsTitle(filipino: filipino), isNotEmpty);
          expect(audience.learnersStatLabel(filipino: filipino), isNotEmpty);
          expect(audience.performanceTitle(filipino: filipino), isNotEmpty);
          expect(audience.compareTooltip(filipino: filipino), isNotEmpty);
          expect(audience.selectLearnersTitle(filipino: filipino), isNotEmpty);
          expect(audience.analyticsEmptyTitle(filipino: filipino), isNotEmpty);
          expect(audience.analyticsEmptyBody(filipino: filipino), isNotEmpty);
          expect(audience.needHelpTitle(filipino: filipino), isNotEmpty);
        }
      }
    });
  });

  group('Analytics screen', () {
    testWidgets('a teacher sees class wording', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_analytics(UserRole.teacher));
      await _settle(tester);

      expect(find.text('Class Analytics'), findsOneWidget);
      expect(find.text('No students yet'), findsOneWidget);
      expect(find.text('Share Class Code'), findsOneWidget);
    });

    testWidgets('a parent sees family wording', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_analytics(UserRole.parent));
      await _settle(tester);

      expect(find.text('Family Analytics'), findsOneWidget);
      expect(find.text('No children yet'), findsOneWidget);
      expect(find.text('Share Home Group Code'), findsOneWidget);

      expect(find.text('Class Analytics'), findsNothing);
      expect(find.textContaining('class code'), findsNothing);
    });

    testWidgets('Filipino keeps the audience split', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_analytics(UserRole.parent, locale: 'fil'));
      await _settle(tester);

      expect(find.text('Analytics ng Pamilya'), findsOneWidget);
      expect(find.text('Analytics ng Klase'), findsNothing);
    });
  });

  group('on-screen Filipino', () {
    // The spoken descriptions were localised before the screens were, so a
    // Filipino user heard "Lahat ng Anak" while reading "All Children".
    test('every localised getter is actually translated', () {
      for (final audience in EducatorAudience.values) {
        final pairs = <String, List<String>>{
          'dashboardTitle': [
            audience.dashboardTitle,
            audience.dashboardTitleOf(filipino: true),
          ],
          'overviewTitle': [
            audience.overviewTitle,
            audience.overviewTitleOf(filipino: true),
          ],
          'rosterTitle': [
            audience.rosterTitle,
            audience.rosterTitleOf(filipino: true),
          ],
          'allLearnersTitle': [
            audience.allLearnersTitle,
            audience.allLearnersTitleOf(filipino: true),
          ],
          'learnerNounPluralCap': [
            audience.learnerNounPluralCap,
            audience.learnerNounPluralCapOf(filipino: true),
          ],
          'learnerNounPlural': [
            audience.learnerNounPlural,
            audience.learnerNounPluralOf(filipino: true),
          ],
          'learnerNoun': [
            audience.learnerNoun,
            audience.learnerNounOf(filipino: true),
          ],
          'emptyDescription': [
            audience.emptyDescription,
            audience.emptyDescriptionOf(filipino: true),
          ],
          'manageTooltip': [
            audience.manageTooltip,
            audience.manageTooltipOf(filipino: true),
          ],
          'notesTooltip': [
            audience.notesTooltip,
            audience.notesTooltipOf(filipino: true),
          ],
          'learnerPossessive': [
            audience.learnerPossessive,
            audience.learnerPossessiveOf(filipino: true),
          ],
        };

        for (final entry in pairs.entries) {
          final [en, fil] = entry.value;
          expect(fil, isNotEmpty, reason: '${entry.key} (${audience.name})');
          expect(
            fil,
            isNot(en),
            reason: '${entry.key} (${audience.name}) is still English',
          );
        }
      }
    });

    test('the Filipino possessive carries no article of its own', () {
      // These land after "ng" and "ang" in the sentences that use them, so a
      // leading article would read as "ng ang estudyante".
      for (final audience in EducatorAudience.values) {
        final possessive = audience.learnerPossessiveOf(filipino: true);
        expect(possessive, isNot(startsWith('ang ')), reason: audience.name);
        expect(possessive, isNot(startsWith('ng ')), reason: audience.name);
      }
    });

    test('the Filipino nouns keep the parent and teacher split', () {
      expect(
        EducatorAudience.parent.allLearnersTitleOf(filipino: true),
        'Lahat ng Anak',
      );
      expect(
        EducatorAudience.teacher.allLearnersTitleOf(filipino: true),
        'Lahat ng Estudyante',
      );
      expect(
        EducatorAudience.parent.learnerNounPluralCapOf(filipino: true),
        'Mga Anak',
      );
      expect(
        EducatorAudience.teacher.learnerNounPluralCapOf(filipino: true),
        'Mga Estudyante',
      );
    });

    testWidgets('a Filipino parent reads Filipino on the dashboard', (
      tester,
    ) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_dashboard(UserRole.parent, locale: 'fil'));
      await _settle(tester);

      expect(find.text('Dashboard ng Magulang'), findsOneWidget);
      expect(find.text('Wala pang anak'), findsOneWidget);
      expect(find.text('Ibahagi ang Home Group Code'), findsOneWidget);

      expect(find.text('Parent Dashboard'), findsNothing);
      expect(find.text('No children yet'), findsNothing);
    });

    testWidgets('English is untouched', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_dashboard(UserRole.parent));
      await _settle(tester);

      expect(find.text('Parent Dashboard'), findsOneWidget);
      expect(find.text('No children yet'), findsOneWidget);
    });

    testWidgets('a Filipino teacher reads teacher nouns', (tester) async {
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(_dashboard(UserRole.teacher, locale: 'fil'));
      await _settle(tester);

      expect(find.text('Dashboard ng Guro'), findsOneWidget);
      expect(find.text('Wala pang estudyante'), findsOneWidget);
    });
  });

  group('voice route announcements', () {
    // Spoken descriptions are the only way a Visual-Impairment educator learns
    // what a screen is, so "All Students" on a Parent profile is the same
    // defect as the on-screen copy — they just cannot see it to report it.
    ({String name, String description}) describeAs(
      String route,
      EducatorAudience audience, {
      String locale = 'en',
    }) => VoiceNavigationService.describeRoute(
      route,
      locale: locale,
      audience: audience,
    );

    ({String name, String description}) describe(EducatorAudience audience) =>
        describeAs('/multi-dashboard', audience);

    test('a parent hears their children, a teacher their students', () {
      expect(describe(EducatorAudience.parent).name, 'All Children');
      expect(
        describe(EducatorAudience.parent).description,
        'View progress for all your children.',
      );

      expect(describe(EducatorAudience.teacher).name, 'All Students');
      expect(
        describe(EducatorAudience.teacher).description,
        'View progress for all your students.',
      );
    });

    test('the static keeps the teacher wording by default', () {
      // Callers that cannot know the audience get what these strings have
      // always said, rather than a parent-flavoured surprise.
      final info = VoiceNavigationService.describeRoute('/multi-dashboard');
      expect(info.name, 'All Students');
    });

    test('the shared Analytics tab follows the reader in both languages', () {
      // Reachable by both educator roles, unlike the two role-specific
      // dashboards below it.
      expect(
        describeAs('/teacher-analytics', EducatorAudience.parent).name,
        'Family Analytics',
      );
      expect(
        describeAs('/teacher-analytics', EducatorAudience.teacher).name,
        'Class Analytics',
      );
      expect(
        describeAs(
          '/teacher-analytics',
          EducatorAudience.parent,
          locale: 'fil',
        ).name,
        'Analytics ng Pamilya',
      );
    });

    test('the role-specific dashboards name their own learners', () {
      // A parent can only reach the parent route, so these are fixed rather
      // than audience-driven — that is what stops a mismatch.
      expect(
        describeAs('/parent-dashboard', EducatorAudience.parent).description,
        contains('children'),
      );
      expect(
        describeAs('/teacher-dashboard', EducatorAudience.teacher).description,
        contains('students'),
      );
    });

    test('an unknown route falls back in the right language', () {
      expect(
        VoiceNavigationService.describeRoute('/nope', locale: 'fil').name,
        'Pahina',
      );
      expect(VoiceNavigationService.describeRoute('/nope').name, 'Page');
    });

    testWidgets('the service takes its audience from the signed-in profile',
        (tester) async {
      // Through the real provider: the wiring is the part that broke, not the
      // switch statement.
      for (final (role, expected) in [
        (UserRole.parent, 'All Children'),
        (UserRole.teacher, 'All Students'),
      ]) {
        final container = ProviderContainer(
          overrides: [
            profileProvider.overrideWith(() => _StubProfileNotifier(role)),
            settingsProvider.overrideWith(
              () => _FixedSettings(const AppSettings(reducedMotion: true)),
            ),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(voiceNavigationProvider);
        expect(
          service.describeRouteForViewer('/multi-dashboard').name,
          expected,
          reason: role.name,
        );
      }
    });
  });

  group('educatorAudienceProvider', () {
    ProviderContainer containerFor(UserRole role) {
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(role)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a parent profile resolves to the parent audience', () {
      expect(
        containerFor(UserRole.parent).read(educatorAudienceProvider),
        EducatorAudience.parent,
      );
    });

    test('every other role resolves to the teacher audience', () {
      for (final role in [UserRole.teacher, UserRole.student, UserRole.child]) {
        expect(
          containerFor(role).read(educatorAudienceProvider),
          EducatorAudience.teacher,
          reason: role.name,
        );
      }
    });
  });
}
