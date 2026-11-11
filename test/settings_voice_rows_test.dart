import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/device_sound.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart';

/// The two rows in Settings about voices: whether Filipino words have a
/// Filipino voice here (and the way to add one), and, for someone on TalkBack
/// in a Filipino app, the way to set TalkBack's own words to Filipino.

class _Settings extends SettingsNotifier {
  _Settings(this.locale);
  final String locale;
  @override
  AppSettings build() => AppSettings(locale: locale);
  @override
  void update(AppSettings newSettings) => state = newSettings;
}

final _en = AppLocalizationsEn();
final _fil = AppLocalizationsFil();

void main() {
  late int voiceOpened;
  late int talkBackOpened;

  setUpAll(() => openMemoryBoxes('settings_voice_rows'));

  setUp(() {
    voiceOpened = 0;
    talkBackOpened = 0;
    DeviceSound.debugCanOpenVoiceSettings = true;
    DeviceSound.debugOpenVoiceSettings = () async {
      voiceOpened++;
      return true;
    };
    DeviceSound.debugOpenTalkBackLanguage = () async {
      talkBackOpened++;
      return true;
    };
  });
  tearDown(() {
    DeviceSound.debugCanOpenVoiceSettings = null;
    DeviceSound.debugOpenVoiceSettings = null;
    DeviceSound.debugOpenTalkBackLanguage = null;
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    required Set<String> voices,
    String locale = 'en',
    bool talkBack = false,
  }) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('flutter_tts'),
        (call) async {
      if (call.method == 'getLanguages') return voices.toList();
      if (call.method == 'isLanguageAvailable') {
        return voices.contains(call.arguments as String);
      }
      return 1;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          null,
        ));
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sweepProfileOverride(UserRole.student),
        settingsProvider.overrideWith(() => _Settings(locale)),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(accessibleNavigation: talkBack),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    ));
    for (var t = 0; t < 20; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<bool> scrollTo(WidgetTester tester, Finder finder) async {
    final list = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    final position = tester.state<ScrollableState>(list.first).position;
    for (var i = 0; i < 80 && finder.evaluate().isEmpty; i++) {
      if (position.extentAfter <= 0) break;
      position.jumpTo(
        (position.pixels + 250).clamp(0.0, position.maxScrollExtent),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return finder.evaluate().isNotEmpty;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  group('the Filipino voice row', () {
    testWidgets('says the voice is there', (tester) async {
      await pumpSettings(tester, voices: {'en-US', 'fil-PH'});
      expect(await scrollTo(tester, find.text(_en.fvSettingInstalled)), isTrue);
      await unmount(tester);
    });

    testWidgets('says it is not, and a tap opens the voice settings',
        (tester) async {
      await pumpSettings(tester, voices: {'en-US'});
      final row = find.textContaining(_en.fvSettingMissing);
      expect(await scrollTo(tester, row), isTrue);
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 100));
      expect(voiceOpened, 1);
      await unmount(tester);
    });

    testWidgets('in Filipino', (tester) async {
      await pumpSettings(tester, voices: {'en-US'}, locale: 'fil');
      expect(await scrollTo(tester, find.textContaining(_fil.fvSettingMissing)),
          isTrue);
      await unmount(tester);
    });

    testWidgets('a browser with no list of voices yet says nothing',
        (tester) async {
      await pumpSettings(tester, voices: {});
      expect(await scrollTo(tester, find.text(_en.fvSetting)), isFalse);
      await unmount(tester);
    });
  });

  group('TalkBack\'s own words', () {
    testWidgets('a Filipino app on TalkBack gets the way to change them',
        (tester) async {
      await pumpSettings(
        tester,
        voices: {'en-US', 'fil-PH'},
        locale: 'fil',
        talkBack: true,
      );
      final row = find.text(_fil.fvTalkBackWords);
      expect(await scrollTo(tester, row), isTrue);
      await tester.ensureVisible(row);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(row);
      await tester.pump(const Duration(milliseconds: 100));
      expect(talkBackOpened, 1);
      await unmount(tester);
    });

    testWidgets('no row without TalkBack', (tester) async {
      await pumpSettings(tester, voices: {'en-US'}, locale: 'fil');
      expect(await scrollTo(tester, find.text(_fil.fvTalkBackWords)), isFalse);
      await unmount(tester);
    });

    testWidgets('no row in English: its words are in the language shown',
        (tester) async {
      await pumpSettings(tester, voices: {'en-US'}, talkBack: true);
      expect(await scrollTo(tester, find.text(_en.fvTalkBackWords)), isFalse);
      await unmount(tester);
    });
  });
}
