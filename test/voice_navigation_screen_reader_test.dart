import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/accessibility/voice_navigation_service.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_announcer.dart';

/// With TalkBack on, the app's own voice must not talk over it. Found on the
/// tablet: opening Home, the app announced the screen while TalkBack read the
/// first control — two voices at once. A running screen reader now speaks the
/// announcement itself, in its own queue.

class _FakeTts extends TtsService {
  final List<String> spoken = [];
  @override
  Future<void> speakEnglish(String text) async => spoken.add(text);
  @override
  Future<void> speakFilipino(String text) async => spoken.add('[fil] $text');
  @override
  Future<void> stop() async {}
  @override
  Future<void> setSpeed(double speed) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late bool Function() original;
  late List<Object?> sent;

  setUp(() {
    original = VoiceNavigationService.screenReaderOn;
    sent = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility,
            (message) async {
      sent.add(message);
      return null;
    });
  });
  tearDown(() {
    VoiceNavigationService.screenReaderOn = original;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, null);
  });

  test('without a screen reader the app speaks the screen', () async {
    final tts = _FakeTts();
    final nav = VoiceNavigationService(tts)..setEnabled(true);
    VoiceNavigationService.screenReaderOn = () => false;

    await nav.announceScreen('Home', description: 'Explore categories');
    expect(tts.spoken, ['Home. Explore categories']);
    expect(sent, isEmpty);
  });

  test('with a screen reader on, the reader says it — the app stays quiet',
      () async {
    final tts = _FakeTts();
    final nav = VoiceNavigationService(tts)..setEnabled(true);
    VoiceNavigationService.screenReaderOn = () => true;

    await nav.announceScreen('Home', description: 'Explore categories');
    await nav.announceGameEvent('Correct!');
    expect(tts.spoken, isEmpty, reason: 'no second voice');
    final messages = [
      for (final m in sent)
        if (m is Map && m['type'] == 'announce') (m['data'] as Map)['message'],
    ];
    expect(messages, ['Home. Explore categories', 'Correct!']);
  });

  test('switched off, neither speaks', () async {
    final tts = _FakeTts();
    final nav = VoiceNavigationService(tts);
    VoiceNavigationService.screenReaderOn = () => true;

    await nav.announceScreen('Home');
    expect(tts.spoken, isEmpty);
    expect(sent, isEmpty);
  });

  // The controller's voice has the same rule. Found on the tablet with
  // TalkBack on: each press moved the focus, TalkBack read the new control,
  // and the controller read it again over the top.
  group('the controller speech', () {
    List<Object?> announced() => [
          for (final m in sent)
            if (m is Map && m['type'] == 'announce')
              (m['data'] as Map)['message'],
        ];

    test('without a screen reader, the controller speaks', () async {
      final tts = _FakeTts();
      VoiceNavigationService.screenReaderOn = () => false;

      await GamepadAnnouncer(tts).say('Games, 3 of 12.');
      expect(tts.spoken, ['Games, 3 of 12.']);
      expect(announced(), isEmpty);
    });

    test('a focus move is left to the screen reader, which reads it',
        () async {
      final tts = _FakeTts();
      VoiceNavigationService.screenReaderOn = () => true;
      final announcer = GamepadAnnouncer(tts);

      await announcer.say('Games, 3 of 12.', readByScreenReader: true);
      expect(tts.spoken, isEmpty, reason: 'no second voice');
      expect(announced(), isEmpty, reason: 'TalkBack already read it');
      expect(announcer.lastMessage, 'Games, 3 of 12.',
          reason: 'the repeat button still has it');
    });

    test('anything else the controller says, the screen reader says',
        () async {
      final tts = _FakeTts();
      VoiceNavigationService.screenReaderOn = () => true;
      final announcer = GamepadAnnouncer(tts);

      await announcer.say('Left the text box.');
      await announcer.repeat();
      expect(tts.spoken, isEmpty);
      expect(announced(), ['Left the text box.', 'Left the text box.']);
    });
  });
}
