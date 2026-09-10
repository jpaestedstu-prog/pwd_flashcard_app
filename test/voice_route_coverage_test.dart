import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/voice_navigation_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/models/educator_audience.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Every screen a Voice-Guided Navigation user can reach must say something,
/// in both languages.
///
/// Walks the *real* router rather than a hand-kept list, so adding a screen
/// without a description fails here. That is the failure mode this feature
/// keeps having: the Filipino map once covered 6 routes out of 18, and nobody
/// noticed because nothing compared it against the app.

class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'e1',
    name: 'Sir Kevin',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

/// Screens that deliberately say nothing.
const _intentionallySilent = <String>{
  // On screen for well under a second, and `_speak` stops the previous
  // utterance — announcing it would only truncate the announcement for
  // whichever screen the splash redirects to.
  '/splash',
};

List<String> _fullPaths(List<RouteBase> routes, String prefix) {
  final out = <String>[];
  for (final route in routes) {
    var here = prefix;
    if (route is GoRoute) {
      here = route.path.startsWith('/') ? route.path : '$prefix/${route.path}';
      out.add(here);
    }
    out.addAll(_fullPaths(route.routes, here));
  }
  return out;
}

void main() {
  late List<String> appRoutes;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer(
      overrides: [profileProvider.overrideWith(_StubProfile.new)],
    );
    addTearDown(container.dispose);
    appRoutes =
        _fullPaths(container.read(routerProvider).configuration.routes, '')
          ..sort();
  });

  test('the router is fully walked', () {
    // A sanity floor: if this collapses, the walk broke rather than the app
    // shrinking, and every other assertion here would pass vacuously.
    expect(appRoutes.length, greaterThan(120));
    expect(appRoutes, contains('/home'));
    expect(appRoutes, contains('/games/word-match'));
    expect(appRoutes, contains('/child-alarms/:profileId'));
  });

  test('every route has an English description', () {
    final missing = appRoutes
        .where((r) => !_intentionallySilent.contains(r))
        .where((r) => VoiceNavigationService.describeRoute(r).description.isEmpty)
        .toList();
    expect(missing, isEmpty, reason: 'no English voice description');
  });

  test('every route has a Filipino description', () {
    final missing = appRoutes
        .where((r) => !_intentionallySilent.contains(r))
        .where(
          (r) => VoiceNavigationService.describeRoute(
            r,
            locale: 'fil',
          ).description.isEmpty,
        )
        .toList();
    expect(missing, isEmpty, reason: 'no Filipino voice description');
  });

  test('Filipino is a translation, not a copy of the English', () {
    final untranslated = <String>[];
    for (final route in appRoutes) {
      if (_intentionallySilent.contains(route)) continue;
      final en = VoiceNavigationService.describeRoute(route);
      final fil = VoiceNavigationService.describeRoute(route, locale: 'fil');
      if (en.description == fil.description) untranslated.add(route);
    }
    expect(untranslated, isEmpty, reason: 'still reads English in Filipino');
  });

  test('no described route has gone stale', () {
    // The other direction: a description for a screen that no longer exists is
    // dead weight, and hides the fact that its replacement has none.
    final orphans = VoiceNavigationService.describedRoutes
        .where((r) => !appRoutes.contains(r))
        .toList();
    expect(orphans, isEmpty, reason: 'described but not routed any more');
  });

  test('silent routes are silent on purpose, and stay real routes', () {
    for (final route in _intentionallySilent) {
      expect(appRoutes, contains(route));
      expect(VoiceNavigationService.describeRoute(route).description, isEmpty);
    }
  });

  group('audience-aware routes', () {
    // Anything that names the learners has to follow the reader. A Parent
    // hearing "your students" is the defect this whole area keeps producing.
    const learnerRoutes = <String>[
      '/multi-dashboard',
      '/teacher-analytics',
      '/weekly-reports',
      '/classroom',
      '/student-comparison',
      '/student-profiles',
      '/student-profile-detail',
      '/progress-timeline/:profileId',
      '/child-alarms/:profileId',
      '/child-time-limits/:profileId',
      '/assessment/assign',
    ];

    test('learner nouns follow the reader, in both languages', () {
      // Each audience must never hear the other role's noun. Driven from a map
      // so the audience is a variable, and so adding a third role would force
      // its forbidden words to be stated.
      const forbidden = <EducatorAudience, List<String>>{
        EducatorAudience.parent: ['student', 'estudyante'],
        EducatorAudience.teacher: ['child', 'anak'],
      };

      for (final entry in forbidden.entries) {
        for (final route in learnerRoutes) {
          for (final locale in ['en', 'fil']) {
            final copy = VoiceNavigationService.describeRoute(
              route,
              locale: locale,
              audience: entry.key,
            );
            final spoken = '${copy.name}. ${copy.description}'.toLowerCase();
            for (final word in entry.value) {
              expect(
                spoken,
                isNot(contains(word)),
                reason: '$route ($locale, ${entry.key.name}) said "$word"',
              );
            }
          }
        }
      }
    });

    test('the two role-specific dashboards keep their own nouns', () {
      // Not audience-driven: a parent can only reach the parent route, so the
      // route itself is the more reliable signal.
      expect(
        VoiceNavigationService.describeRoute('/parent-dashboard').description,
        contains('children'),
      );
      expect(
        VoiceNavigationService.describeRoute('/teacher-dashboard').description,
        contains('students'),
      );
    });
  });
}
