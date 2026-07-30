import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../../data/models/models.dart';
import '../../../data/models/enums.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/spaced_repetition_service.dart';
import '../models/tutor_models.dart';

const _uuid = Uuid();

/// Rule-based adaptive tutor engine.
/// Analyzes learning progress and generates contextual messages,
/// hints, practice suggestions, and mini-quizzes.
class TutorEngine {
  TutorEngine._();

  static final _random = Random();

  // ─── Interest model ─────────────────────────────────────────────────────
  //
  // The tutor personalizes examples around topics the learner *loves*, not
  // just topics they're weak in. Interests come from two signals:
  //   * explicit — the learner taps a favorite-topic chip ("pickInterests");
  //   * implicit — repeated behavior (asking about a category, answering its
  //     quizzes) accumulates a per-category score.
  // Both live in [TutorMemory] so the buddy remembers across sessions.

  /// Max explicit favorites remembered (most recent first).
  static const int maxFavorites = 3;

  /// Implicit score a category needs before it counts as an interest.
  static const double interestThreshold = 2.0;

  /// Ceiling so one obsession can't grow unboundedly.
  static const double maxInterestScore = 50.0;

  // Signal weights.
  static const double signalPick = 3.0; // explicit favorite tap
  static const double signalAsk = 1.0; // asked about the category
  static const double signalQuiz = 0.5; // answered a quiz in it
  static const double signalQuizCorrect = 0.5; // …and got it right

  /// Resolves the learner's current interests: explicit favorites first (in
  /// pick order), then implicit categories whose score passed the threshold,
  /// strongest first. Deduplicated and capped at [max].
  static List<FlashcardCategory> topInterests(TutorMemory memory,
      {int max = maxFavorites}) {
    final result = <FlashcardCategory>[];
    for (final name in memory.favoriteCategories) {
      final cat = categoryFromName(name);
      if (cat != null && !result.contains(cat)) result.add(cat);
    }
    final implicit = memory.interestScores.entries
        .where((e) => e.value >= interestThreshold)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final e in implicit) {
      final cat = categoryFromName(e.key);
      if (cat != null && !result.contains(cat)) result.add(cat);
    }
    return result.take(max).toList();
  }

  /// Returns a new score map with [category] bumped by [amount], clamped to
  /// [0, maxInterestScore].
  static Map<String, double> bumpInterest(
      Map<String, double> scores, FlashcardCategory category, double amount) {
    final next = Map<String, double>.from(scores);
    next[category.name] = ((next[category.name] ?? 0) + amount)
        .clamp(0.0, maxInterestScore)
        .toDouble();
    return next;
  }

  /// Looks up a category by its enum [name] (the stored identifier).
  static FlashcardCategory? categoryFromName(String name) {
    for (final c in FlashcardCategory.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Looks up a category by display label (English or Filipino) or enum name.
  static FlashcardCategory? categoryFromLabel(String label) {
    for (final c in FlashcardCategory.values) {
      if (c.label == label || c.labelFilipino == label || c.name == label) {
        return c;
      }
    }
    return null;
  }

  /// Finds a category mentioned in free text — matches the full English or
  /// Filipino label, or any distinctive (5+ letter) word of either, so
  /// "I like animals" and "gusto ko ang mga hayop" both resolve.
  static FlashcardCategory? categoryInText(String text) {
    final lower = text.toLowerCase();
    for (final c in FlashcardCategory.values) {
      for (final label in [c.label, c.labelFilipino]) {
        final lowerLabel = label.toLowerCase();
        if (lower.contains(lowerLabel)) return c;
        for (final token in lowerLabel.split(RegExp(r'[^a-zà-ÿ]+'))) {
          if (token.length >= 5 && lower.contains(token)) return c;
        }
      }
    }
    return null;
  }

  /// True when [question] matches none of the engine's structured intents
  /// (quiz, lesson, hint, practice, progress, favorites, or a named category).
  ///
  /// The companion uses this as the boundary for the optional online model:
  /// structured intents ALWAYS stay on the offline engine (so its quizzes,
  /// lessons, and favorite-topic chips keep working with no network), and only
  /// genuinely open-ended questions are eligible to be routed to Gemini.
  static bool isFreeForm(String question) {
    final q = question.toLowerCase();
    if (categoryInText(q) != null) return false;
    const triggers = [
      // liking / favorites
      'i like', 'i love', 'favorite', 'favourite', 'interest',
      'gusto', 'mahilig', 'paborito',
      // help / hint
      'help', 'hint', 'tulong', 'pahiwatig',
      // quiz
      'quiz', 'test', 'pagsusulit',
      // plan / lesson
      'plan', 'lesson', 'today', 'aralin', 'ngayon',
      // practice
      'practice', 'review', 'pagsasanay',
      // progress
      'progress', 'score', 'how am i', 'pag-unlad',
    ];
    for (final t in triggers) {
      if (q.contains(t)) return false;
    }
    return true;
  }

  /// Generate an initial greeting message
  static TutorMessage greet(String studentName, {bool isFilipino = false}) {
    final greetings = isFilipino
        ? [
            'Kumusta, $studentName! 👋 Ako ang iyong tutor. Paano kita matutulungan ngayon?',
            'Magandang araw, $studentName! 🌟 Handa ka na bang matuto?',
            'Hello, $studentName! 📚 Tanungin mo ako tungkol sa mga salita!',
          ]
        : [
            'Hi $studentName! 👋 I\'m your learning buddy. How can I help today?',
            'Hello $studentName! 🌟 Ready to learn some new words?',
            'Hey $studentName! 📚 Ask me about any vocabulary topic!',
          ];

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: greetings[_random.nextInt(greetings.length)],
      timestamp: DateTime.now(),
    );
  }

  /// Analyze progress and generate a contextual response
  static TutorMessage analyzeAndRespond(
    LearningProgress progress,
    String studentName,
    String profileId, {
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
    bool simple = false,
  }) {
    // Check for weak categories
    final weakCategories = <String>[];
    final strongCategories = <String>[];
    for (final entry in progress.categoryProgress.entries) {
      if (entry.value < 0.4) {
        weakCategories.add(entry.key);
      } else if (entry.value >= 0.8) {
        strongCategories.add(entry.key);
      }
    }

    // Check streak
    if (progress.streakDays >= 7) {
      return _streakCelebration(progress.streakDays, isFilipino: isFilipino);
    }

    // Check if there are weak categories
    if (weakCategories.isNotEmpty) {
      return _weakCategoryAdvice(weakCategories.first,
          isFilipino: isFilipino);
    }

    // Celebrate strong categories
    if (strongCategories.isNotEmpty) {
      return _strongCategoryMessage(strongCategories, isFilipino: isFilipino);
    }

    // Default: offer today's personalized learning plan.
    return offerLearningPlan(progress, profileId,
        isFilipino: isFilipino, interests: interests, simple: simple);
  }

  /// Generate a response to a student question
  /// Generate a response to a student question.
  ///
  /// [activeCard] is the word behind the quiz still waiting for an answer, if
  /// any. It makes "hint" mean *this* question rather than a study tip.
  static TutorMessage respondToQuestion(
    String question,
    LearningProgress progress,
    String profileId, {
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
    Flashcard? activeCard,
    bool simple = false,
  }) {
    final lowerQ = question.toLowerCase();
    final mentioned = categoryInText(lowerQ);

    // "I like animals" / "gusto ko ang mga hayop" → record the favorite.
    // Checked before the category-info branch so liking beats describing.
    const likingVerbs = ['i like', 'i love', 'favorite', 'favourite',
        'gusto', 'mahilig', 'paborito'];
    final expressesLiking = likingVerbs.any(lowerQ.contains);
    if (expressesLiking && mentioned != null) {
      return interestConfirmation(mentioned, isFilipino: isFilipino);
    }

    // "favorites" / "paborito" with no topic named → show the topic picker.
    if (lowerQ.contains('favorite') ||
        lowerQ.contains('favourite') ||
        lowerQ.contains('interest') ||
        lowerQ.contains('paborito') ||
        lowerQ.contains('mahilig')) {
      return askInterests(isFilipino: isFilipino);
    }

    // Check for category queries
    if (mentioned != null) {
      return _categoryInfo(mentioned, progress,
          isFilipino: isFilipino, simple: simple);
    }

    // Check for help/hint requests. With a question on screen, help means
    // help with *that* — the study tips are for when nothing is pending.
    if (lowerQ.contains('help') ||
        lowerQ.contains('hint') ||
        lowerQ.contains('tulong') ||
        lowerQ.contains('pahiwatig')) {
      return activeCard != null
          ? hintForWord(activeCard, isFilipino: isFilipino)
          : _provideHint(progress, isFilipino: isFilipino, simple: simple);
    }

    // Check for quiz requests
    if (lowerQ.contains('quiz') ||
        lowerQ.contains('test') ||
        lowerQ.contains('pagsusulit')) {
      return quickQuiz(isFilipino: isFilipino, interests: interests);
    }

    // Check for learning-plan / daily lesson requests
    if (lowerQ.contains('plan') ||
        lowerQ.contains('lesson') ||
        lowerQ.contains('today') ||
        lowerQ.contains('aralin') ||
        lowerQ.contains('ngayon')) {
      return offerLearningPlan(progress, profileId,
          isFilipino: isFilipino, interests: interests, simple: simple);
    }

    // Check for practice requests
    if (lowerQ.contains('practice') ||
        lowerQ.contains('review') ||
        lowerQ.contains('pagsasanay')) {
      return _suggestPractice(progress, isFilipino: isFilipino);
    }

    // Check for progress queries
    if (lowerQ.contains('progress') ||
        lowerQ.contains('score') ||
        lowerQ.contains('how am i') ||
        lowerQ.contains('pag-unlad')) {
      return _progressSummary(progress,
          isFilipino: isFilipino, simple: simple);
    }

    // Default response
    final defaults = isFilipino
        ? [
            'Subukan mong tanungin ako tungkol sa isang kategorya, o sabihin "quiz" para sa isang mabilisang pagsusulit! 😊',
            'Pwede mong sabihin: "practice", "hint", "quiz", "paborito", o tanungin mo ako tungkol sa anumang kategorya! 📖',
            'Hindi ko masyadong naintindihan. Subukan mo: "Tulong sa Animals" o "Bigyan mo ako ng quiz"! 🤔',
          ]
        : [
            'Try asking me about a category, or say "quiz" for a quick question! 😊',
            'You can say: "practice", "hint", "quiz", "favorites", or ask about any category! 📖',
            'I\'m not sure what you mean. Try: "Help with Animals" or "Give me a quiz"! 🤔',
          ];

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: defaults[_random.nextInt(defaults.length)],
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _streakCelebration(int days,
      {bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '🔥 Wow! $days-araw na streak! Napakahusay mo! Ituloy mo lang, ikaw ang pinakamagaling!'
          : '🔥 Amazing! $days-day streak! You\'re doing incredible! Keep it up, superstar!',
      timestamp: DateTime.now(),
      action: const TutorAction(type: TutorActionType.encouragement),
    );
  }

  static TutorMessage _weakCategoryAdvice(String category,
      {bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📝 Napansin ko na kailangan mo pa ng kaunting practice sa "$category". Gusto mo bang mag-practice doon?'
          : '📝 I noticed "$category" needs some practice. Want to work on it? Tap below to start!',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.practiceRedirect,
        targetRoute: '/guided-practice',
      ),
    );
  }

  static TutorMessage _strongCategoryMessage(List<String> categories,
      {bool isFilipino = false}) {
    final catList = categories.take(3).join(', ');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '⭐ Napakagaling mo sa: $catList! Subukan natin ang mas mahirap na kategorya?'
          : '⭐ You\'re doing great in: $catList! Want to try a harder category?',
      timestamp: DateTime.now(),
    );
  }

  static TutorMessage _wordOfTheDay({
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
  }) {
    final card = _pickCard(interests);
    if (card == null) {
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: isFilipino
            ? 'Handa ka na bang matuto? Sabihin "quiz" o "practice"! 📚'
            : 'Ready to learn? Say "quiz" or "practice"! 📚',
        timestamp: DateTime.now(),
      );
    }
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📖 Salita ng Araw:\n\nEnglish: ${card.wordEnglish}\nFilipino: ${card.wordFilipino}\n${card.exampleSentence != null ? '\n"${card.exampleSentence}"' : ''}'
          : '📖 Word of the Day:\n\nEnglish: ${card.wordEnglish}\nFilipino: ${card.wordFilipino}\n${card.exampleSentence != null ? '\n"${card.exampleSentence}"' : ''}',
      timestamp: DateTime.now(),
      action: const TutorAction(type: TutorActionType.wordOfTheDay),
    );
  }

  static TutorMessage _categoryInfo(
      FlashcardCategory cat, LearningProgress progress,
      {bool isFilipino = false, bool simple = false}) {
    final prog = progress.categoryProgress[cat.label] ?? 0.0;
    final pct = (prog * 100).round();
    final cards = SeedData.getByCategory(cat);
    // A percentage is an abstraction; a count of real words is not.
    final known = (prog * cards.length).round();
    final label = isFilipino ? cat.labelFilipino : cat.label;
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: simple
          ? (isFilipino
              ? '${cat.emoji} $label: alam mo na ang $known sa ${cards.length} salita.\n\n${prog < 0.5 ? 'Matuto pa tayo!' : 'Ang galing mo!'}'
              : '${cat.emoji} $label: you know $known of ${cards.length} words.\n\n${prog < 0.5 ? 'Let\'s learn more!' : 'You are doing great!'}')
          : (isFilipino
              ? '📊 ${cat.label}: $pct% na-master mo. Mayroong ${cards.length} salita sa kategiryang ito. ${prog < 0.5 ? 'Kailangan pa ng practice!' : 'Magaling ang progress mo!'}'
              : '📊 ${cat.label}: You\'ve mastered $pct%. There are ${cards.length} words in this category. ${prog < 0.5 ? 'Let\'s practice more!' : 'Great progress!'}'),
      timestamp: DateTime.now(),
    );
  }

  /// A hint about the question the learner is actually looking at.
  ///
  /// "Hint" used to answer with a generic study tip ("Read stories to see how
  /// words are used"), which is advice for next week, not help with the word
  /// on screen — the moment a learner asks for a hint is the moment they are
  /// stuck on *this* question.
  ///
  /// Scaffolds without giving the answer away: the topic, then the shape of
  /// the word (first letter and length), then the example sentence with the
  /// English word masked. The sentence is a meaning clue — the answer is the
  /// Filipino word, so showing the English context narrows the meaning
  /// without revealing what to tap.
  static TutorMessage hintForWord(Flashcard card, {bool isFilipino = false}) {
    final answer = card.wordFilipino;
    final letters = answer.replaceAll(RegExp(r'\s'), '').length;
    final label = isFilipino ? card.category.labelFilipino : card.category.label;

    final buffer = StringBuffer();
    buffer.write(isFilipino
        ? '💡 Isa itong salita tungkol sa $label ${card.category.emoji}.'
        : '💡 It\'s a $label word ${card.category.emoji}.');
    buffer.write(isFilipino
        ? '\nNagsisimula ito sa "${answer[0]}" at may $letters na letra.'
        : '\nIt starts with "${answer[0]}" and has $letters letters.');

    final masked = _maskWord(card.exampleSentence, card.wordEnglish);
    if (masked != null) buffer.write('\n\n💬 "$masked"');

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: buffer.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// [sentence] with whole-word occurrences of [word] replaced by a blank.
  /// Null when there is no sentence, or the word does not appear in it (a
  /// sentence that never mentions the word is no clue at all).
  static String? _maskWord(String? sentence, String word) {
    final text = sentence?.trim();
    if (text == null || text.isEmpty || word.isEmpty) return null;
    final pattern = RegExp(
      '\\b${RegExp.escape(word)}\\b',
      caseSensitive: false,
    );
    if (!pattern.hasMatch(text)) return null;
    return text.replaceAll(pattern, '___');
  }

  static TutorMessage _provideHint(LearningProgress progress,
      {bool isFilipino = false, bool simple = false}) {
    if (simple) {
      final tips = isFilipino
          ? [
              '💡 Maglaro kahit kaunti araw-araw. Nakakatulong ito!',
              '💡 Tingnan ang larawan. Tapos sabihin ang salita.',
              '💡 Sabihin nang malakas ang salita. Mas madali itong tandaan!',
              '💡 Subukan ang mga laro. Masaya at nakakatulong!',
            ]
          : [
              '💡 Play a little every day. It helps you remember!',
              '💡 Look at the picture. Then say the word.',
              '💡 Say the word out loud. That helps you remember it!',
              '💡 Try the games. They are fun and they help!',
            ];
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: tips[_random.nextInt(tips.length)],
        timestamp: DateTime.now(),
      );
    }
    final hints = isFilipino
        ? [
            '💡 Subukan mong gamitin ang Flashcards araw-araw. Ang pag-uulit ang susi sa pag-alala!',
            '💡 Maglaro ng mga games pagkatapos mag-review ng flashcards — mas matanda ang mga salita.',
            '💡 Basahin ang mga stories para makita kung paano ginagamit ang mga salita sa pangungusap.',
            '💡 Gamitin ang Smart Review para i-focus ang mga salitang mahirap para sa iyo.',
          ]
        : [
            '💡 Try reviewing Flashcards every day. Repetition is key to remembering!',
            '💡 Play games after reviewing flashcards — it reinforces the words.',
            '💡 Read stories to see how words are used in sentences.',
            '💡 Use Smart Review to focus on words you find difficult.',
          ];
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: hints[_random.nextInt(hints.length)],
      timestamp: DateTime.now(),
    );
  }

  /// Looks up a seed flashcard by [id]. Null when the id is unknown (custom or
  /// removed card), so callers can skip gracefully.
  static Flashcard? cardById(String id) {
    for (final c in SeedData.allFlashcards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Re-teaches a word the learner just got wrong.
  ///
  /// A miss used to end at "the correct answer is X" and move straight on,
  /// which tells the learner *that* they were wrong but never re-teaches the
  /// word. This puts the pair back in front of them with whatever context the
  /// card carries — an example sentence and a kid-friendly definition — so the
  /// correction is a teaching moment rather than a verdict.
  static TutorMessage reteach(Flashcard card, {bool isFilipino = false}) {
    final buffer = StringBuffer();
    buffer.write(isFilipino
        ? '📖 Balikan natin ito. Ang "${card.wordEnglish}" ay "${card.wordFilipino}" ${card.category.emoji}'
        : '📖 Let\'s look at it again. "${card.wordEnglish}" is "${card.wordFilipino}" ${card.category.emoji}');
    if (card.exampleSentence != null && card.exampleSentence!.trim().isNotEmpty) {
      buffer.write('\n\n💬 "${card.exampleSentence!.trim()}"');
    }
    if (card.definition != null && card.definition!.trim().isNotEmpty) {
      buffer.write('\n\nℹ️ ${card.definition!.trim()}');
    }
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: buffer.toString(),
      timestamp: DateTime.now(),
      // Carries the word so the bubble can add the card's picture / sign —
      // a re-teach is exactly where a second sense is worth the space.
      action: TutorAction(type: TutorActionType.reteach, wordId: card.id),
    );
  }

  /// Announces the end-of-lesson retry round over the words that were missed,
  /// so "try again next time" actually happens in the same sitting.
  static TutorMessage reviewRoundIntro(int count, {bool isFilipino = false}) {
    final word = isFilipino
        ? (count == 1 ? 'salita' : 'salita')
        : (count == 1 ? 'word' : 'words');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '🔁 Balikan natin ang $count $word na nahirapan ka. Kaya mo ito! 💪'
          : '🔁 Let\'s try the $count $word you found tricky one more time. You\'ve got this! 💪',
      timestamp: DateTime.now(),
    );
  }

  /// Picks a flashcard, preferring the learner's interest categories when any
  /// exist (a random favorite, then a random card within it). Falls back to
  /// the full pool. Null only when no seed cards exist at all.
  static Flashcard? _pickCard(List<FlashcardCategory> interests) {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) return null;
    if (interests.isNotEmpty) {
      final cat = interests[_random.nextInt(interests.length)];
      final pool = SeedData.getByCategory(cat);
      if (pool.isNotEmpty) return pool[_random.nextInt(pool.length)];
    }
    return allCards[_random.nextInt(allCards.length)];
  }

  /// A standalone quick quiz. With [interests], the word comes from a favorite
  /// topic and the header says so ("your favorite!").
  static TutorMessage quickQuiz({
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
  }) {
    final card = _pickCard(interests);
    if (card == null) {
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: isFilipino
            ? 'Walang available na quiz ngayon.'
            : 'No quiz available right now.',
        timestamp: DateTime.now(),
      );
    }

    String? prefix;
    if (interests.contains(card.category)) {
      final catLabel =
          isFilipino ? card.category.labelFilipino : card.category.label;
      prefix = isFilipino
          ? '❓ Quiz tungkol sa $catLabel ${card.category.emoji} — paborito mo!'
          : '❓ A ${card.category.emoji} $catLabel quiz — your favorite!';
    }
    return quizForWord(card, isFilipino: isFilipino, prefix: prefix);
  }

  /// Invites the learner to pick favorite topics via tappable chips. The
  /// action's options carry [FlashcardCategory] enum names; the chat bubble
  /// renders them as localized emoji chips.
  static TutorMessage askInterests({bool isFilipino = false}) {
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '💖 Anong paksa ang paborito mo? Pumili ng isa — gagamit ako ng mga salitang gusto mo sa ating mga quiz at halimbawa!'
          : '💖 What topic do you love? Pick one — I\'ll use more words you like in our quizzes and examples!',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.pickInterests,
        options: FlashcardCategory.values.map((c) => c.name).toList(),
      ),
    );
  }

  /// Confirms a newly picked favorite topic. The action carries the category
  /// name (no options) so the screen can record the pick when this message
  /// came from free text ("I like animals") rather than a chip tap.
  static TutorMessage interestConfirmation(FlashcardCategory category,
      {bool isFilipino = false}) {
    final label = isFilipino ? category.labelFilipino : category.label;
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '🎉 Magaling na pili! Gagamit ako ng mas maraming salita tungkol sa $label ${category.emoji} sa ating mga quiz at aralin!'
          : '🎉 Great choice! I\'ll use more $label ${category.emoji} words in our quizzes and lessons!',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.pickInterests,
        categoryLabel: category.name,
      ),
    );
  }

  /// A "welcome back" for a returning learner on a new day — mentions their
  /// favorite topic and offers today's (interest-aware) lesson plan.
  static TutorMessage welcomeBack(
    String studentName,
    LearningProgress progress,
    String profileId, {
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
  }) {
    final plan =
        buildLearningPlan(progress, profileId, interests: interests);
    final favLine = interests.isEmpty
        ? ''
        : (isFilipino
            ? ' Handa ka na ba para sa mas maraming ${interests.first.labelFilipino} ${interests.first.emoji}?'
            : ' Ready for more ${interests.first.label} ${interests.first.emoji} words?');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '👋 Maligayang pagbabalik, $studentName!$favLine Pindutin sa ibaba para sa aralin ngayong araw!'
          : '👋 Welcome back, $studentName!$favLine Tap below to start today\'s lesson!',
      timestamp: DateTime.now(),
      action: plan.isEmpty
          ? null
          : TutorAction(
              type: TutorActionType.startLesson,
              planWordIds: plan.map((c) => c.id).toList(),
            ),
    );
  }

  /// Builds a multiple-choice quiz message for a specific [card]. The action
  /// carries [wordId]/[categoryLabel] so a correct answer can be recorded
  /// against spaced-repetition and progress tracking.
  /// Wrong answers for [card], drawn from its **own category** first.
  ///
  /// Mixing categories makes a question answerable without knowing the word:
  /// asked for the Filipino for "Cat" against *Pusa / Tumayo / Upuan /
  /// Kumanta*, only one option is even an animal, so elimination scores a
  /// point the learner has not earned — and that false positive is then fed
  /// to spaced repetition, which stops resurfacing a word they never learned.
  /// Same-category options force an actual choice.
  ///
  /// Tops up from the wider pool if a category cannot supply enough (custom
  /// or trimmed decks), so a quiz always has four options.
  static List<String> distractorsFor(Flashcard card, {int count = 3}) {
    bool usable(Flashcard c) =>
        c.id != card.id && c.wordFilipino != card.wordFilipino;

    final picked = <String>{};
    for (final pool in [
      SeedData.getByCategory(card.category),
      SeedData.allFlashcards,
    ]) {
      final candidates = pool.where(usable).map((c) => c.wordFilipino).toSet()
        ..removeAll(picked);
      final shuffled = candidates.toList()..shuffle(_random);
      for (final word in shuffled) {
        if (picked.length >= count) break;
        picked.add(word);
      }
      if (picked.length >= count) break;
    }
    return picked.toList();
  }

  static TutorMessage quizForWord(Flashcard card,
      {bool isFilipino = false, String? prefix}) {
    final options = [card.wordFilipino, ...distractorsFor(card)]
      ..shuffle(_random);

    final head = prefix ?? (isFilipino ? '❓ Mabilisang Quiz!' : '❓ Quick Quiz!');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '$head\n\nAno ang Filipino ng "${card.wordEnglish}"?'
          : '$head\n\nWhat is the Filipino for "${card.wordEnglish}"?',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.quickQuiz,
        question: card.wordEnglish,
        options: options,
        correctAnswer: card.wordFilipino,
        wordId: card.id,
        categoryLabel: card.category.label,
      ),
    );
  }

  /// Picks today's personalized learning plan — 3 flashcards prioritized by the
  /// learner's spaced-repetition data (weakest / least-recently-seen first),
  /// falling back to unseen words. Reuses [SpacedRepetitionService.getReviewWords].
  ///
  /// With [interests]: weakness still wins (slots keep SR priority order), but
  /// if no plan word comes from a favorite topic, the *last* (lowest-priority)
  /// slot is swapped for a word from the strongest interest, so every lesson
  /// has something the learner loves without hiding what they struggle with.
  static List<Flashcard> buildLearningPlan(
    LearningProgress progress,
    String profileId, {
    int count = 3,
    List<FlashcardCategory> interests = const [],
  }) {
    final allCards = SeedData.allFlashcards;
    if (allCards.isEmpty) return const [];
    final plan = SpacedRepetitionService.getReviewWords(
      profileId: profileId,
      allCards: allCards,
      count: count,
    );
    if (interests.isEmpty ||
        plan.isEmpty ||
        plan.any((c) => interests.contains(c.category))) {
      return plan;
    }
    for (final cat in interests) {
      final candidates = SeedData.getByCategory(cat)
          .where((c) => plan.every((p) => p.id != c.id))
          .toList();
      if (candidates.isNotEmpty) {
        final pick = candidates[_random.nextInt(candidates.length)];
        return [...plan.sublist(0, plan.length - 1), pick];
      }
    }
    return plan;
  }

  /// A message that invites the learner to start today's learning plan. The
  /// [TutorActionType.startLesson] action carries the chosen [planWordIds].
  static TutorMessage offerLearningPlan(
    LearningProgress progress,
    String profileId, {
    bool isFilipino = false,
    List<FlashcardCategory> interests = const [],
    bool simple = false,
  }) {
    final plan = buildLearningPlan(progress, profileId, interests: interests);
    if (plan.isEmpty) {
      return _wordOfTheDay(isFilipino: isFilipino, interests: interests);
    }
    final preview = plan.map((c) => c.wordEnglish).join(', ');
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: simple
          ? (isFilipino
              ? '🎯 Matuto tayo ng ${plan.length} salita: $preview.\n\nPindutin ang button para magsimula. May bituin ka! ⭐'
              : '🎯 Let\'s learn ${plan.length} words: $preview.\n\nTap the button to start. You get stars! ⭐')
          : isFilipino
          ? '🎯 Handa na ang iyong aralin ngayon! Mag-aaral tayo ng ${plan.length} salita: $preview.\n\nPindutin sa ibaba para magsimula — may bituin kang makukuha!'
          : '🎯 Today\'s lesson is ready! We\'ll practice ${plan.length} words: $preview.\n\nTap below to start — you\'ll earn stars!',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.startLesson,
        planWordIds: plan.map((c) => c.id).toList(),
      ),
    );
  }

  static TutorMessage _suggestPractice(LearningProgress progress,
      {bool isFilipino = false}) {
    // Find the weakest category to suggest
    String? weakest;
    double minProg = 2.0;
    for (final entry in progress.categoryProgress.entries) {
      if (entry.value < minProg) {
        minProg = entry.value;
        weakest = entry.key;
      }
    }

    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📝 ${weakest != null ? 'Irekomenda ko ang practice sa "$weakest".' : 'Subukan ang Guided Practice para sa anumang kategorya!'} Pindutin ang button sa ibaba para magsimula.'
          : '📝 ${weakest != null ? 'I recommend practicing "$weakest".' : 'Try Guided Practice for any category!'} Tap the button below to start.',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.practiceRedirect,
        targetRoute: '/guided-practice',
      ),
    );
  }

  static TutorMessage _progressSummary(LearningProgress progress,
      {bool isFilipino = false, bool simple = false}) {
    if (simple) {
      final words = progress.wordsLearned;
      final days = progress.streakDays;
      return TutorMessage(
        id: _uuid.v4(),
        role: TutorMessageRole.tutor,
        content: isFilipino
            ? '📊 Tingnan ang nagawa mo!\n\n'
                '📖 ${words == 1 ? '1 salita' : '$words na salita'} ang alam mo\n'
                '⭐ ${progress.totalStars} bituin\n'
                '🔥 ${days == 1 ? '1 araw' : '$days na araw'} sunod-sunod\n\n'
                'Ang galing mo! 🎉'
            : '📊 Look what you did!\n\n'
                '📖 You know $words ${words == 1 ? 'word' : 'words'}\n'
                '⭐ You have ${progress.totalStars} stars\n'
                '🔥 $days ${days == 1 ? 'day' : 'days'} in a row\n\n'
                'Great job! 🎉',
        timestamp: DateTime.now(),
      );
    }
    return TutorMessage(
      id: _uuid.v4(),
      role: TutorMessageRole.tutor,
      content: isFilipino
          ? '📊 Ito ang iyong progress:\n\n📖 ${progress.wordsLearned} salita ang natutunan\n⭐ ${progress.totalStars} bituin\n🔥 ${progress.streakDays}-araw na streak\n🎮 ${progress.recentScores.length} laro na nilaro\n\nItuloy mo lang ang magandang gawa!'
          : '📊 Here\'s your progress:\n\n📖 ${progress.wordsLearned} words learned\n⭐ ${progress.totalStars} stars earned\n🔥 ${progress.streakDays}-day streak\n🎮 ${progress.recentScores.length} games played\n\nKeep up the great work!',
      timestamp: DateTime.now(),
    );
  }
}
