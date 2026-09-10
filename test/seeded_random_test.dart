import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/seeded_random.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';

/// The contract the screen matrix depends on.
///
/// Screens that pick their own content shuffle from [contentRandom], so the
/// matrix can only be repeatable if that function is. Five green runs would not
/// have proved it — the suite was green three runs in a row before
/// `FlashcardQuizScreen` drew "Wednesday" and failed. What has to be true is
/// stated directly here instead.
void main() {
  tearDown(() => debugContentRandomSeed = null);

  List<int> draw({int n = 32}) =>
      List.generate(n, (_) => contentRandom().nextInt(1 << 30));

  test('a set seed makes every draw repeatable', () {
    debugContentRandomSeed = 7;
    final first = draw();
    final second = draw();

    // Each screen builds its own Random via contentRandom(), so what matters is
    // that separately-constructed instances agree — not that one instance is
    // internally consistent.
    expect(second, first);
  });

  test('different seeds draw differently', () {
    debugContentRandomSeed = 1;
    final one = draw();
    debugContentRandomSeed = 2;
    final two = draw();

    // The matrix varies the seed per device/scale combination so the sweep
    // still covers several card draws. That is only worth doing if the seed
    // actually changes the draw.
    expect(two, isNot(one));
  });

  test('with no seed it is random again, which is what ships', () {
    // The production path. `Random(null)` is `Random()`, so a learner sees the
    // same shuffling they always did; only tests ever set the seed.
    expect(debugContentRandomSeed, isNull);

    final a = draw(n: 64);
    final b = draw(n: 64);
    expect(
      a,
      isNot(b),
      reason: 'unseeded draws should not repeat — the seed leaked',
    );
  });

  test('the card shuffle the game screens perform is repeatable', () {
    // Mirrors TapQuizState.initState exactly: the pool is copied and shuffled
    // from contentRandom(). This is the draw that decides which flashcard the
    // matrix renders, so it is the one that has to be stable — the RNG tests
    // above prove the source, this proves the thing built on it.
    List<String> order() => (List.of(
      SeedData.allFlashcards,
    )..shuffle(contentRandom())).take(12).map((c) => c.id).toList();

    debugContentRandomSeed = 3;
    final three = order();
    expect(order(), three, reason: 'the same seed must deal the same cards');

    debugContentRandomSeed = 4;
    expect(
      order(),
      isNot(three),
      reason:
          'a different seed must deal different cards, or varying the '
          'seed per matrix combination buys no extra coverage',
    );
  });
}
