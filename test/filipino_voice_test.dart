import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/device_sound.dart';
import 'package:pwdpwdpwd/core/accessibility/spoken_words.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/filipino_voice_hint.dart';
import 'package:pwdpwdpwd/widgets/sound_off_hint.dart';

/// The right voice for each language, and the note when a device has no
/// Filipino one.
///
/// Before: speech that did not name its language (a mood check-in's
/// "Na-save. Ang pakiramdam mo ay …", a teacher's question, the Word of the
/// Day) came out in whatever voice the engine had used last, and a device
/// without a Filipino voice read every Filipino word in the English one
/// without a word about it.

/// The speech engine, faked: which voices it has, and what it was told.
class _Engine {
  _Engine(this.voices);

  Set<String> voices;
  final calls = <MethodCall>[];

  List<String> get languagesSet => [
        for (final c in calls)
          if (c.method == 'setLanguage') c.arguments as String,
      ];

  List<String> get spoken => [
        for (final c in calls)
          if (c.method == 'speak')
            c.arguments is Map
                ? (c.arguments as Map)['text'] as String
                : c.arguments as String,
      ];

  Future<Object?> handle(MethodCall call) async {
    calls.add(call);
    switch (call.method) {
      case 'isLanguageAvailable':
        return voices.contains(call.arguments as String);
      case 'getLanguages':
        return voices.toList();
      default:
        return 1;
    }
  }
}

const _channel = MethodChannel('flutter_tts');

_Engine _fakeEngine(Set<String> voices) {
  final engine = _Engine(voices);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, engine.handle);
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null));
  return engine;
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  void update(AppSettings newSettings) => state = newSettings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the language a text is written in', () {
    test('Filipino sentences read as Filipino', () {
      for (final s in [
        'Ano ang kulay ng langit?',
        'Na-save. Ang pakiramdam mo ay Masaya.',
        'Saan ang aso?',
        'Ito ay isang pusa.',
        'Kumusta ka ngayon?',
      ]) {
        expect(SpokenWords.looksFilipino(s, otherwise: false), isTrue,
            reason: s);
      }
    });

    test('English sentences read as English', () {
      for (final s in [
        'What color is the sky?',
        'Saved. You are feeling Happy.',
        'The dog is my best friend.',
        'Where is the cat?',
        'Look at the picture and choose the word.',
      ]) {
        expect(SpokenWords.looksFilipino(s, otherwise: true), isFalse,
            reason: s);
      }
    });

    test('one word, or a name, goes by the app\'s language', () {
      for (final s in ['Masaya', 'Butterfly', 'Ana Maria', '']) {
        expect(SpokenWords.looksFilipino(s, otherwise: true), isTrue,
            reason: s);
        expect(SpokenWords.looksFilipino(s, otherwise: false), isFalse,
            reason: s);
      }
    });

    test('"at" and "may", in both languages, decide nothing', () {
      expect(SpokenWords.looksFilipino('at may', otherwise: true), isTrue);
      expect(SpokenWords.looksFilipino('at may', otherwise: false), isFalse);
    });
  });

  group('which voice speaks', () {
    test('a Filipino question in the Filipino voice, whatever came before',
        () async {
      final engine = _fakeEngine({'en-US', 'fil-PH'});
      final tts = TtsService();
      await tts.speakEnglish('Dog');
      await tts.speak('Ano ang kulay ng langit?');
      expect(engine.languagesSet.last, 'fil-PH');
      expect(engine.spoken.last, 'Ano ang kulay ng langit?');
    });

    test('an English question in the English voice, after Filipino',
        () async {
      final engine = _fakeEngine({'en-US', 'fil-PH'});
      final tts = TtsService()..appFilipino = true;
      await tts.speakFilipino('Magaling!');
      await tts.speak('What color is the sky?');
      expect(engine.languagesSet.last, 'en-US');
    });

    test('a word alone in the app\'s language', () async {
      final engine = _fakeEngine({'en-US', 'fil-PH'});
      final tts = TtsService()..appFilipino = true;
      await tts.speak('Masaya');
      expect(engine.languagesSet.last, 'fil-PH');
      tts.appFilipino = false;
      await tts.speak('Masaya');
      expect(engine.languagesSet.last, 'en-US');
    });

    test('speakIn says it in the language it is told', () async {
      final engine = _fakeEngine({'en-US', 'fil-PH'});
      final tts = TtsService();
      await tts.speakIn('Na-save.', filipino: true);
      expect(engine.languagesSet.last, 'fil-PH');
      await tts.speakIn('Saved.', filipino: false);
      expect(engine.languagesSet.last, 'en-US');
    });

    test('an engine that names Filipino by Tagalog is used', () async {
      final engine = _fakeEngine({'en-US', 'tl-PH'});
      final before = TtsService.filipinoVoiceMissing.value;
      final tts = TtsService();
      await tts.speakFilipino('Magaling!');
      expect(engine.languagesSet.last, 'tl-PH');
      expect(TtsService.filipinoVoiceMissing.value, before);
    });

    test('no Filipino voice: the words are still said, and it is counted',
        () async {
      final engine = _fakeEngine({'en-US'});
      final before = TtsService.filipinoVoiceMissing.value;
      final tts = TtsService();
      await tts.speakFilipino('Magaling!');
      expect(engine.languagesSet, isNot(contains('fil-PH')));
      expect(engine.spoken.last, 'Magaling!');
      expect(TtsService.filipinoVoiceMissing.value, before + 1);
    });

    test('a new service finds the engine where the last one left it',
        () async {
      final engine = _fakeEngine({'en-US', 'fil-PH'});
      final first = TtsService();
      await first.speakFilipino('Magaling!');
      final second = TtsService();
      await second.init();
      engine.calls.clear();
      await second.speakFilipino('Isa pa!');
      // init put the engine back to English, so Filipino is asked for again.
      expect(engine.languagesSet, ['fil-PH']);
    });

    test('whether the device has a Filipino voice', () async {
      _fakeEngine({'en-US', 'fil-PH'});
      expect(await TtsService().hasFilipinoVoice(), isTrue);
      _fakeEngine({'en-US'});
      expect(await TtsService().hasFilipinoVoice(), isFalse);
      // A browser that has not listed its voices yet cannot tell.
      _fakeEngine({});
      expect(await TtsService().hasFilipinoVoice(), isNull);
    });
  });

  group('"Don\'t remind me" is kept for the device', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fv_hint');
      Hive.init(dir.path);
      await Hive.openBox('settings');
    });
    tearDown(() async {
      await Hive.deleteFromDisk();
      try {
        await dir.delete(recursive: true);
      } on FileSystemException {
        // Still held on Windows: the temp folder goes later.
      }
    });

    test('off once chosen, and back on', () async {
      expect(HiveService.filipinoVoiceHintOff(), isFalse);
      await HiveService.setFilipinoVoiceHintOff(true);
      expect(HiveService.filipinoVoiceHintOff(), isTrue);
      await HiveService.setFilipinoVoiceHintOff(false);
      expect(HiveService.filipinoVoiceHintOff(), isFalse);
    });
  });

  group('the note', () {
    late int opened;

    setUp(() {
      opened = 0;
      DeviceSound.debugCanOpenVoiceSettings = true;
      DeviceSound.debugOpenVoiceSettings = () async {
        opened++;
        return true;
      };
      SoundOffHintHost.visible.value = false;
    });
    tearDown(() {
      DeviceSound.debugCanOpenVoiceSettings = null;
      DeviceSound.debugOpenVoiceSettings = null;
      SoundOffHintHost.visible.value = false;
    });

    final note = find.byKey(const ValueKey('filipino-voice-hint'));

    Future<void> pumpHost(
      WidgetTester tester, {
      String locale = 'en',
      bool screenReader = false,
      Size size = const Size(800, 1280),
      double textScale = 1,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider
                .overrideWith(() => _Settings(AppSettings(locale: locale))),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
                accessibleNavigation: screenReader,
              ),
              child: FilipinoVoiceHintHost(child: child!),
            ),
            home: const Scaffold(body: Center(child: Text('lesson'))),
          ),
        ),
      );
    }

    Future<void> missing(WidgetTester tester) async {
      TtsService.filipinoVoiceMissing.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows when Filipino came out in the English voice',
        (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester);
      expect(note, findsNothing);

      await missing(tester);

      expect(note, findsOneWidget);
      expect(find.text('No Filipino voice on this device'), findsOneWidget);
      expect(find.textContaining('by the app and by TalkBack'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in Filipino, for a Filipino screen', (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester, locale: 'fil');
      await missing(tester);
      expect(find.text('Walang boses na Filipino sa device na ito'),
          findsOneWidget);
      expect(find.text('Buksan ang setting ng boses'), findsOneWidget);
    });

    testWidgets('opens the device\'s voice settings, then goes',
        (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester);
      await missing(tester);

      await tester.tap(find.text('Open voice settings'));
      await tester.pumpAndSettle();

      expect(opened, 1);
      expect(note, findsNothing);
    });

    testWidgets('once in a run of the app', (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester);
      await missing(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(note, findsNothing);

      await missing(tester);
      expect(note, findsNothing);
    });

    testWidgets('goes by itself', (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester);
      await missing(tester);
      await tester.pump(FilipinoVoiceHintHost.showFor);
      await tester.pumpAndSettle();
      expect(note, findsNothing);
    });

    testWidgets('waits for the sound-off note, never over it',
        (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(tester);
      SoundOffHintHost.visible.value = true;
      await missing(tester);
      expect(note, findsNothing);

      SoundOffHintHost.visible.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(note, findsOneWidget);
    });

    testWidgets('a screen reader in Filipino is told at once',
        (tester) async {
      // Its voice is the device's too: it reads the Filipino screens in
      // English before the app ever speaks.
      _fakeEngine({'en-US'});
      await pumpHost(tester, locale: 'fil', screenReader: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(note, findsOneWidget);
    });

    testWidgets('nothing where the voice is there', (tester) async {
      _fakeEngine({'en-US', 'fil-PH'});
      await pumpHost(tester, locale: 'fil', screenReader: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(note, findsNothing);
    });

    testWidgets('fits a small phone at the largest text size',
        (tester) async {
      _fakeEngine({'en-US'});
      await pumpHost(
        tester,
        locale: 'fil',
        size: const Size(360, 640),
        textScale: 1.5,
      );
      await missing(tester);
      expect(note, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
