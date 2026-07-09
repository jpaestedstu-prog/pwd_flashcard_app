import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/widgets/tutorial_overlay.dart';

void main() {
  // ═══════════════════════════════════════════════════════════
  // AppError Model Tests
  // ═══════════════════════════════════════════════════════════

  group('AppError', () {
    test('toJson → fromJson roundtrip preserves all fields', () {
      final error = AppError(
        message: 'Test error',
        source: 'UnitTest',
        context: 'Some context',
        timestamp: DateTime(2025, 6, 20, 14, 30),
        stackTrace: '#0 main (test.dart:10)',
      );

      final json = error.toJson();
      final restored = AppError.fromJson(json);

      expect(restored.message, 'Test error');
      expect(restored.source, 'UnitTest');
      expect(restored.context, 'Some context');
      expect(restored.timestamp, DateTime(2025, 6, 20, 14, 30));
      expect(restored.stackTrace, '#0 main (test.dart:10)');
    });

    test('fromJson handles missing optional fields', () {
      final json = <String, dynamic>{
        'message': 'Minimal error',
        'source': 'Test',
        'timestamp': '2025-06-20T00:00:00.000',
      };
      final error = AppError.fromJson(json);
      expect(error.context, isNull);
      expect(error.stackTrace, isNull);
    });

    test('fromJson handles completely empty map', () {
      final error = AppError.fromJson(<String, dynamic>{});
      expect(error.message, 'Unknown error');
      expect(error.source, 'Unknown');
    });

    test('userMessage returns network error for SocketException', () {
      final error = AppError(
        message: 'SocketException: Connection refused',
        source: 'Test',
        timestamp: DateTime.now(),
      );
      expect(error.userMessage, 'Network error. Please check your connection.');
    });

    test('userMessage returns network error for NetworkException', () {
      final error = AppError(
        message: 'NetworkException: No internet',
        source: 'Test',
        timestamp: DateTime.now(),
      );
      expect(error.userMessage, 'Network error. Please check your connection.');
    });

    test('userMessage returns format error for FormatException', () {
      final error = AppError(
        message: 'FormatException: Invalid JSON',
        source: 'Test',
        timestamp: DateTime.now(),
      );
      expect(
          error.userMessage, 'Data format error. Some data may be corrupted.');
    });

    test('userMessage returns timeout error for TimeoutException', () {
      final error = AppError(
        message: 'TimeoutException after 30s',
        source: 'Test',
        timestamp: DateTime.now(),
      );
      expect(
          error.userMessage, 'Operation timed out. Please try again.');
    });

    test('userMessage returns generic message for unknown errors', () {
      final error = AppError(
        message: 'Some random failure',
        source: 'Test',
        timestamp: DateTime.now(),
      );
      expect(error.userMessage,
          'Something went wrong. The app will continue working.');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // ErrorHandler Stream Tests
  // ═══════════════════════════════════════════════════════════

  group('ErrorHandler constants', () {
    test('errorStream is a broadcast stream', () {
      // Verify the stream exists and is broadcast (can have multiple listeners)
      expect(ErrorHandler.errorStream, isNotNull);
      expect(ErrorHandler.errorStream.isBroadcast, true);
    });
  });

  group('ErrorHandler silent sources', () {
    // Regression: non-critical / recoverable failures must NOT raise the
    // global "Something went wrong" snackbar at a PWD learner —
    //   • feedback: the audioplayers "Bad state: No element" race on the
    //     first sound after launch (SoundService / CelebrationService).
    //   • framework diagnostics: a benign FlutterError assertion such as the
    //     ListTile ink/background-hidden warning that fires on the student
    //     home right after joining a class (FrameworkDiagnostic:silent).
    // These sources are logged for diagnostics but suppressed from
    // errorStream, while genuine user-actionable sources still surface.
    test('non-critical sources are suppressed; real sources still surface',
        () async {
      final received = <String>[];
      final sub =
          ErrorHandler.errorStream.listen((e) => received.add(e.source));
      addTearDown(sub.cancel);

      ErrorHandler.report(
          StateError('Bad state: No element'), null, 'SoundService');
      ErrorHandler.report(Exception('haptic glitch'), null, 'CelebrationService');
      ErrorHandler.report(
          Exception('ListTile ink hidden'), null, 'FrameworkDiagnostic:silent');
      ErrorHandler.report(Exception('real problem'), null, 'SomeFeature');

      // Broadcast streams deliver asynchronously — let the queue drain.
      await Future<void>.delayed(Duration.zero);

      expect(received, isNot(contains('SoundService')));
      expect(received, isNot(contains('CelebrationService')));
      expect(received, isNot(contains('FrameworkDiagnostic:silent')));
      expect(received, contains('SomeFeature'));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // UserProfile PIN Tests
  // ═══════════════════════════════════════════════════════════

  group('UserProfile — PIN protection', () {
    final baseProfile = UserProfile(
      id: 'test-user-1',
      name: 'Test Student',
      role: UserRole.student,
      createdAt: DateTime(2025),
    );

    test('default profile has no PIN', () {
      expect(baseProfile.pin, isNull);
      expect(baseProfile.hasPinProtection, false);
    });

    test('profile with 4-digit PIN has protection', () {
      final withPin = baseProfile.copyWith(pin: () => '1234');
      expect(withPin.pin, '1234');
      expect(withPin.hasPinProtection, true);
    });

    test('profile with short PIN has no protection', () {
      final shortPin = baseProfile.copyWith(pin: () => '12');
      expect(shortPin.pin, '12');
      expect(shortPin.hasPinProtection, false);
    });

    test('copyWith can remove PIN by returning null', () {
      final withPin = baseProfile.copyWith(pin: () => '5678');
      expect(withPin.hasPinProtection, true);

      final removed = withPin.copyWith(pin: () => null);
      expect(removed.pin, isNull);
      expect(removed.hasPinProtection, false);
    });

    test('copyWith without pin parameter preserves existing PIN', () {
      final withPin = baseProfile.copyWith(pin: () => '9999');
      final updated = withPin.copyWith(name: 'New Name');
      expect(updated.name, 'New Name');
      expect(updated.pin, '9999'); // preserved
    });

    test('copyWith preserves all other fields when setting PIN', () {
      final profile = UserProfile(
        id: 'u1',
        name: 'Maria',
        role: UserRole.teacher,
        avatarIndex: 3,
        createdAt: DateTime(2025, 3, 15),
        disabilityType: DisabilityType.visual,
      );
      final withPin = profile.copyWith(pin: () => '0000');
      expect(withPin.id, 'u1');
      expect(withPin.name, 'Maria');
      expect(withPin.role, UserRole.teacher);
      expect(withPin.avatarIndex, 3);
      expect(withPin.createdAt, DateTime(2025, 3, 15));
      expect(withPin.disabilityType, DisabilityType.visual);
      expect(withPin.pin, '0000');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Tutorial Steps for Roles
  // ═══════════════════════════════════════════════════════════

  group('tutorialStepsForRole', () {
    test('returns student steps for student role', () {
      final steps = tutorialStepsForRole(UserRole.student);
      expect(steps, same(homeTutorialSteps));
      expect(steps.length, 6);
      expect(steps.first.title, contains('Welcome to FlashLearn'));
    });

    test('returns teacher steps for teacher role', () {
      final steps = tutorialStepsForRole(UserRole.teacher);
      expect(steps, same(teacherTutorialSteps));
      expect(steps.length, 6);
      expect(steps.first.title, contains('Teacher'));
    });

    test('returns parent steps for parent role', () {
      final steps = tutorialStepsForRole(UserRole.parent);
      expect(steps, same(parentTutorialSteps));
      expect(steps.length, 6);
      expect(steps.first.title, contains('Parent'));
    });

    test('returns student steps for null role', () {
      final steps = tutorialStepsForRole(null);
      expect(steps, same(homeTutorialSteps));
    });

    test('teacher steps mention dashboard', () {
      final dashboardSteps = teacherTutorialSteps
          .where((s) => s.description.toLowerCase().contains('dashboard'));
      expect(dashboardSteps.length, greaterThanOrEqualTo(2));
    });

    test('teacher steps mention reports', () {
      final reportSteps = teacherTutorialSteps.where((s) =>
          s.title.toLowerCase().contains('report') ||
          s.description.toLowerCase().contains('report'));
      expect(reportSteps, isNotEmpty);
    });

    test('parent steps mention child/family', () {
      final familySteps = parentTutorialSteps
          .where((s) =>
              s.description.toLowerCase().contains('child') ||
              s.description.toLowerCase().contains('family'));
      expect(familySteps, isNotEmpty);
    });

    test('all tutorial step lists have non-empty titles and descriptions', () {
      for (final stepList in [
        homeTutorialSteps,
        teacherTutorialSteps,
        parentTutorialSteps,
      ]) {
        for (final step in stepList) {
          expect(step.title, isNotEmpty);
          expect(step.description, isNotEmpty);
        }
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // UserRole Extension Tests
  // ═══════════════════════════════════════════════════════════

  group('UserRole extension', () {
    test('all roles have labels', () {
      expect(UserRole.student.label, 'Student');
      expect(UserRole.teacher.label, 'Teacher');
      expect(UserRole.parent.label, 'Parent');
    });

    test('all roles have emojis', () {
      expect(UserRole.student.emoji, '🎒');
      expect(UserRole.teacher.emoji, '📚');
      expect(UserRole.parent.emoji, '👨‍👩‍👧');
    });

    test('all roles have distinct icons', () {
      final icons = UserRole.values.map((r) => r.icon).toSet();
      expect(icons.length, UserRole.values.length);
    });
  });
}
