import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/stt_service.dart';

void main() {
  group('SttService — Levenshtein distance', () {
    test('identical strings have distance 0', () {
      expect(SttService.levenshteinDistance('hello', 'hello'), 0);
    });

    test('empty strings', () {
      expect(SttService.levenshteinDistance('', ''), 0);
      expect(SttService.levenshteinDistance('abc', ''), 3);
      expect(SttService.levenshteinDistance('', 'abc'), 3);
    });

    test('single insertion', () {
      expect(SttService.levenshteinDistance('cat', 'cats'), 1);
    });

    test('single deletion', () {
      expect(SttService.levenshteinDistance('cats', 'cat'), 1);
    });

    test('single substitution', () {
      expect(SttService.levenshteinDistance('cat', 'bat'), 1);
    });

    test('multiple edits', () {
      expect(SttService.levenshteinDistance('kitten', 'sitting'), 3);
    });

    test('completely different strings', () {
      expect(SttService.levenshteinDistance('abc', 'xyz'), 3);
    });

    test('case sensitive', () {
      expect(SttService.levenshteinDistance('Dog', 'dog'), 1);
    });
  });

  group('SttService — fuzzy matching', () {
    test('exact match (case-insensitive)', () {
      expect(SttService.isFuzzyMatch('Dog', 'dog'), true);
      expect(SttService.isFuzzyMatch('DOG', 'Dog'), true);
    });

    test('short word allows 1 edit distance', () {
      // 'cat' is 3 chars, maxDist = 1
      expect(SttService.isFuzzyMatch('cat', 'bat'), true);  // 1 substitution
      expect(SttService.isFuzzyMatch('cat', 'cab'), true);  // 1 substitution (t→b)
    });

    test('short word does not allow 2 edits', () {
      // 'dog' → 'big' = 2 edits
      expect(SttService.isFuzzyMatch('big', 'dog'), false);
    });

    test('long word allows proportional edits', () {
      // 'elephant' = 8 chars, maxDist = ceil(8*0.15) = 2
      expect(SttService.isFuzzyMatch('elefant', 'elephant'), true); // 1 edit (ph→f) — actually 2 (p→f, remove h) = 2
    });

    test('whitespace is trimmed', () {
      expect(SttService.isFuzzyMatch('  dog  ', 'dog'), true);
    });

    test('completely different words fail', () {
      expect(SttService.isFuzzyMatch('apple', 'zebra'), false);
    });

    test('empty spoken string', () {
      expect(SttService.isFuzzyMatch('', 'dog'), false);
    });

    test('both empty', () {
      expect(SttService.isFuzzyMatch('', ''), true);
    });

    test('medium word with 1 typo matches', () {
      // 'pencil' = 6 chars, maxDist = ceil(6*0.15) = 1
      expect(SttService.isFuzzyMatch('pensil', 'pencil'), true);
    });

    test('medium word with 2 typos fails', () {
      // 'pencil' = 6 chars, maxDist = 1
      expect(SttService.isFuzzyMatch('pinsol', 'pencil'), false);
    });
  });
}
