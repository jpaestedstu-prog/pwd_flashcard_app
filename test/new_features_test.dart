import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';

void main() {
  // Required for AppTheme (uses Google Fonts which needs the binding)
  TestWidgetsFlutterBinding.ensureInitialized();
  group('AppSettings — speechToText field', () {
    test('defaults to false', () {
      const settings = AppSettings();
      expect(settings.speechToText, false);
    });

    test('copyWith sets speechToText', () {
      const settings = AppSettings();
      final updated = settings.copyWith(speechToText: true);
      expect(updated.speechToText, true);
      // Other fields preserved
      expect(updated.fontScale, 1.0);
      expect(updated.ttsEnabled, true);
    });

    test('copyWith does not change speechToText when not specified', () {
      final settings = const AppSettings().copyWith(speechToText: true);
      final unchanged = settings.copyWith(fontScale: 2.0);
      expect(unchanged.speechToText, true);
      expect(unchanged.fontScale, 2.0);
    });
  });

  group('AppSettings — all fields roundtrip', () {
    test('copyWith preserves all non-specified fields', () {
      final original = const AppSettings().copyWith(
        fontScale: 1.5,
        highContrastMode: true,
        darkMode: true,
        ttsEnabled: false,
        ttsSpeed: 0.8,
        reducedMotion: true,
        soundEffects: false,
        speechToText: true,
        locale: 'fil',
        notificationsEnabled: false,
        reminderHour: 15,
        reminderMinute: 30,
      );

      // Copy with NO changes
      final copy = original.copyWith();
      expect(copy.fontScale, 1.5);
      expect(copy.highContrastMode, true);
      expect(copy.darkMode, true);
      expect(copy.ttsEnabled, false);
      expect(copy.ttsSpeed, 0.8);
      expect(copy.reducedMotion, true);
      expect(copy.soundEffects, false);
      expect(copy.speechToText, true);
      expect(copy.locale, 'fil');
      expect(copy.notificationsEnabled, false);
      expect(copy.reminderHour, 15);
      expect(copy.reminderMinute, 30);
    });
  });

  group('AppTheme — shop themes', () {
    test('shopTheme returns null for null id', () {
      expect(AppTheme.shopTheme(null), isNull);
    });

    test('shopTheme returns null for unknown id', () {
      expect(AppTheme.shopTheme('nonexistent'), isNull);
    });

    test('shopTheme returns ThemeData for known ids', () {
      for (final id in ['theme_ocean', 'theme_sunset', 'theme_forest', 'theme_galaxy']) {
        final theme = AppTheme.shopTheme(id);
        expect(theme, isNotNull, reason: '$id should return a theme');
        expect(theme!.scaffoldBackgroundColor, isNotNull);
      }
    });

    test('each shop theme has distinct primary color', () {
      final themes = ['theme_ocean', 'theme_sunset', 'theme_forest', 'theme_galaxy']
          .map((id) => AppTheme.shopTheme(id)!)
          .toList();
      final primaries = themes.map((t) => t.colorScheme.primary).toSet();
      expect(primaries.length, 4, reason: 'All 4 shop themes should have distinct primary colors');
    });
  });

  group('LearningProgress', () {
    test('copyWith preserves unchanged fields', () {
      final progress = LearningProgress(
        profileId: 'p1',
        wordsLearned: 5,
        totalStars: 20,
        spentStars: 5,
        lastActivityDate: DateTime.now(),
      );
      final updated = progress.copyWith(wordsLearned: 10);
      expect(updated.wordsLearned, 10);
      expect(updated.totalStars, 20);
      expect(updated.spentStars, 5);
      expect(updated.profileId, 'p1');
    });

    test('starBalance is totalStars minus spentStars', () {
      final progress = LearningProgress(
        profileId: 'p1',
        totalStars: 30,
        spentStars: 12,
        lastActivityDate: DateTime.now(),
      );
      expect(progress.starBalance, 18);
    });
  });

  group('GameScore', () {
    test('duration field roundtrips through JSON', () {
      final score = GameScore(
        gameType: GameType.spellingBee,
        score: 7,
        total: 10,
        starsEarned: 2,
        date: DateTime(2025, 6, 20),
        durationSeconds: 120,
      );
      final json = score.toJson();
      final restored = GameScore.fromJson(json);
      expect(restored.durationSeconds, 120);
    });

    test('all game types are valid in JSON roundtrip', () {
      for (final gt in GameType.values) {
        final score = GameScore(
          gameType: gt,
          score: 5,
          total: 10,
          starsEarned: 1,
          date: DateTime(2025),
        );
        final restored = GameScore.fromJson(score.toJson());
        expect(restored.gameType, gt);
      }
    });
  });
}
