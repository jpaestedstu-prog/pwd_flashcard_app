import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';

/// A card's word in both languages, as a voice says it.
///
/// Five words are the same in English and Filipino ("T-shirt", "Shorts",
/// "Ruler", "Bus", "Proud"), and TalkBack read the Flashcard Quiz card as
/// "T-shirt, T-shirt" (found by the screen-reader sweep, 30 Oct).
void main() {
  Flashcard card(String english, String filipino) => Flashcard(
        id: 'x',
        wordEnglish: english,
        wordFilipino: filipino,
        category: FlashcardCategory.clothing,
      );

  test('two words, in both languages', () {
    expect(card('Dog', 'Aso').spokenWords(), 'Dog, Aso');
    expect(card('Dog', 'Aso').spokenWords(separator: '. '), 'Dog. Aso');
  });

  test('a word the languages share is said once', () {
    expect(card('T-shirt', 'T-shirt').spokenWords(), 'T-shirt');
    expect(card('Bus', 'bus').spokenWords(separator: '. '), 'Bus');
  });
}
