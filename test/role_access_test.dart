import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Route guard logic (unit tests) ──────────────────

  /// Mirrors the route guard lists from app_router.dart
  const educatorOnlyRoutes = [
    '/dashboard',
    '/multi-dashboard',
    '/teacher-analytics',
    '/classroom',
    '/parent-dashboard',
    '/weekly-reports',
    '/assessment/builder',
    '/worksheets',
    '/adaptive-analytics',
  ];

  const studentOnlyRoutes = [
    '/shop',
    '/sticker-album',
  ];

  /// Simulates the redirect logic from app_router.dart
  String? simulateRedirect(UserRole role, String location) {
    if (role == UserRole.student) {
      for (final route in educatorOnlyRoutes) {
        if (location.startsWith(route)) return '/home';
      }
    } else {
      for (final route in studentOnlyRoutes) {
        if (location.startsWith(route)) return '/home';
      }
    }
    return null; // no redirect
  }

  group('Role-based route guard', () {
    test('student is blocked from educator-only routes', () {
      for (final route in educatorOnlyRoutes) {
        expect(
          simulateRedirect(UserRole.student, route),
          '/home',
          reason: 'Student should be blocked from $route',
        );
      }
    });

    test('student can access learning routes', () {
      const studentRoutes = [
        '/home',
        '/flashcards',
        '/games',
        '/stories',
        '/progress',
        '/shop',
        '/sticker-album',
        '/games/word-match',
        '/smart-review',
        '/daily-challenge',
        '/leaderboard',
      ];
      for (final route in studentRoutes) {
        expect(
          simulateRedirect(UserRole.student, route),
          isNull,
          reason: 'Student should access $route',
        );
      }
    });

    test('teacher is blocked from student-only routes', () {
      for (final route in studentOnlyRoutes) {
        expect(
          simulateRedirect(UserRole.teacher, route),
          '/home',
          reason: 'Teacher should be blocked from $route',
        );
      }
    });

    test('parent is blocked from student-only routes', () {
      for (final route in studentOnlyRoutes) {
        expect(
          simulateRedirect(UserRole.parent, route),
          '/home',
          reason: 'Parent should be blocked from $route',
        );
      }
    });

    test('teacher can access educator routes', () {
      for (final route in educatorOnlyRoutes) {
        expect(
          simulateRedirect(UserRole.teacher, route),
          isNull,
          reason: 'Teacher should access $route',
        );
      }
    });

    test('parent can access educator routes', () {
      for (final route in educatorOnlyRoutes) {
        expect(
          simulateRedirect(UserRole.parent, route),
          isNull,
          reason: 'Parent should access $route',
        );
      }
    });

    test('all roles can access shared routes', () {
      const sharedRoutes = [
        '/home',
        '/settings',
        '/assessment',
        '/messages',
        '/recommendations',
      ];
      for (final role in UserRole.values) {
        for (final route in sharedRoutes) {
          expect(
            simulateRedirect(role, route),
            isNull,
            reason: '${role.name} should access $route',
          );
        }
      }
    });
  });

  // ─── Bottom nav tab configuration (unit tests) ──────

  group('Role-based bottom navigation', () {
    const studentPaths = [
      '/home',
      '/flashcards',
      '/games',
      '/stories',
      '/progress',
    ];
    const educatorPaths = [
      '/home',
      '/multi-dashboard',
      '/teacher-analytics',
      '/weekly-reports',
      '/settings',
    ];

    int currentIndex(List<String> paths, String location) {
      for (int i = paths.length - 1; i >= 0; i--) {
        if (location.startsWith(paths[i])) return i;
      }
      return 0;
    }

    test('student nav has 5 learning-focused tabs', () {
      expect(studentPaths.length, 5);
      expect(studentPaths, contains('/flashcards'));
      expect(studentPaths, contains('/games'));
      expect(studentPaths, contains('/stories'));
    });

    test('educator nav has 5 management-focused tabs', () {
      expect(educatorPaths.length, 5);
      expect(educatorPaths, contains('/multi-dashboard'));
      expect(educatorPaths, contains('/teacher-analytics'));
      expect(educatorPaths, contains('/weekly-reports'));
    });

    test('student tab index resolves correctly', () {
      expect(currentIndex(studentPaths, '/home'), 0);
      expect(currentIndex(studentPaths, '/flashcards'), 1);
      expect(currentIndex(studentPaths, '/flashcards/viewer/3'), 1);
      expect(currentIndex(studentPaths, '/games'), 2);
      expect(currentIndex(studentPaths, '/games/word-match'), 2);
      expect(currentIndex(studentPaths, '/stories'), 3);
      expect(currentIndex(studentPaths, '/progress'), 4);
    });

    test('educator tab index resolves correctly', () {
      expect(currentIndex(educatorPaths, '/home'), 0);
      expect(currentIndex(educatorPaths, '/multi-dashboard'), 1);
      expect(currentIndex(educatorPaths, '/teacher-analytics'), 2);
      expect(currentIndex(educatorPaths, '/weekly-reports'), 3);
      expect(currentIndex(educatorPaths, '/settings'), 4);
    });

    test('unknown route defaults to index 0', () {
      expect(currentIndex(studentPaths, '/unknown-route'), 0);
      expect(currentIndex(educatorPaths, '/unknown-route'), 0);
    });
  });

  // ─── UserRole enum tests ────────────────────────────

  group('UserRole role checks', () {
    test('student is not educator', () {
      const role = UserRole.student;
      const isEducator =
          role == UserRole.teacher || role == UserRole.parent;
      expect(isEducator, false);
    });

    test('teacher is educator', () {
      const role = UserRole.teacher;
      const isEducator =
          role == UserRole.teacher || role == UserRole.parent;
      expect(isEducator, true);
    });

    test('parent is educator', () {
      const role = UserRole.parent;
      const isEducator =
          role == UserRole.teacher || role == UserRole.parent;
      expect(isEducator, true);
    });

    test('UserRole has exactly 5 values (student, teacher, parent, child, player)', () {
      expect(UserRole.values.length, 5);
      // Existing roles must keep their indices so older Hive-stored
      // profiles continue to deserialize correctly.
      expect(UserRole.student.index, 0);
      expect(UserRole.teacher.index, 1);
      expect(UserRole.parent.index, 2);
      expect(UserRole.child.index, 3);
      expect(UserRole.player.index, 4);
    });
  });
}
