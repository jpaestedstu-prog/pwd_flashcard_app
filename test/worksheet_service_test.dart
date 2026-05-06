import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/worksheet_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

void main() {
  group('WorksheetType', () {
    test('all types have unique labels', () {
      final labels = WorksheetType.values.map((t) => t.label).toSet();
      expect(labels.length, WorksheetType.values.length);
    });

    test('all types have non-empty descriptions', () {
      for (final t in WorksheetType.values) {
        expect(t.description, isNotEmpty, reason: '${t.name} missing desc');
      }
    });

    test('all types have emoji', () {
      for (final t in WorksheetType.values) {
        expect(t.emoji, isNotEmpty, reason: '${t.name} missing emoji');
      }
    });
  });

  group('WorksheetService.generate', () {
    test('generates word tracing PDF bytes', () async {
      final bytes = await WorksheetService.generate(
        type: WorksheetType.wordTracing,
        category: FlashcardCategory.animals,
        difficulty: GameDifficulty.easy,
      );
      expect(bytes, isNotEmpty);
      // PDF files start with %PDF
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('generates picture matching PDF bytes', () async {
      final bytes = await WorksheetService.generate(
        type: WorksheetType.pictureMatching,
        category: FlashcardCategory.colorsAndShapes,
        difficulty: GameDifficulty.medium,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('generates fill in the blank PDF bytes', () async {
      final bytes = await WorksheetService.generate(
        type: WorksheetType.fillInTheBlank,
        category: FlashcardCategory.foodAndDrinks,
        difficulty: GameDifficulty.easy,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('generates word search PDF bytes', () async {
      final bytes = await WorksheetService.generate(
        type: WorksheetType.wordSearch,
        category: FlashcardCategory.animals,
        difficulty: GameDifficulty.hard,
      );
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
    });

    test('different difficulties generate valid PDFs', () async {
      for (final diff in GameDifficulty.values) {
        final bytes = await WorksheetService.generate(
          type: WorksheetType.wordTracing,
          category: FlashcardCategory.animals,
          difficulty: diff,
        );
        expect(bytes, isNotEmpty, reason: '${diff.name} should produce PDF');
        expect(String.fromCharCodes(bytes.take(5)), startsWith('%PDF'));
      }
    });
  });
}
