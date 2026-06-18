import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/responsive_utils.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/progress/theme/progress_layout.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/category_progress_row.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/progress_stat_card.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/progress_stat_grid.dart';
import 'package:pwdpwdpwd/widgets/enhanced_category_card.dart';
import 'package:pwdpwdpwd/widgets/rich_empty_states.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow regression suite for the high-reuse, layout-critical
/// shared widgets. Each case renders across [kTabletMatrix] (7"→10"+ tablets,
/// both orientations, plus phones) × [kTextScales] (1.0 / 1.3 / 2.0) and
/// asserts no `RenderFlex` overflow or other layout exception is thrown.
///
/// See [test/support/device_matrix.dart] for the harness.

/// A dense-ish layout so the grid has to pack several stats per row — the
/// classic place a fixed `Row` of cards overflows on a narrow tablet.
const _layout = ProgressLayout(
  id: 'test',
  displayName: 'Test',
  emoji: '🧪',
  blurb: 'test layout',
  sectionGap: 16,
  cardPadding: EdgeInsets.all(16),
  statColumnsPhone: 2,
  statColumnsTablet: 4,
  heroScale: 1.0,
);

void main() {
  setUpAll(() async {
    // RichEmptyState/EnhancedCategoryCard embed the 3D motion kit, which
    // reads the reduced-motion setting from the Hive-backed settingsProvider.
    Hive.init('./build/test_cache/overflow_matrix');
    if (!Hive.isBoxOpen('settings')) await Hive.openBox('settings');
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('ProgressStatCard survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: ProgressStatCard(
          icon: Icons.local_fire_department_rounded,
          label: 'Longest Streak This Semester',
          value: '99999',
          suffix: '/ 99999 days',
          color: Colors.orange,
        ),
      ),
    );
  });

  testWidgets('A 3-card stats Row survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: ProgressStatCard(
                icon: Icons.local_fire_department_rounded,
                label: 'Streak',
                value: '365',
                suffix: 'days',
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ProgressStatCard(
                icon: Icons.star_rounded,
                label: 'Stars Earned',
                value: '12480',
                color: Colors.amber,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ProgressStatCard(
                icon: Icons.menu_book_rounded,
                label: 'Words Mastered',
                value: '518',
                suffix: '/ 1000',
                color: Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  });

  testWidgets('CategoryProgressRow with a long label survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: CategoryProgressRow(
          icon: Icons.category_rounded,
          label: 'A very long category name that would otherwise overflow on '
              'a narrow tablet in portrait at a large font scale',
          color: Colors.green,
          mastered: 3,
          total: 10,
          percent: 0.3,
        ),
      ),
    );
  });

  testWidgets('ProgressStatGrid packs many stats without overflow',
      (tester) async {
    final stats = List.generate(
      5,
      (i) => ProgressStat(
        icon: Icons.star_rounded,
        label: 'Metric Number ${i + 1}',
        value: '${(i + 1) * 1111}',
        suffix: '/ 9999',
        color: Colors.primaries[i % Colors.primaries.length],
      ),
    );
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: ProgressStatGrid(stats: stats, layout: _layout),
      ),
      // The grid is vertically-growing page content that lives inside the
      // Progress screen's scroll view, so test it in a scrollable host: we
      // care that it never overflows *horizontally*, not that 3 rows of cards
      // exceed a phone's height (which scrolling resolves).
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('EnhancedCategoryCard in a grid cell survives the device matrix',
      (tester) async {
    // Category cards are laid out in a GridView whose cells have a fixed
    // aspect ratio — the height a cell gets is derived from its width, so a
    // narrow tablet column at 2.0x font is the classic place the card's inner
    // Column overflows. Reproduce a single grid cell at the app's tablet
    // category-card aspect ratio.
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Center(
        child: SizedBox(
          width: 220,
          height: 180,
          child: EnhancedCategoryCard(
            category: FlashcardCategory.familyAndGreetings,
            wordCount: 24,
            progress: 0.66,
            onTap: () {},
          ),
        ),
      ),
    );
  });

  testWidgets(
      'Home Vocabulary Categories grid survives the device matrix',
      (tester) async {
    // Renders the real Home "Vocabulary Categories" grid: every category at
    // the production cell height (context.categoryTileHeight()) and the real
    // responsive column count. This covers the tightest real cell — the narrow
    // 2-up phone column — end to end, not just a single representative box,
    // so a regression in the helper or the card's inner layout is caught.
    await expectNoOverflowAcrossDevices(
      tester,
      (context) {
        final width = MediaQuery.sizeOf(context).width;
        final columns = width >= 1200
            ? 4
            : width >= 600
                ? 3
                : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: context.categoryTileHeight(),
          ),
          itemCount: FlashcardCategory.values.length,
          itemBuilder: (context, i) => EnhancedCategoryCard(
            category: FlashcardCategory.values[i],
            wordCount: 24,
            progress: 0.66,
            onTap: () {},
          ),
        );
      },
      // A grid of every category grows vertically and lives in a scrolling
      // page, so a scrollable host matches real usage and isolates horizontal
      // RenderFlex overflow from expected vertical growth.
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('RichEmptyState survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const RichEmptyState(
        emoji: '📭',
        title: 'No items yet',
        description: 'When you add your first item it will appear here so '
            'you can track it across every lesson and session.',
        actionLabel: 'Get started',
        actionIcon: Icons.add_rounded,
      ),
      // Empty states center themselves in available space and are placed
      // inside scrolling pages, so a scrollable host matches real usage.
      host: LayoutHost.scrollable,
    );
  });
}
