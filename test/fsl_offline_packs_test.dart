import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/flashcards/providers/fsl_offline_packs.dart';
import 'package:pwdpwdpwd/features/flashcards/widgets/fsl_offline_packs_sheet.dart';

import 'support/screen_matrix.dart';

/// Offline sign packs — the feature that decides whether the FSL Dictionary
/// works at all on a classroom connection. Nothing is bundled with the app, so
/// every sign is a download until a pack puts it on disk.

/// A notifier with a fixed, already-scanned state, so the sheet can be laid out
/// without touching the disk cache (whose lookups never resolve inside
/// FakeAsync).
class _StubPacks extends FslOfflinePacksNotifier {
  _StubPacks(this._value);
  final FslOfflinePacksState _value;

  @override
  FslOfflinePacksState build() => _value;

  @override
  Future<void> refresh() async {}
}

FslOfflinePacksState _populated({
  FslPackStatus status = FslPackStatus.idle,
  FlashcardCategory? busy,
  int done = 0,
  int total = 0,
  String label = '',
  int failed = 0,
}) => FslOfflinePacksState(
  status: status,
  busyCategory: busy,
  done: done,
  total: total,
  label: label,
  failed: failed,
  byCategory: {
    for (final c in FlashcardCategory.values)
      c: switch (c) {
        // Actions has no signs recorded at all — the row must offer nothing
        // rather than a download button that can never succeed.
        FlashcardCategory.actions => const FslPackCoverage(),
        // A finished pack, with bytes to give back.
        FlashcardCategory.animals => const FslPackCoverage(
          downloadable: 12,
          ready: 12,
          bytes: 96 * 1024 * 1024,
        ),
        // A pack not started.
        FlashcardCategory.numbers => const FslPackCoverage(downloadable: 12),
        // A half-finished pack.
        _ => const FslPackCoverage(
          downloadable: 12,
          ready: 5,
          bytes: 40 * 1024 * 1024,
        ),
      },
  },
);

Widget _sheetHost(FslOfflinePacksState value) => ProviderScope(
  overrides: [fslOfflinePacksProvider.overrideWith(() => _StubPacks(value))],
  child: const Scaffold(body: FslOfflinePacksSheet()),
);

/// Pumps the sheet tall enough that all 13 category rows are built — the list
/// is lazy, and Actions (the row these tests care about most) is last.
Future<void> _pumpTall(WidgetTester tester, FslOfflinePacksState value) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home: _sheetHost(value)));
  await tester.pump();
}

void main() {
  group('formatPackBytes', () {
    test('reads as a size a teacher can act on', () {
      expect(formatPackBytes(0), '0 MB');
      expect(formatPackBytes(-1), '0 MB');
      expect(formatPackBytes(5 * 1024 * 1024), '5.0 MB');
      // Past 10 MB the decimal is noise on a row of text.
      expect(formatPackBytes(96 * 1024 * 1024), '96 MB');
      expect(formatPackBytes(1536 * 1024 * 1024), '1.5 GB');
    });
  });

  group('FslPackCoverage', () {
    test('a category with no signs recorded is never "complete"', () {
      // Actions' shape today. Complete must mean "everything that exists is
      // here", not "nothing exists", or its row would claim to be saved.
      const none = FslPackCoverage();
      expect(none.isComplete, isFalse);
      expect(none.isEmpty, isTrue);
      expect(none.fraction, 0);
    });

    test('tracks partial and finished packs', () {
      const half = FslPackCoverage(downloadable: 12, ready: 6);
      expect(half.isComplete, isFalse);
      expect(half.isEmpty, isFalse);
      expect(half.fraction, closeTo(0.5, 0.001));

      const full = FslPackCoverage(downloadable: 12, ready: 12);
      expect(full.isComplete, isTrue);
    });
  });

  group('downloadableIn', () {
    setUp(() async {
      FslAssetsService.reset();
      await FslAssetsService.load();
    });
    tearDown(FslAssetsService.reset);

    test('a card can borrow an identical sign from another category', () {
      // "Walk" is one sign, and the seed has it twice: a Transportation card
      // and an Actions verb. The Actions one has no manifest entry of its own,
      // so it borrows — which is why Actions is 1-of-20 covered, not 0.
      final walk = SeedData.allFlashcards.firstWhere(
        (c) =>
            c.category == FlashcardCategory.actions && c.wordEnglish == 'Walk',
      );
      expect(FslAssetsService.hasAnyVideoSource(walk), isTrue);
      expect(
        FslOfflinePacksNotifier.downloadableIn(FlashcardCategory.actions),
        hasLength(1),
      );

      // The borrowed source is the lender's.
      final lender = SeedData.allFlashcards.firstWhere(
        (c) =>
            c.category == FlashcardCategory.transportation &&
            c.wordEnglish == 'Walk',
      );
      expect(
        FslAssetsService.downloadUrlFor(walk),
        FslAssetsService.downloadUrlFor(lender),
      );
    });

    test('offers only words that actually have a sign', () {
      // Actions is the near-total gap: 19 of its 20 verbs have no clip, and the
      // one that works ("Walk") only does so by borrowing Transportation's.
      expect(
        FslOfflinePacksNotifier.downloadableIn(
          FlashcardCategory.actions,
        ).map((c) => c.wordEnglish),
        ['Walk'],
      );
      expect(
        FslOfflinePacksNotifier.downloadableIn(FlashcardCategory.animals),
        hasLength(12),
      );
      // Classroom has 19 seed words but only 12 signs — the pack must size
      // itself to what can be fetched, not to the word count.
      expect(
        FslOfflinePacksNotifier.downloadableIn(FlashcardCategory.classroom),
        hasLength(12),
      );
    });
  });

  group('the packs sheet', () {
    testWidgets('survives the device matrix while idle', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => _sheetHost(_populated()),
      );
    });

    testWidgets('survives the device matrix mid-download', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => _sheetHost(
          _populated(
            status: FslPackStatus.downloading,
            done: 12,
            total: 84,
            label: 'Partly Cloudy',
            failed: 3,
          ),
        ),
      );
    });

    testWidgets('a category with no signs offers no buttons', (tester) async {
      await _pumpTall(tester, _populated());

      expect(find.text('No signs recorded yet'), findsOneWidget);
      // One download button per unfinished category, and Actions is not one of
      // them: 13 categories, minus Animals (complete) and Actions (nothing).
      expect(
        find.byTooltip('Save Actions offline'),
        findsNothing,
        reason: 'a download that can never succeed must not be offered',
      );
      expect(find.byTooltip('Save Animals offline'), findsNothing);
      expect(find.byTooltip('Save Numbers offline'), findsOneWidget);
    });

    testWidgets('a finished pack can be given back but not re-fetched', (
      tester,
    ) async {
      await _pumpTall(tester, _populated());

      expect(find.byTooltip('Remove Animals downloads'), findsOneWidget);
      // Numbers has nothing saved, so there is no space to reclaim.
      expect(find.byTooltip('Remove Numbers downloads'), findsNothing);
    });
  });
}
