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

/// Records the rate changes too, and finishes speech on demand — the engine's
/// completion is what puts the app's rate back after a 2× narration.
class _SpeedTts extends _RecordingTts {
  void Function()? _onDone;

  @override
  void setCompletionHandler(void Function() handler) => _onDone = handler;

  @override
  Future<void> setSpeed(double speed) async => calls.add('rate:$speed');

  /// The engine says it has finished the current utterance.
  void finish() => _onDone?.call();
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

  group('TvCastAudioNarrator playback speed', () {
    test('2× speaks at twice the app rate, then puts the rate back', () async {
      final tts = _SpeedTts();
      final narrator = TvCastAudioNarrator(
        tts: tts,
        sfx: _SilentSfx(),
        baseRate: () => 0.5,
      );
      await narrator.speakOne('Dog', filipino: false, speed: 2);
      expect(tts.calls, ['stop', 'rate:1.0', 'en:Dog']);
      tts.finish();
      await Future<void>.delayed(Duration.zero);
      expect(tts.calls.last, 'rate:0.5',
          reason: 'every other screen speaks at the learner\'s own pace');
    });

    test('both languages are said at 2×, the rate back only at the end',
        () async {
      final tts = _SpeedTts();
      final narrator = TvCastAudioNarrator(
        tts: tts,
        sfx: _SilentSfx(),
        baseRate: () => 0.5,
      );
      await narrator.speakBoth('Dog', 'Aso', speed: 2);
      tts.finish(); // English done: Filipino starts, still at 2×
      await Future<void>.delayed(Duration.zero);
      expect(tts.calls, ['stop', 'rate:1.0', 'en:Dog', 'fil:Aso']);
      tts.finish(); // Filipino done
      await Future<void>.delayed(Duration.zero);
      expect(tts.calls.last, 'rate:0.5');
    });

    test('at 1× the rate is never touched', () async {
      final tts = _SpeedTts();
      final narrator = TvCastAudioNarrator(
        tts: tts,
        sfx: _SilentSfx(),
        baseRate: () => 0.5,
      );
      await narrator.speakBoth('Dog', 'Aso');
      tts.finish();
      tts.finish();
      await narrator.stop();
      expect(tts.calls.where((c) => c.startsWith('rate:')), isEmpty);
    });

    test('stopping mid-word puts the rate back too', () async {
      final tts = _SpeedTts();
      final narrator = TvCastAudioNarrator(
        tts: tts,
        sfx: _SilentSfx(),
        baseRate: () => 0.6,
      );
      await narrator.speakOne('Aso', filipino: true, speed: 2);
      await narrator.stop();
      expect(tts.calls.last, 'rate:0.6');
    });
  });
}
