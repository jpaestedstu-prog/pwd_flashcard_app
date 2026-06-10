import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/fsl_assets_service.dart';
import '../models/sign_interpreter_models.dart';

/// Maps free text (an STT transcript or a typed sentence) onto the FSL video
/// vocabulary, producing an ordered playlist of [SignPlayItem]s.
///
/// Pure Dart over an in-memory index — safe to unit test without Flutter.
/// Matching is content-word based ("gloss"), as sign languages drop most
/// function words: vocabulary lookups run FIRST, then non-vocabulary
/// stopwords are silently skipped, and anything left over surfaces as an
/// unmatched item (the unmatched list is itself a research signal for which
/// signs to record next).
class SignGlossService {
  /// Normalized phrase → entry. Keys may contain spaces ("thank you").
  final Map<String, FslManifestEntry> _index = {};

  /// Longest indexed phrase, in words — bounds the greedy matcher.
  int _maxPhraseWords = 1;

  SignGlossService(List<FslManifestEntry> entries) {
    for (final entry in entries) {
      _addKey(entry.wordEnglish, entry);
      _addKey(entry.wordFilipino, entry);
      // Slugs use '-'/'_' as separators ("thank-you") — index the spaced form.
      _addKey(entry.slug.replaceAll(RegExp(r'[-_]+'), ' '), entry);

      // Number entries: STT usually transcribes digits ("3", not "three"),
      // so index the digit form alongside the word form.
      final digit = _numberWordToDigit[_normalize(entry.wordEnglish)];
      if (digit != null) _addKey(digit, entry);
    }
  }

  /// First entry wins on collisions (e.g. "chicken" exists in both Animals
  /// and Food & Drinks) — manifest order decides.
  void _addKey(String raw, FslManifestEntry entry) {
    final key = _normalize(raw);
    if (key.isEmpty) return;
    _index.putIfAbsent(key, () => entry);
    final words = key.split(' ').length;
    if (words > _maxPhraseWords) _maxPhraseWords = words;
  }

  /// Number of distinct lookup keys (diagnostic / tests).
  int get indexSize => _index.length;

  /// Glosses [text] into an ordered playlist. Function words that aren't in
  /// the vocabulary are dropped; unknown content words come back as
  /// unmatched items so the UI can show "no sign yet" placeholders.
  List<SignPlayItem> glossify(String text) {
    final tokens = _normalize(text)
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    final items = <SignPlayItem>[];
    var i = 0;
    while (i < tokens.length) {
      // Greedy longest-phrase match so "thank you" beats "you".
      FslManifestEntry? match;
      var consumed = 1;
      final maxLen =
          _maxPhraseWords < tokens.length - i ? _maxPhraseWords : tokens.length - i;
      for (var len = maxLen; len >= 1; len--) {
        final phrase = tokens.sublist(i, i + len).join(' ');
        final found = _lookup(phrase, allowVariants: len == 1);
        if (found != null) {
          match = found;
          consumed = len;
          break;
        }
      }

      if (match != null) {
        items.add(SignPlayItem.matched(match));
      } else if (!_isStopword(tokens[i])) {
        items.add(SignPlayItem.unmatched(tokens[i]));
      }
      i += consumed;
    }
    return items;
  }

  FslManifestEntry? _lookup(String key, {required bool allowVariants}) {
    final direct = _index[key];
    if (direct != null) return direct;
    if (!allowVariants) return null;

    // Plural → singular ("dogs" → "dog", "dresses" → "dress").
    if (key.length > 3 && key.endsWith('es')) {
      final stripped = _index[key.substring(0, key.length - 2)];
      if (stripped != null) return stripped;
    }
    if (key.length > 2 && key.endsWith('s')) {
      final stripped = _index[key.substring(0, key.length - 1)];
      if (stripped != null) return stripped;
    }

    // Digit → number word ("3" → "three") for digits not indexed directly.
    final word = _digitToNumberWord[key];
    if (word != null) return _index[word];

    return null;
  }

  bool _isStopword(String token) =>
      _englishStopwords.contains(token) || _filipinoStopwords.contains(token);

  /// Lowercases and strips everything but letters, digits, apostrophes and
  /// spaces; collapses whitespace. Hyphens become spaces so "thank-you"
  /// tokenizes like "thank you".
  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r"[^a-z0-9'áàâéèêíìîóòôúùûñ\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const Map<String, String> _numberWordToDigit = {
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'twenty': '20',
    'hundred': '100',
  };

  static final Map<String, String> _digitToNumberWord = {
    for (final e in _numberWordToDigit.entries) e.value: e.key,
  };

  /// Function words dropped from English glosses. Vocabulary lookups run
  /// before this check, so a word that is both a stopword and vocabulary
  /// still matches its sign.
  static const Set<String> _englishStopwords = {
    'a', 'an', 'the', 'is', 'am', 'are', 'was', 'were', 'be', 'been', 'being',
    'do', 'does', 'did', 'have', 'has', 'had', 'will', 'would', 'can',
    'could', 'shall', 'should', 'may', 'might', 'must',
    'i', 'me', 'my', 'mine', 'you', 'your', 'yours', 'he', 'him', 'his',
    'she', 'her', 'hers', 'it', 'its', 'we', 'us', 'our', 'ours', 'they',
    'them', 'their', 'theirs', 'this', 'that', 'these', 'those',
    'to', 'of', 'in', 'on', 'at', 'by', 'for', 'with', 'from', 'about',
    'into', 'onto', 'up', 'down', 'out', 'off', 'over', 'under',
    'and', 'or', 'but', 'so', 'if', 'then', 'than', 'as', 'not', 'no',
    'very', 'too', 'also', 'just', 'there', 'here', 'what', 'which', 'who',
    'when', 'where', 'why', 'how', 'all', 'some', 'any',
    "i'm", "it's", "don't", "doesn't", "can't", "won't", "let's",
    'please', 'want', 'wants', 'like', 'likes', 'go', 'going', 'get', 'got',
  };

  /// Filipino function words/particles dropped from glosses.
  static const Set<String> _filipinoStopwords = {
    'ang', 'mga', 'ng', 'nang', 'sa', 'ay', 'na', 'at', 'si', 'ni', 'kay',
    'ko', 'mo', 'niya', 'namin', 'natin', 'ninyo', 'nila', 'akin', 'iyo',
    'kanya', 'amin', 'atin', 'inyo', 'kanila',
    'ako', 'ikaw', 'ka', 'siya', 'kami', 'tayo', 'kayo', 'sila',
    'ito', 'iyan', 'iyon', 'dito', 'diyan', 'doon',
    'po', 'opo', 'ho', 'ba', 'raw', 'daw', 'pa', 'naman', 'lang', 'lamang',
    'din', 'rin', 'man', 'nga', 'pala', 'kasi', 'dahil', 'kung', 'para',
    'pero', 'o', 'hindi', 'wala', 'may', 'mayroon', 'meron',
    'gusto', 'ayaw', 'nais', 'punta', 'pumunta', 'kumuha',
  };
}

/// Loads the manifest once and builds the gloss index. Watch this from the
/// interpreter screen; it resolves fast (asset parse only, no network).
final signGlossServiceProvider = FutureProvider<SignGlossService>((ref) async {
  final entries = await FslAssetsService.manifestEntries();
  return SignGlossService(entries);
});
