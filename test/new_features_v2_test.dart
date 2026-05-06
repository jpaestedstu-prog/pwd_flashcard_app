import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/core/accessibility/voice_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Voice Navigation Route Descriptions ────────────────

  group('VoiceNavigationService — new route descriptions', () {
    test('describes /weekly-reports route', () {
      final info = VoiceNavigationService.describeRoute('/weekly-reports');
      expect(info.name, 'Weekly Reports');
      expect(info.description, contains('weekly'));
    });

    test('describes /adaptive-analytics route', () {
      final info = VoiceNavigationService.describeRoute('/adaptive-analytics');
      expect(info.name, 'Adaptive Analytics');
      expect(info.description, contains('chart'));
    });

    test('describes /multiplayer-quiz route', () {
      final info = VoiceNavigationService.describeRoute('/multiplayer-quiz');
      expect(info.name, 'Multiplayer Quiz');
      expect(info.description, contains('two-player'));
    });

    test('describes /voice-guided route', () {
      final info = VoiceNavigationService.describeRoute('/voice-guided');
      expect(info.name, 'Voice-Guided Mode');
      expect(info.description, contains('voice navigation'));
    });

    test('describes /create-flashcard-enhanced route', () {
      final info =
          VoiceNavigationService.describeRoute('/create-flashcard-enhanced');
      expect(info.name, 'Enhanced Flashcard Creator');
      expect(info.description, contains('image'));
    });

    test('strips query parameters from route', () {
      final info = VoiceNavigationService.describeRoute(
          '/multiplayer-quiz?difficulty=medium');
      expect(info.name, 'Multiplayer Quiz');
    });

    test('unknown route returns generic description', () {
      final info = VoiceNavigationService.describeRoute('/nonexistent-route');
      expect(info.name, 'Page');
    });

    test('existing routes still work (home)', () {
      final info = VoiceNavigationService.describeRoute('/home');
      expect(info.name, 'Home');
      expect(info.description, contains('Home screen'));
    });

    test('existing routes still work (games)', () {
      final info = VoiceNavigationService.describeRoute('/games');
      expect(info.name, 'Games');
    });

    test('Filipino locale routes still work', () {
      final info =
          VoiceNavigationService.describeRoute('/home', locale: 'fil');
      expect(info.name, 'Home');
      expect(info.description, contains('kategorya'));
    });
  });

  // ─── Flashcard with Image ───────────────────────────────

  group('Flashcard — enhanced creator model support', () {
    test('Flashcard supports imageAsset field', () {
      const card = Flashcard(
        id: 'custom-01',
        wordEnglish: 'Sun',
        wordFilipino: 'Araw',
        imageAsset: '/path/to/photo.jpg',
        category: FlashcardCategory.weather,
        isCustom: true,
      );
      expect(card.imageAsset, '/path/to/photo.jpg');
      expect(card.isCustom, true);
    });

    test('copyWith can update imageAsset', () {
      const card = Flashcard(
        id: 'custom-02',
        wordEnglish: 'Tree',
        wordFilipino: 'Puno',
        category: FlashcardCategory.weather,
        isCustom: true,
      );
      final updated = card.copyWith(imageAsset: '/new/image.png');
      expect(updated.imageAsset, '/new/image.png');
      expect(updated.wordEnglish, 'Tree');
    });

    test('toJson preserves imageAsset', () {
      const card = Flashcard(
        id: 'custom-03',
        wordEnglish: 'Moon',
        wordFilipino: 'Buwan',
        imageAsset: 'assets/images/moon.png',
        category: FlashcardCategory.weather,
        isCustom: true,
      );
      final json = card.toJson();
      expect(json['imageAsset'], 'assets/images/moon.png');
      expect(json['isCustom'], true);
    });

    test('fromJson restores imageAsset', () {
      final json = {
        'id': 'custom-04',
        'wordEnglish': 'Star',
        'wordFilipino': 'Bituin',
        'imageAsset': 'photos/star.jpg',
        'category': FlashcardCategory.weather.index,
        'isCustom': true,
      };
      final card = Flashcard.fromJson(json);
      expect(card.imageAsset, 'photos/star.jpg');
      expect(card.isCustom, true);
    });

    test('null imageAsset roundtrips correctly', () {
      const card = Flashcard(
        id: 'custom-05',
        wordEnglish: 'Cloud',
        wordFilipino: 'Ulap',
        category: FlashcardCategory.weather,
        isCustom: true,
      );
      final json = card.toJson();
      final restored = Flashcard.fromJson(json);
      expect(restored.imageAsset, isNull);
    });
  });

  // ─── AppSettings — voice navigation fields ─────────────

  group('AppSettings — voice navigation & adaptive difficulty', () {
    test('voiceNavigation defaults to false', () {
      const settings = AppSettings();
      expect(settings.voiceNavigation, false);
    });

    test('adaptiveDifficulty defaults to true', () {
      const settings = AppSettings();
      expect(settings.adaptiveDifficulty, true);
    });

    test('copyWith sets voiceNavigation', () {
      const settings = AppSettings();
      final updated = settings.copyWith(voiceNavigation: true);
      expect(updated.voiceNavigation, true);
      expect(updated.adaptiveDifficulty, true); // unchanged
    });

    test('ttsSpeed defaults to 0.5', () {
      const settings = AppSettings();
      expect(settings.ttsSpeed, 0.5);
    });

    test('copyWith changes ttsSpeed', () {
      const settings = AppSettings();
      final updated = settings.copyWith(ttsSpeed: 0.8);
      expect(updated.ttsSpeed, 0.8);
    });

    test('locale defaults to en', () {
      const settings = AppSettings();
      expect(settings.locale, 'en');
    });

    test('copyWith changes locale to fil', () {
      const settings = AppSettings();
      final updated = settings.copyWith(locale: 'fil');
      expect(updated.locale, 'fil');
    });
  });

  // ─── GameScore — multiplayer scoring model ──────────────

  group('GameScore — serialization for multiplayer results', () {
    test('toJson roundtrip preserves all fields', () {
      final score = GameScore(
        gameType: GameType.wordMatch,
        score: 8,
        total: 10,
        starsEarned: 3,
        date: DateTime(2025, 6, 15),
        durationSeconds: 45,
      );
      final json = score.toJson();
      final restored = GameScore.fromJson(json);
      expect(restored.score, 8);
      expect(restored.total, 10);
      expect(restored.starsEarned, 3);
      expect(restored.durationSeconds, 45);
      expect(restored.gameType, GameType.wordMatch);
    });

    test('GameScore with null duration serializes correctly', () {
      final score = GameScore(
        gameType: GameType.spellingBee,
        score: 5,
        total: 7,
        starsEarned: 2,
        date: DateTime(2025, 6, 15),
      );
      final json = score.toJson();
      expect(json['durationSeconds'], isNull);
      final restored = GameScore.fromJson(json);
      expect(restored.durationSeconds, isNull);
    });
  });

  // ─── LearningProgress — weekly report data ─────────────

  group('LearningProgress — report data model', () {
    test('starBalance computes correctly', () {
      final progress = LearningProgress(
        profileId: 'child-1',
        totalStars: 100,
        spentStars: 30,
        lastActivityDate: DateTime.now(),
      );
      expect(progress.starBalance, 70);
    });

    test('categoryProgress holds category data', () {
      final progress = LearningProgress(
        profileId: 'child-2',
        categoryProgress: {
          'animals': 0.85,
          'colors': 0.60,
          'numbers': 0.20,
        },
        lastActivityDate: DateTime.now(),
      );
      expect(progress.categoryProgress['animals'], 0.85);
      expect(progress.categoryProgress.length, 3);
    });

    test('copyWith updates recentScores', () {
      final progress = LearningProgress(
        profileId: 'child-3',
        lastActivityDate: DateTime.now(),
      );
      final newScores = [
        GameScore(
          gameType: GameType.memoryMatch,
          score: 10,
          total: 10,
          starsEarned: 5,
          date: DateTime.now(),
        ),
      ];
      final updated = progress.copyWith(recentScores: newScores);
      expect(updated.recentScores.length, 1);
      expect(updated.recentScores.first.score, 10);
    });
  });

  // ─── FlashcardCategory — enum completeness ─────────────

  group('FlashcardCategory — all categories have labels', () {
    test('every category has a non-empty label', () {
      for (final cat in FlashcardCategory.values) {
        expect(cat.label, isNotEmpty, reason: '${cat.name} has no label');
      }
    });

    test('every category has a non-empty labelFilipino', () {
      for (final cat in FlashcardCategory.values) {
        expect(cat.labelFilipino, isNotEmpty,
            reason: '${cat.name} has no Filipino label');
      }
    });

    test('every category has an icon', () {
      for (final cat in FlashcardCategory.values) {
        expect(cat.icon, isNotNull, reason: '${cat.name} has no icon');
      }
    });
  });

  // ─── GameType — all types have labels ──────────────────

  group('GameType — all game types have labels', () {
    test('every GameType has a non-empty label', () {
      for (final gt in GameType.values) {
        expect(gt.label, isNotEmpty, reason: '${gt.name} has no label');
      }
    });
  });
}
