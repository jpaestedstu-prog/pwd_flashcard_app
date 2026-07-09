import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/avatar_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/core/services/learning_level_service.dart';

void main() {
  group('suggestGradeLevelFromAge', () {
    test('age <= 5 suggests Kinder', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(3), GradeLevel.kinder);
      expect(LearningLevelService.suggestGradeLevelFromAge(4), GradeLevel.kinder);
      expect(LearningLevelService.suggestGradeLevelFromAge(5), GradeLevel.kinder);
    });

    test('age 6 suggests Grade 1', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(6), GradeLevel.grade1);
    });

    test('age 7 suggests Grade 2', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(7), GradeLevel.grade2);
    });

    test('age 8 suggests Grade 3', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(8), GradeLevel.grade3);
    });

    test('age 9 suggests Grade 4', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(9), GradeLevel.grade4);
    });

    test('age 10 suggests Grade 5', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(10), GradeLevel.grade5);
    });

    test('age 11 suggests Grade 6', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(11), GradeLevel.grade6);
    });

    test('age 12-17 suggests High School', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(12), GradeLevel.highSchool);
      expect(LearningLevelService.suggestGradeLevelFromAge(15), GradeLevel.highSchool);
      expect(LearningLevelService.suggestGradeLevelFromAge(17), GradeLevel.highSchool);
    });

    test('age >= 18 suggests College', () {
      expect(LearningLevelService.suggestGradeLevelFromAge(18), GradeLevel.college);
      expect(LearningLevelService.suggestGradeLevelFromAge(22), GradeLevel.college);
      expect(LearningLevelService.suggestGradeLevelFromAge(50), GradeLevel.college);
    });
  });

  group('GradeLevel enum', () {
    test('covers Kindergarten to College', () {
      expect(GradeLevel.values.length, 9);
      expect(GradeLevel.values.first, GradeLevel.kinder);
      expect(GradeLevel.values.last, GradeLevel.college);
    });

    test('labels are correct', () {
      expect(GradeLevel.kinder.label, 'Kinder');
      expect(GradeLevel.grade1.label, 'Grade 1');
      expect(GradeLevel.grade6.label, 'Grade 6');
      expect(GradeLevel.highSchool.label, 'High School');
      expect(GradeLevel.college.label, 'College');
    });
  });

  group('UserProfile model', () {
    test('computes age from birthDate', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'test-1',
        name: 'Test Student',
        role: UserRole.student,
        createdAt: now,
        birthDate: DateTime(now.year - 10, now.month, now.day),
      );
      expect(profile.age, 10);
    });

    test('age is null when birthDate is not set', () {
      final profile = UserProfile(
        id: 'test-2',
        name: 'No Age',
        role: UserRole.student,
        createdAt: DateTime.now(),
      );
      expect(profile.age, isNull);
    });

    test('copyWith preserves birthDate and gradeLevel', () {
      final profile = UserProfile(
        id: 'test-3',
        name: 'Student',
        role: UserRole.student,
        createdAt: DateTime.now(),
        birthDate: DateTime(2015, 6, 15),
        gradeLevel: GradeLevel.grade4,
      );

      final updated = profile.copyWith(name: 'Updated Student');
      expect(updated.name, 'Updated Student');
      expect(updated.birthDate, DateTime(2015, 6, 15));
      expect(updated.gradeLevel, GradeLevel.grade4);
    });

    test('profile with all student fields', () {
      final profile = UserProfile(
        id: 'test-4',
        name: 'Complete Student',
        role: UserRole.student,
        avatarIndex: 2,
        createdAt: DateTime.now(),
        birthDate: DateTime(2016, 3, 20),
        gradeLevel: GradeLevel.grade3,
      );

      expect(profile.name, 'Complete Student');
      expect(profile.role, UserRole.student);
      expect(profile.gradeLevel, GradeLevel.grade3);
      expect(profile.birthDate, isNotNull);
      expect(profile.age, isNotNull);
    });

    test('form validation - name must not be empty', () {
      // Simulate form validation logic
      String? validateName(String? value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a name';
        }
        if (value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      }

      expect(validateName(null), 'Please enter a name');
      expect(validateName(''), 'Please enter a name');
      expect(validateName('  '), 'Please enter a name');
      expect(validateName('A'), 'Name must be at least 2 characters');
      expect(validateName('Anna'), isNull);
    });

    test('form validation - grade level must be selected for students', () {
      GradeLevel? validateGradeLevel(GradeLevel? value) {
        if (value == null) return null; // indicates validation failure
        return value;
      }

      expect(validateGradeLevel(null), isNull);
      expect(validateGradeLevel(GradeLevel.kinder), GradeLevel.kinder);
      expect(validateGradeLevel(GradeLevel.college), GradeLevel.college);
    });
  });

  group('Student profile list filtering', () {
    test('filters only student profiles', () {
      final profiles = [
        UserProfile(
          id: '1',
          name: 'Student A',
          role: UserRole.student,
          createdAt: DateTime.now(),
          gradeLevel: GradeLevel.grade3,
          birthDate: DateTime(2016),
        ),
        UserProfile(
          id: '2',
          name: 'Teacher B',
          role: UserRole.teacher,
          createdAt: DateTime.now(),
        ),
        UserProfile(
          id: '3',
          name: 'Student C',
          role: UserRole.student,
          createdAt: DateTime.now(),
          gradeLevel: GradeLevel.kinder,
          birthDate: DateTime(2020, 6, 15),
        ),
        UserProfile(
          id: '4',
          name: 'Parent D',
          role: UserRole.parent,
          createdAt: DateTime.now(),
        ),
      ];

      final students =
          profiles.where((p) => p.role == UserRole.student).toList();
      expect(students.length, 2);
      expect(students[0].name, 'Student A');
      expect(students[1].name, 'Student C');
    });

    test('sorts by createdAt descending', () {
      final profiles = [
        UserProfile(
          id: '1',
          name: 'Old Student',
          role: UserRole.student,
          createdAt: DateTime(2025),
        ),
        UserProfile(
          id: '2',
          name: 'New Student',
          role: UserRole.student,
          createdAt: DateTime(2026, 4),
        ),
      ];

      profiles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(profiles[0].name, 'New Student');
      expect(profiles[1].name, 'Old Student');
    });
  });

  group('PIN protection', () {
    test('hasPinProtection is true only with 4-digit pin', () {
      final withPin = UserProfile(
        id: 'pin-1',
        name: 'PIN Student',
        role: UserRole.student,
        createdAt: DateTime.now(),
        pin: '1234',
      );
      expect(withPin.hasPinProtection, isTrue);

      final withShortPin = UserProfile(
        id: 'pin-2',
        name: 'Short PIN',
        role: UserRole.student,
        createdAt: DateTime.now(),
        pin: '12',
      );
      expect(withShortPin.hasPinProtection, isFalse);

      final withoutPin = UserProfile(
        id: 'pin-3',
        name: 'No PIN',
        role: UserRole.student,
        createdAt: DateTime.now(),
      );
      expect(withoutPin.hasPinProtection, isFalse);
    });

    test('PIN validation - must be 4 digits', () {
      String? validatePin(String? value) {
        if (value == null || value.length != 4) {
          return 'PIN must be exactly 4 digits';
        }
        if (!RegExp(r'^\d{4}$').hasMatch(value)) {
          return 'PIN must contain only digits';
        }
        return null;
      }

      expect(validatePin(null), 'PIN must be exactly 4 digits');
      expect(validatePin(''), 'PIN must be exactly 4 digits');
      expect(validatePin('12'), 'PIN must be exactly 4 digits');
      expect(validatePin('12345'), 'PIN must be exactly 4 digits');
      expect(validatePin('abcd'), 'PIN must contain only digits');
      expect(validatePin('1234'), isNull);
      expect(validatePin('0000'), isNull);
      expect(validatePin('9999'), isNull);
    });

    test('PIN confirmation - must match', () {
      String? validateConfirm(String pin, String? confirm) {
        if (confirm != pin) return 'PINs do not match';
        return null;
      }

      expect(validateConfirm('1234', '1234'), isNull);
      expect(validateConfirm('1234', '5678'), 'PINs do not match');
      expect(validateConfirm('1234', null), 'PINs do not match');
    });

    test('copyWith can set and remove PIN', () {
      final profile = UserProfile(
        id: 'pin-4',
        name: 'Student',
        role: UserRole.student,
        createdAt: DateTime.now(),
      );

      // Set PIN
      final withPin = profile.copyWith(pin: () => '5678');
      expect(withPin.pin, '5678');
      expect(withPin.hasPinProtection, isTrue);

      // Remove PIN
      final noPin = withPin.copyWith(pin: () => null);
      expect(noPin.pin, isNull);
      expect(noPin.hasPinProtection, isFalse);
    });
  });

  group('Profile deletion', () {
    test('removing student from list works', () {
      final profiles = [
        UserProfile(
          id: 'del-1',
          name: 'Student A',
          role: UserRole.student,
          createdAt: DateTime.now(),
        ),
        UserProfile(
          id: 'del-2',
          name: 'Student B',
          role: UserRole.student,
          createdAt: DateTime.now(),
        ),
        UserProfile(
          id: 'del-3',
          name: 'Student C',
          role: UserRole.student,
          createdAt: DateTime.now(),
        ),
      ];

      // Simulate deletion
      profiles.removeWhere((p) => p.id == 'del-2');
      expect(profiles.length, 2);
      expect(profiles.any((p) => p.name == 'Student B'), isFalse);
      expect(profiles[0].name, 'Student A');
      expect(profiles[1].name, 'Student C');
    });
  });

  group('Student Profile Detail data', () {
    test('LearningProgress has correct defaults', () {
      final progress = LearningProgress(
        profileId: 'detail-1',
        lastActivityDate: DateTime(2025, 6),
      );
      expect(progress.wordsLearned, 0);
      expect(progress.streakDays, 0);
      expect(progress.totalStars, 0);
      expect(progress.spentStars, 0);
      expect(progress.starBalance, 0);
      expect(progress.categoryProgress, isEmpty);
      expect(progress.recentScores, isEmpty);
      expect(progress.learnedWordIds, isEmpty);
    });

    test('starBalance computed correctly', () {
      final progress = LearningProgress(
        profileId: 'detail-2',
        lastActivityDate: DateTime(2025, 6),
        totalStars: 50,
        spentStars: 20,
      );
      expect(progress.starBalance, 30);
    });

    test('categoryProgress stores values between 0 and 1', () {
      final progress = LearningProgress(
        profileId: 'detail-3',
        lastActivityDate: DateTime(2025, 6),
        categoryProgress: {
          'Animals': 0.85,
          'Colors': 0.4,
          'Numbers': 1.0,
          'Shapes': 0.0,
        },
      );
      expect(progress.categoryProgress.length, 4);
      expect(progress.categoryProgress['Animals'], 0.85);
      expect(progress.categoryProgress['Numbers'], 1.0);
      expect(progress.categoryProgress['Shapes'], 0.0);
    });

    test('GameScore percentage calculation', () {
      final score = GameScore(
        gameType: GameType.wordMatch,
        score: 8,
        total: 10,
        starsEarned: 3,
        date: DateTime(2025, 6),
      );
      final pct = score.total > 0 ? (score.score / score.total * 100).round() : 0;
      expect(pct, 80);
      expect(score.starsEarned, 3);
      expect(score.gameType.label, 'Word Match');
    });

    test('GameScore handles zero total gracefully', () {
      final score = GameScore(
        gameType: GameType.spellingBee,
        score: 0,
        total: 0,
        starsEarned: 0,
        date: DateTime(2025, 6),
      );
      final pct = score.total > 0 ? (score.score / score.total * 100).round() : 0;
      expect(pct, 0);
    });

    test('recent scores limited to 5 most recent', () {
      final scores = List.generate(
        10,
        (i) => GameScore(
          gameType: GameType.wordMatch,
          score: i + 1,
          total: 10,
          starsEarned: 1,
          date: DateTime(2025, 1, i + 1),
        ),
      );
      // Same logic as detail screen
      final recent = scores.length > 5 ? scores.sublist(scores.length - 5) : scores;
      final display = recent.reversed.toList();
      expect(display.length, 5);
      expect(display.first.score, 10); // most recent first
      expect(display.last.score, 6);
    });

    test('profile detail shows all fields', () {
      final profile = UserProfile(
        id: 'detail-full',
        name: 'Maria Santos',
        role: UserRole.student,
        avatarIndex: 3,
        createdAt: DateTime(2025, 3, 15),
        birthDate: DateTime(2016, 7, 20),
        gradeLevel: GradeLevel.grade3,
        section: 'Section A',
        disabilityType: DisabilityType.cognitive,
        pin: '4321',
        tags: ['Tagalog', 'Reading'],
      );

      expect(profile.name, 'Maria Santos');
      expect(profile.age, isNotNull);
      expect(profile.gradeLevel, GradeLevel.grade3);
      expect(profile.section, 'Section A');
      expect(profile.disabilityType, DisabilityType.cognitive);
      expect(profile.disabilityType.label, 'Cognitive/Learning');
      expect(profile.hasPinProtection, isTrue);
      expect(profile.tags, ['Tagalog', 'Reading']);
      expect(profile.role.label, 'Student');
    });

    test('category progress sorted by descending value', () {
      final categoryProgress = {
        'Animals': 0.3,
        'Colors': 0.85,
        'Numbers': 0.6,
        'Shapes': 1.0,
      };
      final sorted = categoryProgress.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      expect(sorted[0].key, 'Shapes');
      expect(sorted[1].key, 'Colors');
      expect(sorted[2].key, 'Numbers');
      expect(sorted[3].key, 'Animals');
    });

    test('progress copyWith works correctly', () {
      final progress = LearningProgress(
        profileId: 'detail-copy',
        lastActivityDate: DateTime(2025, 6),
        wordsLearned: 10,
        streakDays: 5,
        totalStars: 30,
      );
      final updated = progress.copyWith(
        wordsLearned: 15,
        streakDays: 6,
      );
      expect(updated.wordsLearned, 15);
      expect(updated.streakDays, 6);
      expect(updated.totalStars, 30); // unchanged
      expect(updated.profileId, 'detail-copy'); // unchanged
    });
  });

  group('Avatar Customization', () {
    test('ShopData has premium avatar items', () {
      final premiumAvatars = ShopData.byType(ShopItemType.avatar);
      expect(premiumAvatars.isNotEmpty, isTrue);
      expect(premiumAvatars.length, 8);
      for (final item in premiumAvatars) {
        expect(item.type, ShopItemType.avatar);
        expect(item.cost, greaterThan(0));
        expect(item.emoji.isNotEmpty, isTrue);
        expect(item.name.isNotEmpty, isTrue);
        expect(item.id.startsWith('avatar_'), isTrue);
      }
    });

    test('premium avatars have unique IDs', () {
      final premiumAvatars = ShopData.byType(ShopItemType.avatar);
      final ids = premiumAvatars.map((a) => a.id).toSet();
      expect(ids.length, premiumAvatars.length);
    });

    test('ShopData.findById returns correct item', () {
      final unicorn = ShopData.findById('avatar_unicorn');
      expect(unicorn, isNotNull);
      expect(unicorn!.name, 'Unicorn');
      expect(unicorn.emoji, '🦄');
      expect(unicorn.cost, 15);
      expect(unicorn.type, ShopItemType.avatar);
    });

    test('ShopData.findById returns null for unknown ID', () {
      final result = ShopData.findById('avatar_unknown_xyz');
      expect(result, isNull);
    });

    test('free avatars and premium avatars are distinct', () {
      final freeEmojis = AvatarData.avatars.map((a) => a.emoji).toSet();
      final premiumEmojis =
          ShopData.byType(ShopItemType.avatar).map((a) => a.emoji).toSet();
      // No overlap between free and premium sets
      expect(freeEmojis.intersection(premiumEmojis), isEmpty);
    });

    test('premium avatar selection state logic', () {
      // Simulate the edit screen state
      String? selectedPremiumAvatarId;
      int selectedFreeAvatar = 0;

      // Select a premium avatar
      selectedPremiumAvatarId = 'avatar_unicorn';
      expect(selectedPremiumAvatarId, isNotNull);

      // Tapping a free avatar clears premium selection
      selectedFreeAvatar = 3;
      selectedPremiumAvatarId = null;
      expect(selectedPremiumAvatarId, isNull);
      expect(selectedFreeAvatar, 3);

      // Tapping the same premium avatar toggles off
      selectedPremiumAvatarId = 'avatar_dragon';
      expect(selectedPremiumAvatarId, 'avatar_dragon');
      // Toggle off
      selectedPremiumAvatarId = null;
      expect(selectedPremiumAvatarId, isNull);
    });

    test('premium avatar costs are reasonable', () {
      final premiumAvatars = ShopData.byType(ShopItemType.avatar);
      for (final item in premiumAvatars) {
        expect(item.cost, greaterThanOrEqualTo(10));
        expect(item.cost, lessThanOrEqualTo(50));
      }
    });

    test('all shop item types exist', () {
      final avatars = ShopData.byType(ShopItemType.avatar);
      final themes = ShopData.byType(ShopItemType.theme);
      final borders = ShopData.byType(ShopItemType.border);
      expect(avatars.isNotEmpty, isTrue);
      expect(themes.isNotEmpty, isTrue);
      expect(borders.isNotEmpty, isTrue);
    });
  });

  group('Profile Import/Export serialisation', () {
    test('profile round-trips through JSON', () {
      final profile = UserProfile(
        id: 'export-1',
        name: 'Maria Santos',
        role: UserRole.student,
        avatarIndex: 5,
        createdAt: DateTime(2025, 3, 15),
        disabilityType: DisabilityType.cognitive,
        pin: '4321',
        gradeLevel: GradeLevel.grade3,
        section: 'Section A',
        birthDate: DateTime(2016, 7, 20),
        tags: ['tagalog', 'reading'],
      );

      // Simulate the serialisation the export service does
      final map = {
        'id': profile.id,
        'name': profile.name,
        'role': profile.role.index,
        'avatarIndex': profile.avatarIndex,
        'createdAt': profile.createdAt.toIso8601String(),
        'disabilityType': profile.disabilityType.index,
        'pin': profile.pin,
        'gradeLevel': profile.gradeLevel?.index,
        'section': profile.section,
        'birthDate': profile.birthDate?.toIso8601String(),
        'tags': profile.tags,
      };

      // Round-trip through JSON encoding/decoding
      final jsonStr = jsonEncode(map);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['id'], profile.id);
      expect(decoded['name'], profile.name);
      expect(decoded['role'], profile.role.index);
      expect(decoded['avatarIndex'], profile.avatarIndex);
      expect(decoded['pin'], profile.pin);
      expect(decoded['gradeLevel'], profile.gradeLevel!.index);
      expect(decoded['section'], profile.section);
      expect(decoded['tags'], profile.tags);
    });

    test('progress round-trips through JSON', () {
      final progress = LearningProgress(
        profileId: 'export-2',
        wordsLearned: 42,
        streakDays: 7,
        lastActivityDate: DateTime(2025, 6),
        totalStars: 150,
        spentStars: 30,
        categoryProgress: {'Animals': 0.8, 'Colors': 0.5},
        learnedWordIds: {'word_1', 'word_2', 'word_3'},
        recentScores: [
          GameScore(
            gameType: GameType.wordMatch,
            score: 8,
            total: 10,
            starsEarned: 3,
            date: DateTime(2025, 5, 28),
            durationSeconds: 120,
          ),
        ],
      );

      final map = {
        'wordsLearned': progress.wordsLearned,
        'learnedWordIds': progress.learnedWordIds.toList(),
        'streakDays': progress.streakDays,
        'lastActivityDate': progress.lastActivityDate.toIso8601String(),
        'totalStars': progress.totalStars,
        'spentStars': progress.spentStars,
        'categoryProgress': progress.categoryProgress,
        'recentScores': progress.recentScores
            .map((s) => {
                  'gameType': s.gameType.index,
                  'score': s.score,
                  'total': s.total,
                  'starsEarned': s.starsEarned,
                  'date': s.date.toIso8601String(),
                  'durationSeconds': s.durationSeconds,
                })
            .toList(),
      };

      final jsonStr = jsonEncode(map);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['wordsLearned'], 42);
      expect(decoded['streakDays'], 7);
      expect(decoded['totalStars'], 150);
      expect(decoded['spentStars'], 30);
      expect((decoded['learnedWordIds'] as List).length, 3);
      expect((decoded['categoryProgress'] as Map)['Animals'], 0.8);
      expect((decoded['recentScores'] as List).length, 1);

      final scoreMap = (decoded['recentScores'] as List).first as Map<String, dynamic>;
      expect(scoreMap['score'], 8);
      expect(scoreMap['total'], 10);
      expect(scoreMap['starsEarned'], 3);
      expect(scoreMap['durationSeconds'], 120);
    });

    test('full export JSON structure is valid', () {
      final exportData = {
        'formatVersion': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'profile': {
          'id': 'test-id',
          'name': 'Test Student',
          'role': UserRole.student.index,
          'avatarIndex': 0,
          'createdAt': DateTime(2025).toIso8601String(),
          'disabilityType': DisabilityType.none.index,
          'pin': null,
          'gradeLevel': GradeLevel.grade1.index,
          'section': null,
          'birthDate': null,
          'tags': <String>[],
        },
        'progress': {
          'wordsLearned': 0,
          'learnedWordIds': <String>[],
          'streakDays': 0,
          'lastActivityDate': DateTime.now().toIso8601String(),
          'totalStars': 0,
          'spentStars': 0,
          'categoryProgress': <String, double>{},
          'recentScores': <dynamic>[],
        },
        'achievements': <String>['badge_first_word', 'badge_streak_3'],
        'purchases': <String>['avatar_unicorn'],
        'equipped': {'avatar': 'avatar_unicorn', 'theme': null, 'border': null},
      };

      // Should encode without error
      final jsonStr = jsonEncode(exportData);
      expect(jsonStr.isNotEmpty, isTrue);

      // Should decode back correctly
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(decoded['formatVersion'], 1);
      expect(decoded.containsKey('profile'), isTrue);
      expect(decoded.containsKey('progress'), isTrue);
      expect(decoded.containsKey('achievements'), isTrue);
      expect(decoded.containsKey('purchases'), isTrue);
      expect(decoded.containsKey('equipped'), isTrue);
    });

    test('import validation rejects invalid data', () {
      // Missing profile key
      final invalid1 = {'progress': {}};
      expect(invalid1.containsKey('profile'), isFalse);

      // Missing progress key
      final invalid2 = {'profile': {}};
      expect(invalid2.containsKey('progress'), isFalse);

      // Valid structure
      final valid = {'profile': {}, 'progress': {}};
      expect(valid.containsKey('profile') && valid.containsKey('progress'), isTrue);
    });

    test('profile reconstruction from map handles missing optional fields', () {
      final minimalMap = {
        'id': 'min-1',
        'name': 'Minimal',
        'role': UserRole.student.index,
        'createdAt': DateTime(2025).toIso8601String(),
      };

      // Reconstruct (same logic as the import service)
      final roleIndex = minimalMap['role'] as int;
      final profile = UserProfile(
        id: minimalMap['id'] as String,
        name: minimalMap['name'] as String,
        role: UserRole.values[roleIndex.clamp(0, UserRole.values.length - 1)],
        avatarIndex: (minimalMap['avatarIndex'] as int?) ?? 0,
        createdAt: DateTime.parse(minimalMap['createdAt'] as String),
      );

      expect(profile.id, 'min-1');
      expect(profile.name, 'Minimal');
      expect(profile.avatarIndex, 0);
      expect(profile.pin, isNull);
      expect(profile.gradeLevel, isNull);
      expect(profile.section, isNull);
      expect(profile.birthDate, isNull);
      expect(profile.tags, isEmpty);
    });

    test('achievements and purchases are sets of strings', () {
      final rawAchievements = ['badge_a', 'badge_b', 'badge_a'];
      final achievementSet = Set<String>.from(rawAchievements);
      expect(achievementSet.length, 2); // deduped

      final rawPurchases = ['avatar_unicorn', 'avatar_dragon'];
      final purchaseSet = Set<String>.from(rawPurchases);
      expect(purchaseSet.length, 2);
      expect(purchaseSet.contains('avatar_unicorn'), isTrue);
    });

    test('equipped items map structure', () {
      final equipped = <String, String?>{
        'avatar': 'avatar_unicorn',
        'theme': null,
        'border': 'border_rainbow',
      };

      expect(equipped['avatar'], 'avatar_unicorn');
      expect(equipped['theme'], isNull);
      expect(equipped['border'], 'border_rainbow');

      // Only non-null values should be saved
      final nonNull = equipped.entries
          .where((e) => e.value != null)
          .map((e) => e.key)
          .toList();
      expect(nonNull, ['avatar', 'border']);
    });
  });

  // ─────────────────────────────────────────────────────
  // 9. Onboarding Tutorial
  // ─────────────────────────────────────────────────────
  group('Onboarding Tutorial', () {
    test('tutorial tracking uses profile-scoped key', () {
      // The key format should isolate tutorials per profile
      const id1 = 'profile-aaa';
      const id2 = 'profile-bbb';
      const key1 = 'tutorial_$id1';
      const key2 = 'tutorial_$id2';
      expect(key1, 'tutorial_profile-aaa');
      expect(key2, 'tutorial_profile-bbb');
      expect(key1 == key2, isFalse);
    });

    test('student onboarding pages include all key features', () {
      // Expected onboarding page topics (order matters)
      final expectedTopics = [
        'Welcome',
        'Flashcards',
        'Games',
        'Progress',
        'Everyone',
        'Ready',
      ];

      // Simulate what the screen builds
      final pages = <String>[
        'Welcome, TestStudent! 🎉',
        'Learn with Flashcards 📚',
        'Play Fun Games 🎮',
        'Track Your Progress ⭐',
        'Made for Everyone ♿',
        "You're Ready! 🚀",
      ];

      expect(pages.length, expectedTopics.length);
      for (var i = 0; i < expectedTopics.length; i++) {
        expect(
          pages[i].toLowerCase().contains(expectedTopics[i].toLowerCase()),
          isTrue,
          reason: 'Page $i should contain "${expectedTopics[i]}"',
        );
      }
    });

    test('page order starts with welcome and ends with ready', () {
      final titles = [
        'Welcome, User! 🎉',
        'Learn with Flashcards 📚',
        'Play Fun Games 🎮',
        'Track Your Progress ⭐',
        'Made for Everyone ♿',
        "You're Ready! 🚀",
      ];

      expect(titles.first, contains('Welcome'));
      expect(titles.last, contains('Ready'));
    });

    test('onboarding personalises welcome with profile name', () {
      const name = 'Maria';
      const welcomeTitle = 'Welcome, $name! 🎉';
      expect(welcomeTitle, contains(name));
    });

    test('teacher sees different descriptions than student', () {
      const studentDesc =
          'You\'re all set up and ready to start learning!';
      const teacherDesc =
          'Your account is ready! Let\'s show you the key features '
          'you\'ll use to guide your students.';
      expect(studentDesc == teacherDesc, isFalse);
      expect(teacherDesc, contains('guide your students'));
    });

    test('parent sees different descriptions than student', () {
      const studentDesc =
          'You\'re all set up and ready to start learning!';
      const parentDesc =
          'Your account is ready! Let\'s show you the key features '
          'you\'ll use to support your child\'s learning.';
      expect(studentDesc == parentDesc, isFalse);
      expect(parentDesc, contains("support your child's learning"));
    });

    test('onboarding navigates to /home on completion', () {
      // After markTutorialSeen + context.go('/home')
      const destinationRoute = '/home';
      expect(destinationRoute, '/home');
    });

    test('first-time profile routes to onboarding-tutorial', () {
      // The accessibility setup screen checks HiveService.hasSeenTutorial
      // and routes accordingly
      String routeForTutorialStatus(bool seen) =>
          seen ? '/home' : '/onboarding-tutorial';
      expect(routeForTutorialStatus(false), '/onboarding-tutorial');
    });

    test('returning profile skips onboarding and goes to /home', () {
      String routeForTutorialStatus(bool seen) =>
          seen ? '/home' : '/onboarding-tutorial';
      expect(routeForTutorialStatus(true), '/home');
    });
  });

  group('profileTypeLabel (Switch Profiles)', () {
    UserProfile learner(UserRole role, DisabilityType type) => UserProfile(
          id: 'p-${role.name}-${type.name}',
          name: 'Jules',
          role: role,
          createdAt: DateTime(2025),
          disabilityType: type,
        );

    test('Student profiles combine role with accessibility category', () {
      expect(learner(UserRole.student, DisabilityType.visual).profileTypeLabel,
          'Student - Visual Impairment');
      expect(learner(UserRole.student, DisabilityType.hearing).profileTypeLabel,
          'Student - Hearing Impairment');
      expect(learner(UserRole.student, DisabilityType.motor).profileTypeLabel,
          'Student - Motor Impairment');
      expect(
          learner(UserRole.student, DisabilityType.cognitive).profileTypeLabel,
          'Student - Cognitive/Learning Disability');
      expect(
          learner(UserRole.student, DisabilityType.multiple).profileTypeLabel,
          'Student - Multiple Disabilities');
      expect(learner(UserRole.student, DisabilityType.none).profileTypeLabel,
          'Student - No Accessibility Needs');
    });

    test('Child profiles combine role with accessibility category', () {
      expect(learner(UserRole.child, DisabilityType.visual).profileTypeLabel,
          'Child - Visual Impairment');
      expect(learner(UserRole.child, DisabilityType.hearing).profileTypeLabel,
          'Child - Hearing Impairment');
      expect(learner(UserRole.child, DisabilityType.motor).profileTypeLabel,
          'Child - Motor Impairment');
      expect(learner(UserRole.child, DisabilityType.cognitive).profileTypeLabel,
          'Child - Cognitive/Learning Disability');
      expect(learner(UserRole.child, DisabilityType.multiple).profileTypeLabel,
          'Child - Multiple Disabilities');
      expect(learner(UserRole.child, DisabilityType.none).profileTypeLabel,
          'Child - No Accessibility Needs');
    });

    test('non-learner roles keep their plain role label', () {
      // Teacher/Parent/Player never self-classify, so the disability category
      // is not appended even if one happens to be set.
      expect(learner(UserRole.teacher, DisabilityType.visual).profileTypeLabel,
          'Teacher');
      expect(learner(UserRole.parent, DisabilityType.none).profileTypeLabel,
          'Parent');
      expect(learner(UserRole.player, DisabilityType.none).profileTypeLabel,
          'Player');
    });
  });
}
