import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/hard_words_screen.dart';
import 'package:pwdpwdpwd/features/games/screens/game_hub_screen.dart';
import 'package:pwdpwdpwd/features/stories/screens/story_list_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/readability.dart';

/// Readability matrix — the companion to the 24 overflow suites.
///
/// Those suites ask "does the content burst its box?". This one asks "can the
/// learner still read it?", which is a different question with a different
/// answer. The Games hub passed every overflow test in the repo while rendering
/// "Pronunciat / ion Practi…" to the Visual Impairment preset, because nothing
/// overflowed — the text fit its box perfectly and was simply unreadable.
///
/// The scales matter more than the viewports here. Every readability defect
/// found on the device existed **only** above 1.0x, so a matrix that tests the
/// default scale alone would have reported the hub as clean.
class _StubProfile extends ProfileNotifier {
  _StubProfile(this.role, this.type);

  final UserRole role;
  final DisabilityType type;

  @override
  UserProfile? build() => UserProfile(
        id: 'readability-profile',
        name: 'Test User',
        role: role,
        disabilityType: type,
        createdAt: DateTime(2026),
      );
}

/// The device this app is built for, plus the narrowest phone it supports —
/// column width is what decides whether a long word can fit at all.
const _viewports = <(String, Size)>[
  ('7" portrait (the tablet)', Size(600, 960)),
  ('phone portrait', Size(360, 640)),
];

/// 1.4 is the Visual Impairment preset. 2.0 is the OS maximum the app clamps
/// its own product to, so it is the widest any glyph ever gets.
const _scales = <double>[1.0, 1.4, 2.0];

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/readability_matrix');
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
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  Future<void> pumpHub(
    WidgetTester tester, {
    required DisabilityType type,
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider
              .overrideWith(() => _StubProfile(UserRole.student, type)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const GameHubScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Unmounts and flushes the mascot's repeating blink timer so no test ends
  /// with a live timer.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required Size size,
    required double scale,
  }) async {
    tester.view.physicalSize = size * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(
            () => _StubProfile(UserRole.student, DisabilityType.visual),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump();
  }

  /// The other card-shaped learner surfaces. The Games hub was found by eye;
  /// these are checked so the same defect cannot be sitting on a screen nobody
  /// happened to screenshot at 1.4x.
  group('other learner surfaces stay readable', () {
    final screens = <String, Widget Function()>{
      'Deck list': () => const DeckListScreen(),
      'Hard words': () => const HardWordsScreen(),
      'Story list': () => const StoryListScreen(),
    };

    for (final entry in screens.entries) {
      for (final (label, size) in _viewports) {
        for (final scale in _scales) {
          testWidgets('${entry.key} · $label · ${scale}x', (tester) async {
            await pumpScreen(tester, entry.value(), size: size, scale: scale);
            expectReadable(tester, at: '${entry.key} on $label at ${scale}x');
            await unmount(tester);
          });
        }
      }
    }
  });

  group('Games hub stays readable', () {
    for (final type in DisabilityType.values) {
      for (final (label, size) in _viewports) {
        for (final scale in _scales) {
          testWidgets(
            '${type.profileTypeLabel} · $label · ${scale}x',
            (tester) async {
              await pumpHub(tester, type: type, size: size, scale: scale);
              expectReadable(
                tester,
                at: '${type.profileTypeLabel} on $label at ${scale}x',
              );
              await unmount(tester);
            },
          );
        }
      }
    }
  });
}
