import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/hands_free_pause.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/scan_clock.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/voice_commands.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/voice_screen_reading.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/hands_free_paused_banner.dart';

/// Voice for learners who cannot use their hands: the app-wide commands
/// ("read the screen", "say again", "what can I say", "stop listening",
/// "resume"), Voice only (no camera), and the pause they control.
void main() {
  tearDown(resumeHandsFree);

  GlobalVoiceIntent say(String phrase, {bool paused = false}) =>
      resolveGlobalVoiceCommand(phrase, paused: paused);

  group('app-wide voice commands', () {
    test('each command, in English and Filipino', () {
      for (final p in ['stop listening', 'pause listening', 'pause voice', 'huwag makinig', 'hinto muna']) {
        expect(say(p), GlobalVoiceIntent.pause, reason: p);
      }
      for (final p in ['read the screen', 'read screen', 'read the instructions', "what's on the screen",
          'basahin ang screen', 'basahin ang instructions']) {
        expect(say(p), GlobalVoiceIntent.readScreen, reason: p);
      }
      for (final p in ['repeat', 'say again', 'say that again', 'sabihin ulit', 'pakiulit']) {
        expect(say(p), GlobalVoiceIntent.repeat, reason: p);
      }
      for (final p in ['what can I say', 'voice commands', 'ano ang masasabi ko']) {
        expect(say(p), GlobalVoiceIntent.help, reason: p);
      }
    });

    test('recogniser noise: capitals, punctuation, a longer sentence', () {
      expect(say('Read the screen.'), GlobalVoiceIntent.readScreen);
      expect(say('please read the screen'), GlobalVoiceIntent.readScreen);
      expect(say('STOP LISTENING!'), GlobalVoiceIntent.pause);
      expect(say('What can I say?'), GlobalVoiceIntent.help);
    });

    test('words that are real button labels still reach the screen', () {
      // A game's Pause and Resume, a story's Read, Filipino "Ulitin"
      // (restart a game), "repeat after me" on a button.
      for (final p in ['pause', 'resume', 'read', 'ulitin', 'repeat after me', 'games', 'next', 'select', 'go back']) {
        expect(say(p), GlobalVoiceIntent.none, reason: p);
      }
    });

    test('while paused, only resume is heard', () {
      for (final p in ['resume', 'continue', 'ituloy', 'tuloy', 'start listening', 'Resume.']) {
        expect(say(p, paused: true), GlobalVoiceIntent.resume, reason: p);
      }
      for (final p in ['games', 'select', 'read the screen', 'left', 'stop listening']) {
        expect(say(p, paused: true), GlobalVoiceIntent.none, reason: p);
      }
    });

    test('the existing screen commands are unchanged', () {
      expect(resolveDpadVoiceCommand('left', const []).intent, DpadVoiceIntent.moveLeft);
      expect(resolveDpadVoiceCommand('select', const []).intent, DpadVoiceIntent.select);
      expect(resolveDpadVoiceCommand('go back', const []).intent, DpadVoiceIntent.goBack);
      expect(resolveDpadVoiceCommand('scroll down', const []).intent, DpadVoiceIntent.scrollDown);
    });
  });

  group('Voice only (camera off)', () {
    test('turns the camera off when voice commands are on', () {
      const voiceOnly = GazeSettings(enabled: true, voiceCommands: true, voiceOnly: true);
      expect(voiceOnly.voiceOnlyActive, isTrue);
      expect(voiceOnly.usesCamera, isFalse);
      expect(voiceOnly.blinkSelects, isFalse);
    });

    test('without voice commands it cannot work, so the camera stays as it was', () {
      const stale = GazeSettings(enabled: true, voiceOnly: true);
      expect(stale.voiceOnlyActive, isFalse);
      expect(stale.usesCamera, isTrue);
    });

    test('head mode and switch scanning keep their own camera rule', () {
      expect(const GazeSettings(enabled: true).usesCamera, isTrue);
      expect(const GazeSettings(enabled: true, scanMode: true, pickWith: GazePick.switchButton).usesCamera,
          isFalse);
    });

    test('saved and read back; settings saved before it default to off', () {
      const s = GazeSettings(enabled: true, voiceCommands: true, voiceOnly: true);
      final back = GazeSettings.fromMap(s.toMap());
      expect(back, s);
      expect(back.voiceOnly, isTrue);
      final old = Map<String, dynamic>.from(s.toMap())..remove('voiceOnly');
      expect(GazeSettings.fromMap(old).voiceOnly, isFalse);
      expect(s.copyWith(voiceOnly: false).voiceOnly, isFalse);
      expect(s.hashCode == s.copyWith(voiceOnly: false).hashCode, isFalse);
    });
  });

  group('"read the screen" wording', () {
    test('heading, the screen’s words, then what can be said', () {
      expect(
        voiceScreenSummary(
          title: 'Word Match',
          prose: ['Which picture is the dog?'],
          choices: ['Dog', 'Cat', 'Bird'],
          filipino: false,
        ),
        'Word Match. Which picture is the dog? You can say: Dog, Cat, Bird.',
      );
      expect(
        voiceScreenSummary(title: 'Home', prose: const [], choices: ['Cards'], filipino: true),
        'Home. Masasabi mo: Cards.',
      );
    });

    test('long lists are cut short; repeats and blanks are dropped; empty screens say so', () {
      final many = [for (var i = 1; i <= 15; i++) 'Item $i'];
      final text = voiceScreenSummary(title: '', prose: const [], choices: many, filipino: false);
      expect(text, contains('Item 12, and 3 more.'));
      expect(text, isNot(contains('Item 13')));
      expect(
        voiceScreenSummary(title: 'Games', prose: ['Games'], choices: ['Dog', 'dog', ' '], filipino: false),
        'Games. You can say: Dog.',
      );
      expect(voiceScreenSummary(title: '', prose: const [], choices: const [], filipino: false),
          'There is nothing to read here.');
    });
  });

  group('pausing hands-free control', () {
    test('the scanning highlight stands still while paused, and moves on after', () {
      fakeAsync((async) {
        var steps = 0;
        final clock = ScanClock(step: const Duration(seconds: 1), onStep: () => steps++);
        clock.start();
        async.elapse(const Duration(milliseconds: 2100));
        expect(steps, 2);
        pauseHandsFree();
        async.elapse(const Duration(seconds: 5));
        expect(steps, 2, reason: 'nothing moves while paused');
        resumeHandsFree();
        async.elapse(const Duration(milliseconds: 1100));
        expect(steps, 3);
        clock.stop();
      });
    });

    testWidgets('a banner shows the pause, and a tap on it resumes', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: HandsFreePausedBanner(child: Scaffold(body: Text('lesson'))),
      ));
      expect(find.text('Hands-free control is paused'), findsNothing);
      pauseHandsFree();
      await tester.pump();
      expect(find.text('Hands-free control is paused'), findsOneWidget);
      expect(find.text('lesson'), findsOneWidget, reason: 'the screen stays underneath');
      final semantics = tester.getSemantics(find.bySemanticsLabel(RegExp('Hands-free control is paused')));
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      await tester.tap(find.text('Hands-free control is paused'));
      await tester.pump();
      expect(handsFreePaused.value, isFalse);
      expect(find.text('Hands-free control is paused'), findsNothing);
    });
  });
}
