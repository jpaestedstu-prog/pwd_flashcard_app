import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_catalog.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_presentation.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_templates.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_step_screen.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_step_card.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/routine_test_doubles.dart';

/// The Routine surfaces in Filipino.
///
/// Two things are easy to get wrong here and both have bitten this codebase
/// before: **reading** the locale instead of watching it (the screen then never
/// re-renders when the learner switches language), and shipping an English
/// string with no Filipino twin. The first is covered by the live-switch test
/// at the bottom; the second by the catalog sweep.

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Settings whose locale can be flipped while the screen stays mounted.
class _SwitchableSettings extends SettingsNotifier {
  _SwitchableSettings(this._locale);
  final String _locale;

  @override
  AppSettings build() => AppSettings(reducedMotion: true, locale: _locale);

  void setLocale(String locale) {
    state = AppSettings(reducedMotion: true, locale: locale);
  }
}

Widget _app({
  required Widget home,
  String locale = 'fil',
  DisabilityType disability = DisabilityType.none,
  SettingsNotifier Function()? settings,
}) {
  return ProviderScope(
    overrides: [
      ...routineOverrides(disability: disability),
      settingsProvider.overrideWith(
        settings ??
            () => _FixedSettings(
                  AppSettings(reducedMotion: true, locale: locale),
                ),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

Future<void> _settle(
  WidgetTester tester, [
  Duration total = const Duration(milliseconds: 900),
]) async {
  const step = Duration(milliseconds: 100);
  for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
    await tester.pump(step);
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await _settle(tester, const Duration(milliseconds: 300));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/routine_localization');
    for (final name in const ['profiles', 'settings', 'progress']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (t, d) => false);
      }
    }
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  group('the content itself is bilingual', () {
    test('every catalog activity has a Filipino twin for every string', () {
      for (final info in RoutineCatalog.all) {
        expect(info.labelFilipino, isNotEmpty, reason: '${info.activity}');
        expect(info.blurbFilipino, isNotEmpty, reason: '${info.activity}');
        expect(info.audioCueFilipino, isNotEmpty, reason: '${info.activity}');
        // A Filipino string identical to the English one is almost always a
        // forgotten translation rather than a genuine loanword. "GIF" and
        // "Timer" are the real exceptions and they live elsewhere.
        expect(info.labelFilipino, isNot(info.label),
            reason: '${info.activity} label looks untranslated');
        for (final step in info.instructions) {
          expect(step.textFilipino, isNotEmpty, reason: '${info.activity}');
          expect(step.textFilipino, isNot(step.text),
              reason: '${info.activity}: "${step.text}" looks untranslated');
        }
      }
    });

    test('every template has a Filipino name and description', () {
      for (final t in RoutineTemplates.all) {
        expect(t.nameFilipino, isNotEmpty, reason: t.id);
        expect(t.descriptionFilipino, isNotEmpty, reason: t.id);
        expect(t.nameFilipino, isNot(t.name), reason: '${t.id} name');
      }
    });

    test('day names are localised, and "every day" is one phrase', () {
      expect(formatDays(const {}, filipino: true), 'Araw-araw');
      expect(formatDays(const {}, filipino: false), 'Every day');
      expect(formatDays(const {1, 3}, filipino: true), 'Lun, Miy');
      expect(formatDays(const {1, 3}, filipino: false), 'Mon, Wed');
    });

    test('titleFor and audioCueFor follow the reader', () {
      const lunch = RoutineStep(id: 's', activity: RoutineActivity.lunch);
      expect(RoutineCatalog.titleFor(lunch, filipino: true), 'Tanghalian');
      expect(
        RoutineCatalog.audioCueFor(lunch, filipino: true),
        contains('tanghalian'),
      );
    });
  });

  group('the learner’s day in Filipino', () {
    testWidgets('renders the routine, the counter and the step titles',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1400) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(home: const RoutineScreen()));
      await _settle(tester);

      expect(find.text('Ang Aking Araw'), findsOneWidget);
      expect(find.text('0 sa 4 tapos na'), findsOneWidget);
      expect(find.text('Gawain sa Umaga'), findsOneWidget);
      expect(find.text('Pagsisipilyo'), findsOneWidget);
      expect(find.text('Almusal'), findsOneWidget);
      // The custom step's own Filipino title, not the generic catalog word.
      expect(find.text('Ligpitin ang laruan'), findsOneWidget);
      // An unscheduled step says so in Filipino.
      expect(find.text('Kahit anong oras'), findsOneWidget);
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the empty state explains itself in Filipino', (tester) async {
      tester.view.physicalSize = const Size(800, 1400) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...routineOverrides(routines: const []),
          settingsProvider.overrideWith(
            () => _FixedSettings(
              const AppSettings(reducedMotion: true, locale: 'fil'),
            ),
          ),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('fil'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoutineScreen(),
        ),
      ));
      await _settle(tester);
      expect(find.text('Wala pang routine'), findsOneWidget);
      await _unmount(tester);
    });
  });

  group('a step in Filipino', () {
    testWidgets('the instructions, controls and placeholder note translate',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(
        home: RoutineStepScreen(
          step: const RoutineStep(
            id: 'step-brush',
            activity: RoutineActivity.brushingTeeth,
            hour: 6,
            minute: 45,
            durationMinutes: 2,
          ),
          presentation:
              RoutinePresentation.forType(DisabilityType.cognitive),
          profileId: kTestProfileId,
          day: DateTime.now(),
        ),
      ));
      await _settle(tester);

      expect(find.text('Pagsisipilyo'), findsWidgets);
      expect(find.text('Paano ito gawin'), findsOneWidget);
      expect(find.text('Basain ang sipilyo'), findsOneWidget);
      expect(find.text('Magmumog ng tubig'), findsOneWidget);
      expect(find.text('Tulong sa Gawain'), findsOneWidget);
      expect(find.text('Basahin ito'), findsOneWidget);
      expect(find.text('Tapos na!'), findsOneWidget);
      expect(find.text('2 minuto'), findsWidgets);
      expect(
        find.textContaining('Wala pang larawan o bidyo dito'),
        findsOneWidget,
      );
      await _unmount(tester);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('switching language re-renders a mounted day', (tester) async {
    // The trap: `ref.read(settingsProvider)` compiles and looks right, but the
    // screen then keeps the language it was born with. Every routine surface
    // must *watch* it.
    tester.view.physicalSize = const Size(800, 1400) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        ...routineOverrides(),
        settingsProvider.overrideWith(() => _SwitchableSettings('en')),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RoutineScreen(),
      ),
    ));
    await _settle(tester);
    expect(find.text('0 of 4 done'), findsOneWidget);

    (container.read(settingsProvider.notifier) as _SwitchableSettings)
        .setLocale('fil');
    await _settle(tester, const Duration(milliseconds: 400));

    expect(find.text('0 sa 4 tapos na'), findsOneWidget);
    expect(find.text('0 of 4 done'), findsNothing);
    await _unmount(tester);
  });
}
