import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/accessibility/spoken_words.dart';
import '../../../data/local/seed_data.dart';
import '../../../data/local/seed_stories.dart';
import '../../live_session/models/live_session_models.dart';
import '../models/tv_cast_session.dart';

/// One line the TV says: the words and the language they are in (`en` or
/// `fil`), which picks the voice.
class CastSpeechLine {
  const CastSpeechLine(this.text, this.lang);

  final String text;

  /// `en` or `fil`.
  final String lang;

  @override
  bool operator ==(Object other) =>
      other is CastSpeechLine && other.text == text && other.lang == lang;

  @override
  int get hashCode => Object.hash(text, lang);

  @override
  String toString() => 'CastSpeechLine($lang: $text)';
}

/// The spoken form of a live question: the instruction (or the educator's own
/// prompt), then the lettered choices, so a learner can answer by ear. The
/// correct answer is never part of it.
///
/// In the app's language ([filipino]): an activity is authored once by the
/// educator, so only the instruction lines have a second language. Kept word
/// for word in step with `liveSpeechText` in `assets/tv_cast/app.js`, which
/// the TV still uses when it has to speak on its own.
String castLiveSpeechText(LiveActivity activity, {required bool filipino}) {
  final parts = <String>[];
  switch (activity.type) {
    case LiveActivityType.fslSign:
      parts.add(
        filipino
            ? 'Panoorin ang senyas, saka piliin ang salita.'
            : 'Watch the sign, then pick the word.',
      );
    case LiveActivityType.pictureChoice:
      parts.add(
        filipino
            ? 'Aling salita ang tugma sa larawan?'
            : 'Which word matches the picture?',
      );
    default:
      final prompt = activity.prompt;
      if (prompt.trim().isNotEmpty) parts.add(prompt);
  }
  if (activity.type == LiveActivityType.trueFalse) {
    parts.add(filipino ? 'Tama, o mali?' : 'True, or false?');
  } else {
    final options = activity.options;
    for (var i = 0; i < options.length; i++) {
      parts.add('${String.fromCharCode(65 + i)}. ${options[i]}');
    }
  }
  return parts.join(' ');
}

/// What the TV says for the item on screen, in order (English first, the way
/// the cast has always read a word). Empty for modes that say nothing: the
/// FSL signs, the progress board, idle, a story showing its sign clip or its
/// closing screen.
///
/// The "Language on TV" filter governs speech as well as what is shown —
/// hearing a language the TV isn't displaying is worse than silence. A live
/// question is spoken in the app's language ([uiFilipino]).
///
/// Pure (seed data only), so the server and the notifier build the identical
/// list: the server to hand the TV its audio links, the notifier to have the
/// audio made before the TV asks.
List<CastSpeechLine> castSpeechLinesFor(
  TvCastSession s, {
  required bool uiFilipino,
}) {
  final lines = <CastSpeechLine>[];
  void add(String text, String lang) {
    final clean = SpokenWords.withoutPictures(text).trim();
    if (clean.isEmpty) return;
    if (lang == 'en' && s.castLanguage == CastLanguage.filipino) return;
    if (lang == 'fil' && s.castLanguage == CastLanguage.english) return;
    lines.add(CastSpeechLine(clean, lang));
  }

  switch (s.mode) {
    case CastMode.flashcards:
      final cat = s.category;
      if (cat == null) break;
      final cards = SeedData.getByCategory(cat);
      if (cards.isEmpty) break;
      final card = cards[s.slideIndex % cards.length];
      add(card.wordEnglish, 'en');
      add(card.wordFilipino, 'fil');
    case CastMode.story:
      if (s.storyFinished || s.storyFslActive) break;
      final id = s.storyId;
      if (id == null) break;
      final story = SeedStories.all.where((st) => st.id == id).firstOrNull;
      if (story == null || story.sentencesEn.isEmpty) break;
      final i = s.storyPageIndex.clamp(0, story.sentencesEn.length - 1);
      add(story.sentencesEn[i], 'en');
      if (i < story.sentencesFil.length) add(story.sentencesFil[i], 'fil');
    case CastMode.live:
      final activity = s.liveActivity;
      if (activity == null) break;
      final text = castLiveSpeechText(activity, filipino: uiFilipino);
      final clean = SpokenWords.withoutPictures(text).trim();
      if (clean.isNotEmpty) {
        lines.add(CastSpeechLine(clean, uiFilipino ? 'fil' : 'en'));
      }
    case CastMode.fslVideo:
    case CastMode.progress:
    case CastMode.idle:
      break;
  }
  return lines;
}

/// "Time's up!" for the lesson timer, in the app's language — the same words
/// the TV shows on its clock.
CastSpeechLine castTimesUpLine({required bool uiFilipino}) => uiFilipino
    ? const CastSpeechLine('Tapos na ang oras!', 'fil')
    : const CastSpeechLine("Time's up!", 'en');

/// Identifies what is being said, so the TV speaks each item once: a new
/// card, page or question gets a new key; the same one polled again does not.
String castSpeechKeyFor(TvCastSession s) => switch (s.mode) {
  CastMode.flashcards => 'f:${s.category?.index}:${s.slideIndex}',
  CastMode.story =>
    's:${s.storyId}:${s.storyPageIndex}${s.storyFinished ? ':end' : ''}',
  CastMode.live => 'l:${s.liveActivity?.id ?? ''}',
  _ => '',
};

/// Writes [text] as a WAV file at [path] in [lang] (`en` / `fil`) at the
/// speech engine's [rate] (1.0 = normal). True once the file is complete.
typedef CastSpeechSynthesizer =
    Future<bool> Function(String text, String lang, double rate, String path);

/// Makes the TV's spoken words as **audio files on the phone**, which the TV
/// then plays through its own speakers with a plain `<audio>` element.
///
/// The cast used to rely on the TV browser's Web Speech API alone. Most TV
/// browsers don't have one that works — Android TV / Google TV browsers run on
/// a WebView with no `speechSynthesis` at all, and many Tizen / webOS builds
/// have the object but no voices, so `speak()` silently does nothing. Every
/// one of them plays a WAV. So the phone, which has a real speech engine (and
/// the Filipino voice the app already uses), renders each line to a file and
/// the server hands the TV a link to it. The TV falls back to its own Web
/// Speech only when a file can't be made.
///
/// Lines are registered by the server as it builds `/api/state`; only a
/// registered id can be fetched, so a TV can never make the phone say
/// arbitrary text. Files are named by a hash of (language, rate, text) and
/// kept a few days, so a word the class hears every lesson is made once.
class TvCastSpeech {
  TvCastSpeech({
    double Function()? engineRate,
    CastSpeechSynthesizer? synthesizer,
    Future<Directory> Function()? cacheDir,
  }) : _engineRate = engineRate ?? (() => 1.0),
       _synthesizer = synthesizer ?? _nativeSynthesize,
       _cacheDir = cacheDir ?? _defaultCacheDir;

  static const _channel = MethodChannel('flashlearn/cast_speech');

  /// How many registered lines are remembered. A lesson's current and next
  /// item each register up to two lines per poll; this is hours of lesson.
  static const _maxLines = 256;

  /// A synthesis that never reports back is given up on after this, and the
  /// TV falls back to its own speech for that line.
  static const synthTimeout = Duration(seconds: 15);

  final double Function() _engineRate;
  final CastSpeechSynthesizer _synthesizer;
  final Future<Directory> Function() _cacheDir;

  final Map<String, ({CastSpeechLine line, double rate})> _lines = {};
  final Map<String, Future<File?>> _files = {};
  Directory? _dir;

  /// The speech engine's rate, which follows the app's own speech-speed
  /// setting, so the TV's voice runs at the pace the learner is used to.
  double get _rate {
    final r = _engineRate();
    return r.isFinite && r > 0 ? r.clamp(0.2, 4.0).toDouble() : 1.0;
  }

  /// The id a [line] is (or would be) served under at the current rate.
  String idFor(CastSpeechLine line) => _id(line, _rate);

  static String _id(CastSpeechLine line, double rate) => sha1
      .convert(utf8.encode('v1|${line.lang}|${rate.toStringAsFixed(2)}|${line.text}'))
      .toString()
      .substring(0, 24);

  /// Makes [line] fetchable and returns its id.
  String register(CastSpeechLine line) {
    final rate = _rate;
    final id = _id(line, rate);
    _lines.remove(id);
    _lines[id] = (line: line, rate: rate);
    while (_lines.length > _maxLines) {
      final oldest = _lines.keys.first;
      _lines.remove(oldest);
      _files.remove(oldest);
    }
    return id;
  }

  /// Whether [id] was registered (and so may be served).
  bool knows(String id) => _lines.containsKey(id);

  /// The WAV for a registered [id], made on first request, or null when it is
  /// unknown or the phone could not make it.
  Future<File?> fileFor(String id) {
    final entry = _lines[id];
    if (entry == null) return Future.value();
    final inFlight = _files[id];
    if (inFlight != null) return inFlight;
    final made = _make(id, entry.line, entry.rate).then((file) {
      // Forget a failure so a later request can try again.
      if (file == null) _files.remove(id);
      return file;
    });
    _files[id] = made;
    return made;
  }

  /// Registers [lines] and starts making their audio now, so it is ready
  /// before the TV asks. Fire-and-forget.
  void prefetch(Iterable<CastSpeechLine> lines) {
    for (final line in lines) {
      unawaited(fileFor(register(line)));
    }
  }

  Future<File?> _make(String id, CastSpeechLine line, double rate) async {
    try {
      final dir = _dir ??= await _cacheDir();
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}$id.wav');
      if (await _isWav(file)) return file;
      final ok = await _synthesizer(line.text, line.lang, rate, file.path)
          .timeout(synthTimeout, onTimeout: () => false);
      if (ok && await _isWav(file)) return file;
      debugPrint('TvCastSpeech: no audio made (${line.lang})');
      return null;
    } catch (e) {
      debugPrint('TvCastSpeech: audio failed (${line.lang}): $e');
      return null;
    }
  }

  /// A complete WAV: the RIFF header and at least some sound after it.
  static Future<bool> _isWav(File file) async {
    try {
      if (!await file.exists()) return false;
      if (await file.length() <= 44) return false;
      final raf = await file.open();
      try {
        final head = await raf.read(4);
        return head.length == 4 &&
            head[0] == 0x52 && // R
            head[1] == 0x49 && // I
            head[2] == 0x46 && // F
            head[3] == 0x46; // F
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Deletes audio files older than [maxAge] — a few days of lessons stay
  /// warm, nothing grows without bound. Best-effort.
  Future<void> prune({Duration maxAge = const Duration(days: 3)}) async {
    try {
      final dir = _dir ??= await _cacheDir();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        try {
          if ((await entity.lastModified()).isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  static Future<Directory> _defaultCacheDir() async {
    final tmp = await getTemporaryDirectory();
    return Directory('${tmp.path}${Platform.pathSeparator}cast_speech');
  }

  /// Android: a speech engine of the cast's own (CastSpeech.kt), separate
  /// from the one the app speaks with, so making a file never cuts off — or
  /// is cut off by — anything the app is saying. Elsewhere: no files, and
  /// the TV speaks with its own voice.
  static Future<bool> _nativeSynthesize(
    String text,
    String lang,
    double rate,
    String path,
  ) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('synthesize', {
        'text': text,
        'lang': lang,
        'rate': rate,
        'path': path,
      });
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException catch (e) {
      debugPrint('TvCastSpeech: engine refused ($lang): ${e.code}');
      return false;
    }
  }

  /// Lets the cast's speech engine go when the cast stops.
  static Future<void> release() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('release');
    } catch (_) {}
  }
}
