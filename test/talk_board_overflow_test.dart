import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/communication_board/models/saved_phrase.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/board_template_builder_screen.dart';
import 'package:pwdpwdpwd/features/communication_board/screens/communication_board_screen.dart';

import 'support/board_test_doubles.dart';
import 'support/screen_matrix.dart';

/// Overflow matrix for Talk Board.
///
/// Run per accessibility type, because `BoardPresentation` changes the layout:
/// a cognitive board is two columns of six tiles with a banner, a Player's is
/// three columns of eight without one, and they burst at different sizes. The
/// grid used to overflow by 24 px on a 7" tablet at the 2.0x accessibility
/// font scale — a fixed `childAspectRatio` against a label that grows.
///
/// No Hive writes: the phrase store is in memory and only the first frame is
/// pumped.

/// A learner who has used the board before, so the saved-phrase strip is
/// actually on screen and counted against the header's height budget.
FakeBoardPhraseStore _usedBefore() => FakeBoardPhraseStore([
      SavedPhrase(
        id: 'n01+p01',
        tileIds: const ['n01', 'p01'],
        lastUsedAt: DateTime(2026, 3, 30),
        pinned: true,
      ),
      SavedPhrase(
        id: 'n02+d01+r08',
        tileIds: const ['n02', 'd01', 'r08'],
        lastUsedAt: DateTime(2026, 3, 29),
      ),
    ]);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Hive.init('./build/test_cache/talk_board_overflow');
    for (final name in const ['profiles', 'settings', 'progress', 'sessions']) {
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

  for (final type in DisabilityType.values) {
    testWidgets('Talk Board survives the device matrix — ${type.name}',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const CommunicationBoardScreen(),
        overrides: [
          ...boardProfileOverrides(disability: type),
          overrideBoardPhrases(_usedBefore(), now: () => DateTime(2026, 4)),
        ],
      );
    });

    // Again with a board of their own: the extra tab is one more chip in the
    // strip and its tiles are uncapped, so it is a different first frame.
    testWidgets('Talk Board + a custom tab survives the matrix — ${type.name}',
        (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => const CommunicationBoardScreen(),
        overrides: [
          ...boardProfileOverrides(disability: type),
          overrideBoardPhrases(_usedBefore(), now: () => DateTime(2026, 4)),
          overrideCustomBoard(
            FakeCustomBoardStore(sampleCustomBoard(name: 'Bahay ni Ana')),
            now: () => DateTime(2026, 4),
          ),
        ],
      );
    });
  }

  testWidgets('Talk Board survives the device matrix — Player', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const CommunicationBoardScreen(),
      overrides: [
        ...boardProfileOverrides(role: UserRole.player),
        overrideBoardPhrases(_usedBefore(), now: () => DateTime(2026, 4)),
      ],
    );
  });

  testWidgets('Talk Board survives the device matrix — Child', (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const CommunicationBoardScreen(),
      overrides: [
        ...boardProfileOverrides(
          role: UserRole.child,
          disability: DisabilityType.multiple,
        ),
        overrideBoardPhrases(_usedBefore(), now: () => DateTime(2026, 4)),
      ],
    );
  });

  // The board builder, reached from Talk Board's app bar. It burst at 14 px on
  // a landscape phone before the compact rule.
  testWidgets('BoardTemplateBuilderScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const BoardTemplateBuilderScreen(),
      overrides: boardProfileOverrides(role: UserRole.teacher),
    );
  });

  // With a board already loaded the header carries a row of chips instead of
  // the empty-state hint, which is the taller of the two first frames.
  testWidgets('BoardTemplateBuilderScreen with a loaded board survives it too',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const BoardTemplateBuilderScreen(),
      overrides: [
        ...boardProfileOverrides(role: UserRole.teacher),
        overrideCustomBoard(
          FakeCustomBoardStore(sampleCustomBoard()),
          now: () => DateTime(2026, 4),
        ),
      ],
    );
  });
}
