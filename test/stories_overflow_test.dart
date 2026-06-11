import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/responsive_utils.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/stories/widgets/story_cover_card.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the Stories grid. The real `StoryListScreen`
/// lays the cover cards in a grid whose cells have a **fixed height**
/// (`mainAxisExtent`), grown — but capped — by the Font Size setting. That cap
/// is exactly where the card's bottom text block (title + Filipino subtitle +
/// difficulty/read-time chips) can outgrow the cell, so the test reproduces the
/// same cell geometry the screen uses and renders every seed story in it.
///
/// `kidMode` cards are bigger and simpler; both modes are exercised because the
/// cell height and the card's internal layout differ between them.

/// Mirrors `StoryListScreen`'s cell height formula so the test stresses the
/// real worst case rather than an arbitrary box.
double _cardHeight(BuildContext context, {required bool kid}) =>
    context.scaledHeightCapped(
      kid
          ? context.responsiveTier(phone: 220.0, tablet: 240.0, large: 260.0)
          : context.responsiveTier(phone: 198.0, tablet: 210.0, large: 224.0),
    );

Widget _storyGrid(BuildContext context, {required bool kid}) {
  final stories = SeedStories.all;
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.symmetric(horizontal: context.pagePadding),
    itemCount: stories.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: kid ? (context.isTablet ? 2 : 1) : context.gridColumns,
      mainAxisExtent: _cardHeight(context, kid: kid),
      crossAxisSpacing: context.gridSpacing,
      mainAxisSpacing: context.gridSpacing,
    ),
    itemBuilder: (context, index) {
      final story = stories[index];
      // Vary the badge/lock states so locked, read and starred variants all
      // get laid out at every size × scale.
      return StoryCoverCard(
        story: story,
        unlocked: index % 4 != 0,
        read: index.isEven,
        stars: index % 4,
        kidMode: kid,
        onTap: () {},
      );
    },
  );
}

void main() {
  testWidgets('Story cover grid (normal) survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (context) => _storyGrid(context, kid: false),
      // The grid is vertically-growing page content inside the screen's scroll
      // view, so a scrollable host matches real usage — we care that no *cell*
      // overflows, not that the whole grid exceeds one screen.
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('Story cover grid (kid mode) survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (context) => _storyGrid(context, kid: true),
      host: LayoutHost.scrollable,
    );
  });
}
