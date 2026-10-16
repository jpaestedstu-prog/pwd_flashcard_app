import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_clip_quality.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/readability.dart';

/// Settings > Data > Sign videos: the three choices, which one is on, and
/// that a tap changes it. A friend's phone froze on the full-HD sign videos;
/// this row is where a learner or an educator overrides the automatic
/// choice for the device.
///
/// The choice is kept in memory here: a Hive write started from a widget
/// test holds up every later box operation in the file. The stored side is
/// test/fsl_quality_choice_test.dart.

/// Stubs [profileProvider] so the Settings screen builds without
/// `ProfileNotifier.build`'s Firebase remote-changes stream.
class _StubProfileNotifier extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

class _MemoryChoice extends FslQualityChoiceNotifier {
  @override
  FslQualityChoice build() => FslQualityChoice.auto;

  @override
  Future<void> set(FslQualityChoice choice) async => state = choice;
}

const _en = (
  title: 'Sign videos',
  auto: 'Automatic',
  light: 'Smaller',
  full: 'Sharpest',
);
const _fil = (
  title: 'Mga video ng senyas',
  auto: 'Awtomatiko',
  light: 'Mas maliit',
  full: 'Pinakamalinaw',
);

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/sign_video_setting');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    // The Settings screen's Cloud Sync tile reads the sync-queue box.
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  /// Opens Settings at [size] and [scale] and scrolls the Sign videos row
  /// into the middle of the screen.
  Future<ProviderContainer> pumpRow(
    WidgetTester tester, {
    Size size = const Size(360, 640),
    double scale = 1.0,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(_StubProfileNotifier.new),
      fslQualityChoiceProvider.overrideWith(_MemoryChoice.new),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();

    // Finders skip what is built but scrolled out of view, so scroll until
    // the buttons themselves are on screen, then bring the title back near
    // the top: the whole setting shows at once.
    final strings = locale.languageCode == 'fil' ? _fil : _en;
    // At 2.0x the list runs past the default 50 steps.
    await tester.scrollUntilVisible(
      find.text(strings.full),
      120,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 400,
    );
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text(strings.title, skipOffstage: false)),
      alignment: 0.05,
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> unmount(WidgetTester tester) async {
    // Let the section headers' entrance animations finish first, or their
    // one-shot timers outlive the tree.
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('offers Automatic, Smaller and Sharpest, with Automatic on',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRow(tester);

    expect(
      tester.getSemantics(find.bySemanticsLabel('Set sign videos to Automatic')),
      isSemantics(isButton: true, isSelected: true),
    );
    for (final other in [_en.light, _en.full]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel('Set sign videos to $other')),
        isSemantics(isButton: true, isSelected: false),
      );
    }
    expect(
      find.text('Smaller, faster videos on phones and mobile data; '
          'the sharpest on tablets with Wi-Fi'),
      findsOneWidget,
    );

    await unmount(tester);
    semantics.dispose();
  });

  testWidgets('a tap on Smaller chooses it, and the line under the title '
      'says what it means', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pumpRow(tester);

    await tester.tap(find.bySemanticsLabel('Set sign videos to Smaller'));
    await tester.pumpAndSettle();

    expect(container.read(fslQualityChoiceProvider), FslQualityChoice.light);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Set sign videos to Smaller')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Set sign videos to Automatic')),
      isSemantics(isSelected: false),
    );
    expect(
      find.text(
          'Always the smaller videos: they start at once and use little data'),
      findsOneWidget,
    );

    await unmount(tester);
    semantics.dispose();
  });

  testWidgets('a tap on the row itself steps through the three choices',
      (tester) async {
    final container = await pumpRow(tester);

    final seen = <FslQualityChoice>[];
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(_en.title));
      await tester.pumpAndSettle();
      seen.add(container.read(fslQualityChoiceProvider));
    }
    expect(seen, [
      FslQualityChoice.light,
      FslQualityChoice.full,
      FslQualityChoice.auto,
    ]);

    await unmount(tester);
  });

  // The three buttons share a phone's width, and the Filipino labels are
  // long single words ("Pinakamalinaw"): at large text a plain label breaks
  // inside the word, which no overflow check can see.
  for (final locale in const [Locale('en'), Locale('fil')]) {
    final strings = locale.languageCode == 'fil' ? _fil : _en;
    for (final (device, size) in const [
      ('phone', Size(360, 640)),
      ('sideways phone', Size(640, 360)),
      ('tablet', Size(800, 1280)),
    ]) {
      for (final scale in const [1.0, 1.4, 2.0]) {
        testWidgets(
            'the row reads whole on a $device at ${scale}x '
            '(${locale.languageCode})', (tester) async {
          await pumpRow(tester, size: size, scale: scale, locale: locale);

          expect(tester.takeException(), isNull);
          final labels = {strings.auto, strings.light, strings.full};
          final issues = findReadabilityIssues(tester, checkEllipsis: true)
              .where((i) => labels.contains(i.text))
              .toList();
          expect(issues, isEmpty,
              reason: 'Sign videos buttons on a $device at ${scale}x '
                  '(${locale.languageCode}):\n  ${issues.join('\n  ')}');

          await unmount(tester);
        });
      }
    }
  }
}
