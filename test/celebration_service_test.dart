import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/services/celebration_service.dart';

// ─── Mocks ──────────────────────────────────────────────

class MockSoundService extends Mock implements SoundService {}

class MockHapticService extends Mock implements HapticService {}

void main() {
  late MockSoundService mockSound;
  late MockHapticService mockHaptic;

  setUp(() {
    mockSound = MockSoundService();
    mockHaptic = MockHapticService();

    // Stub all sound methods to return completed futures
    when(() => mockSound.playCorrect()).thenAnswer((_) async {});
    when(() => mockSound.playWrong()).thenAnswer((_) async {});
    when(() => mockSound.playStar()).thenAnswer((_) async {});
    when(() => mockSound.playComplete()).thenAnswer((_) async {});
    when(() => mockSound.playTap()).thenAnswer((_) async {});
    when(() => mockSound.playFlip()).thenAnswer((_) async {});
    when(() => mockSound.playMatch()).thenAnswer((_) async {});
    when(() => mockSound.playLetter()).thenAnswer((_) async {});

    // Stub all haptic methods
    when(() => mockHaptic.success()).thenAnswer((_) async {});
    when(() => mockHaptic.celebration()).thenAnswer((_) async {});
    when(() => mockHaptic.gameComplete()).thenAnswer((_) async {});
    when(() => mockHaptic.error()).thenAnswer((_) async {});
    when(() => mockHaptic.lightTap()).thenAnswer((_) async {});
    when(() => mockHaptic.mediumTap()).thenAnswer((_) async {});
    when(() => mockHaptic.heavyTap()).thenAnswer((_) async {});
  });

  CelebrationService createService({bool reducedMotion = false}) {
    return CelebrationService(
      sound: mockSound,
      haptic: mockHaptic,
      reducedMotion: reducedMotion,
    );
  }

  // ─── celebrate() — sound + haptic orchestration ──────

  group('CelebrationService.celebrate()', () {
    test('correctAnswer triggers playCorrect + haptic success', () async {
      final service = createService();
      await service.celebrate(CelebrationType.correctAnswer);

      verify(() => mockSound.playCorrect()).called(1);
      verify(() => mockHaptic.success()).called(1);
    });

    test('starEarned triggers playStar + haptic celebration', () async {
      final service = createService();
      await service.celebrate(CelebrationType.starEarned);

      verify(() => mockSound.playStar()).called(1);
      verify(() => mockHaptic.celebration()).called(1);
    });

    test('gameComplete triggers playComplete + haptic gameComplete', () async {
      final service = createService();
      await service.celebrate(CelebrationType.gameComplete);

      verify(() => mockSound.playComplete()).called(1);
      verify(() => mockHaptic.gameComplete()).called(1);
    });

    test('perfectScore triggers playComplete + haptic gameComplete', () async {
      final service = createService();
      await service.celebrate(CelebrationType.perfectScore);

      verify(() => mockSound.playComplete()).called(1);
      verify(() => mockHaptic.gameComplete()).called(1);
    });

    test('achievementUnlocked triggers playStar + haptic celebration',
        () async {
      final service = createService();
      await service.celebrate(CelebrationType.achievementUnlocked);

      verify(() => mockSound.playStar()).called(1);
      verify(() => mockHaptic.celebration()).called(1);
    });

    test('streakMilestone triggers playStar + haptic celebration', () async {
      final service = createService();
      await service.celebrate(CelebrationType.streakMilestone);

      verify(() => mockSound.playStar()).called(1);
      verify(() => mockHaptic.celebration()).called(1);
    });

    test('levelUp triggers playComplete + haptic gameComplete', () async {
      final service = createService();
      await service.celebrate(CelebrationType.levelUp);

      verify(() => mockSound.playComplete()).called(1);
      verify(() => mockHaptic.gameComplete()).called(1);
    });

    test('purchase triggers playStar + haptic celebration', () async {
      final service = createService();
      await service.celebrate(CelebrationType.purchase);

      verify(() => mockSound.playStar()).called(1);
      verify(() => mockHaptic.celebration()).called(1);
    });

    test('errors in sound do not propagate', () async {
      when(() => mockSound.playCorrect())
          .thenThrow(Exception('audio failure'));

      final service = createService();
      // Should not throw
      await service.celebrate(CelebrationType.correctAnswer);
    });

    test('errors in haptic do not propagate', () async {
      when(() => mockHaptic.success())
          .thenThrow(Exception('haptic failure'));

      final service = createService();
      // Should not throw
      await service.celebrate(CelebrationType.correctAnswer);
    });
  });

  // ─── lottieAssetFor() ─────────────────────────────────

  group('CelebrationService.lottieAssetFor()', () {
    test('correctAnswer returns thumbs_up asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.correctAnswer),
        'assets/animations/thumbs_up.json',
      );
    });

    test('starEarned returns celebration_stars asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.starEarned),
        'assets/animations/celebration_stars.json',
      );
    });

    test('gameComplete returns trophy asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.gameComplete),
        'assets/animations/trophy.json',
      );
    });

    test('perfectScore returns celebration_fireworks asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.perfectScore),
        'assets/animations/celebration_fireworks.json',
      );
    });

    test('achievementUnlocked returns trophy asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.achievementUnlocked),
        'assets/animations/trophy.json',
      );
    });

    test('streakMilestone returns streak_flame asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.streakMilestone),
        'assets/animations/streak_flame.json',
      );
    });

    test('levelUp returns level_up asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.levelUp),
        'assets/animations/level_up.json',
      );
    });

    test('purchase returns celebration_fireworks asset', () {
      final service = createService();
      expect(
        service.lottieAssetFor(CelebrationType.purchase),
        'assets/animations/celebration_fireworks.json',
      );
    });

    test('all types return a non-null asset when motion is not reduced', () {
      final service = createService();
      for (final type in CelebrationType.values) {
        expect(service.lottieAssetFor(type), isNotNull,
            reason: '$type should have an asset');
        expect(service.lottieAssetFor(type), endsWith('.json'),
            reason: '$type asset should be a JSON file');
      }
    });
  });

  // ─── reducedMotion ────────────────────────────────────

  group('CelebrationService — reducedMotion', () {
    test('isReducedMotion reflects constructor parameter', () {
      expect(createService().isReducedMotion, false);
      expect(createService(reducedMotion: true).isReducedMotion, true);
    });

    test('lottieAssetFor returns null when reducedMotion is true', () {
      final service = createService(reducedMotion: true);
      for (final type in CelebrationType.values) {
        expect(service.lottieAssetFor(type), isNull,
            reason: '$type should return null with reducedMotion');
      }
    });

    test('celebrate() still plays sound and haptic when reducedMotion is true',
        () async {
      final service = createService(reducedMotion: true);
      await service.celebrate(CelebrationType.gameComplete);

      // Sound and haptic should still fire — only visuals are suppressed
      verify(() => mockSound.playComplete()).called(1);
      verify(() => mockHaptic.gameComplete()).called(1);
    });
  });
}
