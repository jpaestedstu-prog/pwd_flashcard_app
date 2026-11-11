import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'spoken_words_web.dart'
    if (dart.library.io) 'spoken_words_native.dart';

/// What a voice is told, without the pictures in it.
///
/// A speech engine reads an emoji by its name. TalkBack said "Welcome Back!
/// waving hand", "Stories, open book" and "Great Job! party popper" (found on
/// the tablet, 29 Oct): about a hundred of the app's titles and messages carry
/// one for the eye. Messages already dropped theirs before being read aloud
/// ("sparkles", "flexed biceps"); this does the same for everything a screen
/// reader is sent ([SpokenWordsBinding]) and everything the app says itself.
abstract final class SpokenWords {
  /// Whether [rune] is a pictograph, or the joiner, variation selector or
  /// keycap that makes one up.
  ///
  /// ⭐ is not: the app counts in stars, and its strings use it as the word
  /// ("+1 ⭐", "You earned 3 ⭐"), which a screen reader says as "star".
  static bool isPicture(int rune) =>
      rune != 0x2B50 &&
      ((rune >= 0x1F000 && rune <= 0x1FAFF) || // emoji, flags, skin tones
          (rune >= 0x2600 && rune <= 0x27BF) || // symbols & dingbats
          (rune >= 0x2B00 && rune <= 0x2BFF) || // stars, arrows
          (rune >= 0x2190 && rune <= 0x21FF) || // arrows
          (rune >= 0x2300 && rune <= 0x23FF) || // clocks, hourglasses
          rune == 0x200D || // zero-width joiner
          (rune >= 0xFE00 && rune <= 0xFE0F) || // variation selectors
          rune == 0x20E3); // keycap

  /// [text] with its pictures removed and the spacing they leave tidied —
  /// even when nothing is left.
  static String strip(String text) {
    var changed = false;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (isPicture(rune)) {
        changed = true;
      } else {
        buffer.writeCharCode(rune);
      }
    }
    if (!changed) return text;
    return buffer
        .toString()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' ?\n ?'), '\n')
        .trim();
  }

  /// [text] as a voice should say it: its pictures removed, unless they are
  /// all it has to say (a sticker, an emoji-only reaction) — then it is left
  /// as it is, so a screen reader still names it.
  static String withoutPictures(String text) {
    final spoken = strip(text);
    if (identical(spoken, text)) return text;
    return _hasWords.hasMatch(spoken) ? spoken : text;
  }

  /// What a stop says when [actions] is all it can do: [text] without its
  /// pictures, and nothing at all when it is only a picture with nothing to
  /// press.
  ///
  /// A "🎉" over a result, or a "🌟" in an empty list, is there for the eye,
  /// and a screen reader made it a stop of its own: "party popper", "glowing
  /// star". (TalkBack said "open book" on Guided Practice, 4 Nov.) With no
  /// words and no action it is no stop at all. A picture that can be pressed
  /// keeps its name, a sticker or a reaction having no other.
  static String forStop(String text, int actions) {
    final spoken = withoutPictures(text);
    return actions == 0 && text.isNotEmpty && strip(text).isEmpty ? '' : spoken;
  }

  static final RegExp _hasWords = RegExp(r'[\p{L}\p{N}]', unicode: true);

  /// The language the app's words are in when it is set to Filipino, as a
  /// screen reader is told it.
  ///
  /// TalkBack reads in the tablet's own language unless a word says
  /// otherwise. On a tablet set to English, every Filipino label was read
  /// with the English voice ("Mga Laro" as English letters); marked as
  /// Filipino, TalkBack switches to its Filipino voice for it, where one is
  /// installed (and stays in its own where none is). The language alone, no
  /// country: a browser is handed it as written, and "fil_PH" (Flutter's
  /// spelling) is no language a browser or its reader knows.
  static const ui.Locale filipino = ui.Locale('fil');

  /// The English the app teaches, as a screen reader is told it.
  static const ui.Locale english = ui.Locale('en');

  /// The English the app teaches: every card's English word and sentence,
  /// lower case and without their punctuation. Set by the app as its cards
  /// load ([learnVocabulary]).
  static Set<String> englishVocabulary = const {};

  /// A card's word, spelled as the card spells it, inside a longer label.
  static RegExp? _wordInLabel;

  /// Takes in the cards' English [words] and [sentences].
  static void learnVocabulary(
    Iterable<String> words,
    Iterable<String> sentences,
  ) {
    englishVocabulary = {
      for (final w in words) vocabularyKey(w),
      for (final s in sentences) vocabularyKey(s),
    };
    // Longest first, so "Ice Cream" is found whole. Spelled as on the card,
    // capital and all, so that a Filipino word is not taken for an English
    // one by its letters (checked against the whole Filipino translation:
    // the only such words in it are English ones, "Phone", "Teacher").
    final spelled = {
      for (final w in words)
        if (w.trim().length >= 2) w.trim(),
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _wordInLabel = spelled.isEmpty
        ? null
        : RegExp(
            r'(?<![\p{L}\p{N}])(?:' +
                spelled.map(RegExp.escape).join('|') +
                r')(?![\p{L}\p{N}])',
            unicode: true,
          );
  }

  /// The English words a Filipino [label] has inside it, each marked English:
  /// a flashcard says "One, kategoryang Mga Numero. Pindutin…", and "One" is
  /// the word being learned.
  static List<ui.StringAttribute> englishWordsIn(String label) {
    final pattern = _wordInLabel;
    if (pattern == null || label.isEmpty) return const [];
    return [
      for (final m in pattern.allMatches(label))
        ui.LocaleStringAttribute(
          range: ui.TextRange(start: m.start, end: m.end),
          locale: english,
        ),
    ];
  }

  /// [words] as a key of [englishVocabulary].
  static String vocabularyKey(String words) => strip(words)
      .toLowerCase()
      .replaceAll(_notWordOrSpace, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static final RegExp _notWordOrSpace = RegExp(r'[^\p{L}\p{N} ]', unicode: true);

  /// The language a screen reader should read [label] in, when the screen
  /// around it is in [around]: a vocabulary word stays English on a Filipino
  /// screen — a card's "Butterfly", an answer's "Chair", or a word and its
  /// sentence, one under the other ("Rainy / It is rainy outside.") — so it
  /// is read the way the learner is learning to say it.
  static ui.Locale? localeFor(String label, ui.Locale? around) {
    if (around == null || around.languageCode != filipino.languageCode) {
      return around;
    }
    if (englishVocabulary.isEmpty || label.isEmpty) return around;
    final lines = label.split('\n').map(vocabularyKey).where((l) => l.isNotEmpty);
    return lines.isNotEmpty && lines.every(englishVocabulary.contains)
        ? english
        : around;
  }

  /// Whether [text] reads as Filipino rather than English, for speech that
  /// comes without its language: a teacher's question in a live session, a
  /// picture's description in a test. Told by the small words neither
  /// language can do without ("ang", "ng", "mga" against "the", "is", "of");
  /// when they do not decide it (one word, a name), [otherwise]: the app's
  /// own language.
  ///
  /// Such speech was read in whichever voice the engine had used last, so a
  /// teacher's "Ano ang kulay ng langit?" could come out in the English one.
  static bool looksFilipino(String text, {required bool otherwise}) {
    var filipinoWords = 0;
    var englishWords = 0;
    for (final word in vocabularyKey(text).split(' ')) {
      if (_filipinoMarkers.contains(word)) filipinoWords++;
      if (_englishMarkers.contains(word)) englishWords++;
    }
    if (filipinoWords != englishWords) return filipinoWords > englishWords;
    return otherwise;
  }

  // Words only one of the two languages uses. "at" and "may" are both
  // Filipino and English, so neither counts.
  static const _filipinoMarkers = {
    'ang', 'ng', 'mga', 'sa', 'ay', 'ko', 'mo', 'niya', 'nila', 'natin',
    'namin', 'ninyo', 'si', 'ni', 'kay', 'ka', 'ikaw', 'ako', 'siya', 'kami',
    'tayo', 'kayo', 'sila', 'ito', 'iyan', 'iyon', 'dito', 'diyan', 'doon',
    'ano', 'sino', 'saan', 'kailan', 'bakit', 'paano', 'ilan', 'alin',
    'hindi', 'huwag', 'oo', 'po', 'opo', 'ba', 'din', 'rin', 'lang',
    'lamang', 'naman', 'pa', 'na', 'nang', 'para', 'kung', 'wala', 'mayroon',
    'meron', 'kasi', 'pero', 'kanino', 'ating', 'aking', 'iyong', 'kanyang',
  };

  static const _englishMarkers = {
    'the', 'is', 'are', 'was', 'were', 'a', 'an', 'of', 'to', 'and', 'in',
    'on', 'it', 'this', 'that', 'these', 'those', 'what', 'where', 'who',
    'which', 'how', 'why', 'when', 'you', 'your', 'i', 'my', 'we', 'our',
    'they', 'their', 'he', 'she', 'his', 'her', 'do', 'does', 'did', 'not',
    'with', 'for', 'from', 'can', 'will', 'have', 'has', 'be', 'there',
  };
}

/// The app's binding: [WidgetsFlutterBinding], with every label, hint and
/// tooltip sent to the platform's screen reader passed through
/// [SpokenWords.withoutPictures].
///
/// Flutter builds each update for TalkBack through
/// [createSemanticsUpdateBuilder], so this one place reaches every Text,
/// button and pop-up, present and future. Values are left alone: a text
/// field's value is what the learner typed, and its selection counts its
/// characters. A browser's builder takes other types, so it has its own
/// wrapper (`spoken_words_web.dart`).
class SpokenWordsBinding extends WidgetsFlutterBinding {
  /// The binding: this one, unless one was made first — the integration
  /// test's, which `main()` then keeps.
  static WidgetsBinding ensureInitialized() {
    // Set by every SemanticsBinding as it starts, in every build mode.
    if (ui.PlatformDispatcher.instance.onSemanticsActionEvent == null) {
      SpokenWordsBinding();
    }
    return WidgetsBinding.instance;
  }

  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      spokenWordsBuilder(super.createSemanticsUpdateBuilder());
}
