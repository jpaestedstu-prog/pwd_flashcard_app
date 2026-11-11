import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../utils/input_trace.dart';
import 'spoken_words.dart';

/// Text-to-Speech service with bilingual support (English + Filipino)
class TtsService {
  TtsService() {
    // One set of engine callbacks, fanned out: [speaking] for whatever paces
    // itself by the speech, and the single [setCompletionHandler] callback TV
    // Cast chains its second language on. A cancel or an error ends the
    // speech too, but only a natural finish runs that callback — exactly what
    // the engine's own completion handler did.
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() {
      _setSpeaking(false);
      _completionHandler?.call();
    });
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));
  }

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;

  /// Whether the speech engine is talking right now — app-wide, since the
  /// device has one engine whichever service instance started the speech.
  /// Spoken scanning waits on it, so a long name is heard to the end before
  /// the highlight moves on.
  static final ValueNotifier<bool> speaking = ValueNotifier(false);

  /// Counts every request to speak, app-wide. The "sound is off" hint checks
  /// the device's volume on each one, the moment it would matter.
  static final ValueNotifier<int> requests = ValueNotifier(0);

  static void Function()? _completionHandler;

  static void _setSpeaking(bool value) {
    if (speaking.value != value) speaking.value = value;
  }

  /// The engine's language. App-wide, like [speaking]: every instance of the
  /// service drives the one engine the device has, and a new instance (the
  /// provider makes one on each change of settings) found the engine in the
  /// language the last one left it in.
  static String _currentLanguage = 'en-US';

  /// The voices a Filipino request tries, in order: engines name it "fil-PH",
  /// "fil" or, older ones, by Tagalog.
  static const filipinoTags = ['fil-PH', 'fil', 'tl-PH'];

  /// Counts the Filipino requests that found no Filipino voice on the device,
  /// so their words came out in the English one. The note that says so
  /// listens ([FilipinoVoiceHintHost]).
  static final ValueNotifier<int> filipinoVoiceMissing = ValueNotifier(0);

  /// Whether the app is in Filipino: the language for speech that does not
  /// show its own ([speak]). Kept up to date by [ttsServiceProvider].
  bool appFilipino = false;

  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {
    if (_isInitialized) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await _useIosPlaybackSession();
    }
    await _engine(() => _tts.setLanguage('en-US'));
    _currentLanguage = 'en-US';
    await _engine(() => _tts.setSpeechRate(speed));
    await _engine(() => _tts.setPitch(pitch));
    await _engine(() => _tts.setVolume(1.0));
    _isInitialized = true;
  }

  /// One call to the engine. Speech is an extra channel: an engine that is
  /// missing or fails (a device without a speech service, a test without
  /// one) must never take a screen down with it. Settings closing threw
  /// "MissingPluginException" from the engine's stop once the screen started
  /// asking it about voices.
  Future<void> _engine(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (e) {
      if (kDebugMode) debugPrint('TtsService: engine call failed: $e');
    }
  }

  /// iOS speaks in its default audio session, which the Ring/Silent switch
  /// mutes: on an iPhone with the switch on, a learner who depends on hearing
  /// the word would hear nothing, and nothing on screen would say why.
  /// "Playback" is the session for sound the user asked for and ignores the
  /// switch; mixing leaves other sound (a parent's music, the class TV) on —
  /// the same session the app's sound effects already use (audioplayers'
  /// default). Best-effort: a failure keeps the engine's default.
  Future<void> _useIosPlaybackSession() async {
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [IosTextToSpeechAudioCategoryOptions.mixWithOthers],
      );
    } catch (e) {
      if (kDebugMode) debugPrint('TtsService: iOS audio session not set: $e');
    }
  }

  /// Speak [text] in the language it is written in: Filipino when it reads
  /// as Filipino ([SpokenWords.looksFilipino]; the app's language when it
  /// cannot be told), English otherwise.
  ///
  /// It used to speak in whatever language the engine was last set to, so a
  /// Filipino question could come out in the English voice, and an English
  /// word in the Filipino one, depending on what had been said before. Text
  /// whose language is known goes to [speakIn], [speakEnglish] or
  /// [speakFilipino] instead.
  Future<void> speak(String text) =>
      SpokenWords.looksFilipino(text, otherwise: appFilipino)
          ? speakFilipino(text)
          : speakEnglish(text);

  /// Speak [text], written in Filipino when [filipino], else in English.
  Future<void> speakIn(String text, {required bool filipino}) =>
      filipino ? speakFilipino(text) : speakEnglish(text);

  /// Whether the device has a Filipino voice: true or false, or null when it
  /// cannot be told (a browser that has not listed its voices yet, a test).
  Future<bool?> hasFilipinoVoice() async {
    try {
      final languages = await _tts.getLanguages;
      if (languages is List && languages.isEmpty) return null;
      for (final tag in filipinoTags) {
        if (await _tts.isLanguageAvailable(tag) == true) return true;
      }
      return false;
    } catch (_) {
      return null;
    }
  }

  /// Stops the engine, and counts it as no longer speaking even if it never
  /// says so — an engine cut off with the app (sent to the background
  /// mid-sentence) can stay silent about it, and [speaking] must not then
  /// claim speech that is long over.
  Future<void> _stopped() async {
    await _engine(() => _tts.stop());
    _setSpeaking(false);
  }

  /// Switch the engine to [language], remembering it only if the engine
  /// actually took it.
  ///
  /// The code used to cache the language code regardless. On a device whose
  /// voice data for that language is missing, `setLanguage` fails, the engine
  /// keeps whatever it had — so Filipino text comes out in an English voice —
  /// and the cache then says the switch already happened, so it is never
  /// retried, not even after the user installs the voice.
  ///
  /// True when the engine speaks [language] now, false when the device has
  /// no voice for it, null when there is no engine to ask. Each switch is
  /// logged (the language, never the words), so a device check can read
  /// which voice the app asked for.
  Future<bool?> _useLanguage(String language) async {
    if (_currentLanguage == language) return true;
    final tags = language == 'fil-PH' ? filipinoTags : [language];
    for (final tag in tags) {
      try {
        if (await _tts.isLanguageAvailable(tag) != true) continue;
        await _tts.setLanguage(tag);
      } catch (_) {
        return null;
      }
      _currentLanguage = language;
      debugPrint('TtsService: voice $tag');
      return true;
    }
    debugPrint(
      'TtsService: no $language voice on this device; '
      'speaking with $_currentLanguage instead',
    );
    return false;
  }

  /// Speak text in English (en-US).
  Future<void> speakEnglish(String text) async {
    text = SpokenWords.withoutPictures(text);
    requests.value++;
    InputTrace.log('TtsSpeak en: $text');
    if (!_isInitialized) await init();
    await _stopped();
    await _useLanguage('en-US');
    await _engine(() => _tts.speak(text));
  }

  /// Speak text in Filipino (fil-PH).
  Future<void> speakFilipino(String text) async {
    text = SpokenWords.withoutPictures(text);
    requests.value++;
    InputTrace.log('TtsSpeak fil: $text');
    if (!_isInitialized) await init();
    await _stopped();
    if (await _useLanguage('fil-PH') == false) filipinoVoiceMissing.value++;
    await _engine(() => _tts.speak(text));
  }

  Future<void> stop() => _stopped();

  /// Register a callback that fires when TTS finishes speaking.
  void setCompletionHandler(void Function() handler) {
    _completionHandler = handler;
  }

  Future<void> setSpeed(double speed) =>
      _engine(() => _tts.setSpeechRate(speed));

  Future<void> dispose() => _stopped();
}

/// Global TTS provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  final settings = ref.watch(settingsProvider);
  service.appFilipino = settings.locale == 'fil';
  service.init(speed: settings.ttsSpeed);
  ref.onDispose(() => service.dispose());
  return service;
});
