import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

/// Text-to-Speech service with bilingual support (English + Filipino)
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  String _currentLanguage = 'en-US';

  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {
    if (_isInitialized) return;
    await _tts.setLanguage('en-US');
    _currentLanguage = 'en-US';
    await _tts.setSpeechRate(speed);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);
    _isInitialized = true;
  }

  /// Speak text using the currently set language (default English).
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Switch the engine to [language], remembering it only if the engine
  /// actually took it.
  ///
  /// The code used to cache the language code regardless. On a device whose
  /// voice data for that language is missing, `setLanguage` fails, the engine
  /// keeps whatever it had — so Filipino text comes out in an English voice —
  /// and the cache then says the switch already happened, so it is never
  /// retried, not even after the user installs the voice.
  Future<void> _useLanguage(String language) async {
    if (_currentLanguage == language) return;
    final available = await _tts.isLanguageAvailable(language);
    if (available != true) {
      if (kDebugMode) {
        debugPrint(
          'TtsService: $language has no voice on this device; '
          'speaking with $_currentLanguage instead',
        );
      }
      return;
    }
    await _tts.setLanguage(language);
    _currentLanguage = language;
  }

  /// Speak text in English (en-US).
  Future<void> speakEnglish(String text) async {
    if (!_isInitialized) await init();
    await _tts.stop();
    await _useLanguage('en-US');
    await _tts.speak(text);
  }

  /// Speak text in Filipino (fil-PH).
  Future<void> speakFilipino(String text) async {
    if (!_isInitialized) await init();
    await _tts.stop();
    await _useLanguage('fil-PH');
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  /// Register a callback that fires when TTS finishes speaking.
  void setCompletionHandler(void Function() handler) {
    _tts.setCompletionHandler(handler);
  }

  Future<void> setSpeed(double speed) async {
    await _tts.setSpeechRate(speed);
  }

  Future<void> dispose() async {
    await _tts.stop();
  }
}

/// Global TTS provider
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  final settings = ref.watch(settingsProvider);
  service.init(speed: settings.ttsSpeed);
  ref.onDispose(() => service.dispose());
  return service;
});
