import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/showcase/models/showcase_models.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('ShowcaseItemType', () {
    test('has all expected types', () {
      expect(ShowcaseItemType.values.length, 7);
      expect(ShowcaseItemType.values, containsAll([
        ShowcaseItemType.achievement,
        ShowcaseItemType.highScore,
        ShowcaseItemType.categoryMastery,
        ShowcaseItemType.learningPathComplete,
        ShowcaseItemType.streakMilestone,
        ShowcaseItemType.assessmentResult,
        ShowcaseItemType.customNote,
      ]));
    });

    test('each type has non-empty label and emoji', () {
      for (final t in ShowcaseItemType.values) {
        expect(t.label.isNotEmpty, true, reason: '${t.name} label');
        expect(t.emoji.isNotEmpty, true, reason: '${t.name} emoji');
      }
    });
  });

  group('ShowcaseItem', () {
    final now = DateTime(2025, 1, 15, 10, 30);
    final item = ShowcaseItem(
      id: 'test-1',
      type: ShowcaseItemType.highScore,
      title: 'Word Match Champion',
      description: 'Scored 3 stars in Word Match',
      earnedAt: now,
      isPinned: true,
      score: 95,
      category: FlashcardCategory.animals,
      gameType: GameType.wordMatch,
    );

    test('toJson produces correct map', () {
      final json = item.toJson();
      expect(json['id'], 'test-1');
      expect(json['type'], ShowcaseItemType.highScore.index);
      expect(json['title'], 'Word Match Champion');
      expect(json['description'], 'Scored 3 stars in Word Match');
      expect(json['isPinned'], true);
      expect(json['score'], 95);
      expect(json['category'], FlashcardCategory.animals.index);
      expect(json['gameType'], GameType.wordMatch.index);
      expect(json['earnedAt'], now.toIso8601String());
    });

    test('fromJson creates identical item', () {
      final json = item.toJson();
      final restored = ShowcaseItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.type, item.type);
      expect(restored.title, item.title);
      expect(restored.description, item.description);
      expect(restored.isPinned, item.isPinned);
      expect(restored.score, item.score);
      expect(restored.category, item.category);
      expect(restored.gameType, item.gameType);
      expect(restored.earnedAt, item.earnedAt);
    });

    test('toJson → fromJson roundtrip', () {
      final json = item.toJson();
      final restored = ShowcaseItem.fromJson(json);
      expect(restored.id, item.id);
      expect(restored.type, item.type);
      expect(restored.title, item.title);
      expect(restored.isPinned, item.isPinned);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'min-1',
        'type': ShowcaseItemType.customNote.index,
        'title': 'A note',
        'description': 'My note',
        'earnedAt': now.toIso8601String(),
        'isPinned': false,
      };
      final restored = ShowcaseItem.fromJson(json);
      expect(restored.id, 'min-1');
      expect(restored.type, ShowcaseItemType.customNote);
      expect(restored.score, isNull);
      expect(restored.category, isNull);
      expect(restored.gameType, isNull);
      expect(restored.masteryPercent, isNull);
      expect(restored.customNote, isNull);
    });

    test('fromJson handles invalid type index gracefully', () {
      final json = {
        'id': 'bad-type',
        'type': 999,
        'title': 'Bad',
        'description': 'x',
        'earnedAt': now.toIso8601String(),
        'isPinned': false,
      };
      final restored = ShowcaseItem.fromJson(json);
      // Should fallback to customNote (last type)
      expect(restored.type, ShowcaseItemType.customNote);
    });

    test('copyWith creates modified copy', () {
      final modified = item.copyWith(isPinned: false, title: 'New Title');
      expect(modified.isPinned, false);
      expect(modified.title, 'New Title');
      // Unchanged fields
      expect(modified.id, item.id);
      expect(modified.type, item.type);
      expect(modified.score, item.score);
      expect(modified.description, item.description);
    });
  });

  group('ShowcasePortfolio', () {
    final now = DateTime(2025, 1, 15);
    final items = [
      ShowcaseItem(
        id: '1',
        type: ShowcaseItemType.achievement,
        title: 'First Achievement',
        description: 'Got it',
        earnedAt: now,
      ),
      ShowcaseItem(
        id: '2',
        type: ShowcaseItemType.highScore,
        title: 'High Score',
        description: 'Top score',
        earnedAt: now.add(const Duration(hours: 1)),
        isPinned: true,
      ),
      ShowcaseItem(
        id: '3',
        type: ShowcaseItemType.achievement,
        title: 'Second Achievement',
        description: 'Another one',
        earnedAt: now.add(const Duration(hours: 2)),
      ),
    ];

    test('sortedItems puts pinned first, then by date descending', () {
      final portfolio = ShowcasePortfolio(
        profileId: 'p-1',
        profileName: 'Test',
        items: items,
        lastUpdated: now,
      );
      final sorted = portfolio.sortedItems;
      expect(sorted.first.id, '2'); // Pinned
      expect(sorted[1].id, '3'); // Most recent non-pinned
      expect(sorted[2].id, '1'); // Oldest
    });

    test('typeCounts counts each type correctly', () {
      final portfolio = ShowcasePortfolio(
        profileId: 'p-1',
        profileName: 'Test',
        items: items,
        lastUpdated: now,
      );
      final counts = portfolio.typeCounts;
      expect(counts[ShowcaseItemType.achievement], 2);
      expect(counts[ShowcaseItemType.highScore], 1);
      expect(counts.containsKey(ShowcaseItemType.customNote), false);
    });

    test('pinnedCount returns correct count', () {
      final portfolio = ShowcasePortfolio(
        profileId: 'p-1',
        profileName: 'Test',
        items: items,
        lastUpdated: now,
      );
      expect(portfolio.pinnedCount, 1);
    });

    test('empty portfolio has zero counts', () {
      final portfolio = ShowcasePortfolio(
        profileId: 'p-1',
        profileName: 'Test',
        items: [],
        lastUpdated: now,
      );
      expect(portfolio.sortedItems, isEmpty);
      expect(portfolio.typeCounts, isEmpty);
      expect(portfolio.pinnedCount, 0);
    });
  });
}
