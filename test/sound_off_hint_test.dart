import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/device_sound.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/sound_off_hint.dart';

/// "Your device sound is off": found on the tablet, whose media volume was 0
/// of 15, so every spoken word was silent and nothing said why.

UserProfile _learner(DisabilityType type) => UserProfile(
      id: 'sound-hint-learner',
      name: 'Learner',
      role: UserRole.student,
      disabilityType: type,
      createdAt: DateTime(2026),
    );

class _Profile extends ProfileNotifier {
  _Profile(this.profile);
  final UserProfile profile;
  @override
  UserProfile? build() => profile;
}

/// In memory only: a real save would write to Hive from the test zone.
class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final AppSettings initial;
  @override
  AppSettings build() => initial;
  @override
  void update(AppSettings newSettings) => state = newSettings;
}

void main() {
  group('who is told', () {
    const auto = AppSettings();

    test('learners who listen to the words, by default', () {
      expect(soundOffHintWanted(_learner(DisabilityType.visual), auto), isTrue);
      expect(
        soundOffHintWanted(
          _learner(DisabilityType.motor),
          auto.copyWith(voiceNavigation: true),
        ),
        isTrue,
      );
    });

    test('nobody else, by default', () {
      for (final type in [
        DisabilityType.hearing,
        DisabilityType.motor,
        DisabilityType.cognitive,
        DisabilityType.none,
      ]) {
        expect(soundOffHintWanted(_learner(type), auto), isFalse, reason: '$type');
      }
      expect(soundOffHintWanted(null, auto), isFalse);
    });

    test('the profile\'s own choice wins either way', () {
      expect(
        soundOffHintWanted(
          _learner(DisabilityType.hearing),
          auto.copyWith(soundOffHint: SoundOffHintChoice.on),
        ),
        isTrue,
      );
      expect(
        soundOffHintWanted(
          _learner(DisabilityType.visual),
          auto.copyWith(soundOffHint: SoundOffHintChoice.off),
        ),
        isFalse,
      );
    });

    test('with speech switched off there is nothing to miss', () {
      expect(
        soundOffHintWanted(
          _learner(DisabilityType.visual),
          auto.copyWith(ttsEnabled: false, soundOffHint: SoundOffHintChoice.on),
        ),
        isFalse,
      );
    });

    test('a saved choice reads back; anything else is the default', () {
      for (final c in SoundOffHintChoice.values) {
        expect(SoundOffHintChoice.fromName(c.name), c);
      }
      expect(SoundOffHintChoice.fromName(null), SoundOffHintChoice.auto);
      expect(SoundOffHintChoice.fromName('loud'), SoundOffHintChoice.auto);
      expect(const AppSettings().soundOffHint, SoundOffHintChoice.auto);
    });
  });

  group('the note', () {
    late bool soundOff;
    late int turnUps;
    late ProviderContainer container;

    setUp(() {
      soundOff = true;
      turnUps = 0;
      DeviceSound.debugIsOff = () async => soundOff;
      DeviceSound.debugCanTurnUp = true;
      DeviceSound.debugTurnUp = () async {
        turnUps++;
        soundOff = false;
        return true;
      };
    });

    tearDown(() {
      DeviceSound.debugIsOff = null;
      DeviceSound.debugCanTurnUp = null;
      DeviceSound.debugTurnUp = null;
    });

    Future<void> pumpHost(
      WidgetTester tester, {
      DisabilityType type = DisabilityType.visual,
      AppSettings settings = const AppSettings(),
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
            profileProvider.overrideWith(() => _Profile(_learner(type))),
            settingsProvider.overrideWith(() => _Settings(settings)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: SoundOffHintHost(child: child!),
            ),
            home: const Scaffold(body: Center(child: Text('lesson'))),
          ),
        ),
      );
      container = ProviderScope.containerOf(
        tester.element(find.byType(SoundOffHintHost)),
      );
    }

    Future<void> speak(WidgetTester tester) async {
      TtsService.requests.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    final note = find.byKey(const ValueKey('sound-off-hint'));

    testWidgets('shows when the app speaks with the sound off', (tester) async {
      await pumpHost(tester);
      expect(note, findsNothing);

      await speak(tester);

      expect(note, findsOneWidget);
      expect(find.text('Your device sound is off'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('stays away while the sound is on', (tester) async {
      soundOff = false;
      await pumpHost(tester);
      await speak(tester);
      expect(note, findsNothing);
    });

    testWidgets('stays away from learners who do not listen to the words',
        (tester) async {
      await pumpHost(tester, type: DisabilityType.hearing);
      await speak(tester);
      expect(note, findsNothing);
    });

    testWidgets('OK hides it and keeps it away for a while', (tester) async {
      await pumpHost(tester);
      await speak(tester);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(note, findsNothing);

      await speak(tester);
      expect(note, findsNothing, reason: 'snoozed after OK');
    });

    testWidgets('"Don’t remind me" switches it off for the profile',
        (tester) async {
      await pumpHost(tester);
      await speak(tester);
      await tester.tap(find.text('Don’t remind me'));
      await tester.pumpAndSettle();

      expect(note, findsNothing);
      expect(container.read(settingsProvider).soundOffHint,
          SoundOffHintChoice.off);
    });

    testWidgets('"Turn sound up" fixes it and the note goes', (tester) async {
      await pumpHost(tester);
      await speak(tester);
      await tester.tap(find.text('Turn sound up'));
      await tester.pumpAndSettle();

      expect(turnUps, 1);
      expect(note, findsNothing);
      await speak(tester);
      expect(note, findsNothing, reason: 'the sound is on now');
    });

    testWidgets('goes by itself when nobody touches it', (tester) async {
      await pumpHost(tester);
      await speak(tester);
      expect(note, findsOneWidget);

      await tester.pump(SoundOffHintHost.showFor);
      await tester.pumpAndSettle();
      expect(note, findsNothing);
    });

    testWidgets('fits a small phone at the largest text size', (tester) async {
      await pumpHost(tester, size: const Size(360, 640), textScale: 2.0);
      await speak(tester);
      expect(note, findsOneWidget);
      expect(tester.takeException(), isNull);
      // Every button is still on screen and tappable.
      for (final label in ['OK', 'Don’t remind me', 'Turn sound up']) {
        expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
      }
    });
  });
}
