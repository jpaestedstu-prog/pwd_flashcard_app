import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_audio_narrator.dart';

/// Records which TTS calls the narrator makes, without touching real platform
/// channels. `extends` (not `implements`) so the base FlutterTts field exists,
/// but every method that would hit the channel is overridden to a no-op record.
class _RecordingTts extends TtsService {
  final List<String> calls = [];

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> speakEnglish(String text) async => calls.add('en:$text');

  @override
  Future<void> speakFilipino(String text) async => calls.add('fil:$text');

  @override
  void setCompletionHandler(void Function() handler) {}
}

/// `implements` so the real `AudioPlayer()` field initializer never runs.
class _SilentSfx implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  // FlutterTts()'s constructor registers a platform method-call handler, which
  // needs the binding initialized (plain `test()` doesn't do this the way
  // `testWidgets` does). The handler is never invoked — every channel-touching
  // method is overridden in _RecordingTts.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TvCastAudioNarrator.speakOne (on-demand replay)', () {
    test('speaks English only when filipino:false', () async {
      final tts = _RecordingTts();
      await TvCastAudioNarrator(tts: tts, sfx: _SilentSfx())
          .speakOne('Dog', filipino: false);
      expect(tts.calls, contains('en:Dog'));
      expect(tts.calls.any((c) => c.startsWith('fil:')), isFalse,
          reason: 'English replay must not also speak Filipino');
    });

    test('speaks Filipino only when filipino:true', () async {
      final tts = _RecordingTts();
      await TvCastAudioNarrator(tts: tts, sfx: _SilentSfx())
          .speakOne('Aso', filipino: true);
      expect(tts.calls, contains('fil:Aso'));
      expect(tts.calls.any((c) => c.startsWith('en:')), isFalse,
          reason: 'Filipino replay must not also speak English');
    });

    test('is a no-op on empty / whitespace text', () async {
      final tts = _RecordingTts();
      await TvCastAudioNarrator(tts: tts, sfx: _SilentSfx())
          .speakOne('   ', filipino: false);
      expect(tts.calls, isEmpty);
    });
  });
}
