import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show UserProfile;
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, profileProvider;

import 'support/all_screens.dart' show openMemoryBoxes;
import 'support/app_harness.dart';
import 'support/real_fonts.dart';

/// On a phone with Android's Display Size at Largest (about 320 wide) the five
/// controls under a flashcard wrapped onto three rows and the two language
/// buttons stacked, and the card itself was left a thin strip. A learner who
/// signs has the most controls there, so that is who this test is.
class _Learner extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'viewer-row',
    name: 'Ana',
    role: UserRole.student,
    disabilityType: DisabilityType.hearing,
    createdAt: DateTime(2026),
  );
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('viewer_row');
    await ActionClipService.load();
  });

  // One test, not one per size: the viewer starts a save that outlives a
  // test, and the next test in this file would wait on it for ever.
  testWidgets('all five controls stay on one row and the card keeps its word', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final old = FlutterError.onError;
    FlutterError.onError = (d) {};
    try {
      for (final size in const [
        Size(320, 568),
        Size(320, 711),
        Size(360, 640),
        // Sideways, where the controls sit in a panel beside the card: the
        // Villaon at its largest Display size (they wrapped there, 9 Nov),
        // at its owner's Display size, and an ordinary phone.
        Size(711, 320),
        Size(941, 423),
        Size(640, 360),
      ]) {
        for (final scale in const [1.0, 1.5]) {
          final where =
              '${size.width.round()}x${size.height.round()} at ${scale}x';
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [profileProvider.overrideWith(_Learner.new)],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: harnessBuilder(textScale: scale),
                home: const FlashcardViewerScreen(
                  category: FlashcardCategory.animals,
                ),
              ),
            ),
          );
          for (var t = 0; t < 25; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }

          final controls = ['Previous', 'FSL', 'Show Me', 'Flip', 'Next'];
          final rows = {
            for (final c in controls) tester.getCenter(find.text(c)).dy.round(),
          };
          expect(rows.length, 1, reason: '$where: the controls are on one row');
          expect(
            tester.getCenter(find.text('English')).dy,
            closeTo(tester.getCenter(find.text('Filipino')).dy, 1),
            reason: '$where: the language buttons are side by side',
          );

          // The card still has room for its word, at a size that can be read.
          final word = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byType(FlashcardViewerScreen),
              matching: find.text('Dog'),
            ),
          );
          final drawn = MatrixUtils.transformRect(
            word.getTransformTo(null),
            Offset.zero & word.size,
          );
          expect(drawn.height, greaterThan(26), reason: '$where: the word');

          await tester.pumpWidget(const SizedBox());
          for (var t = 0; t < 5; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
      }
    } finally {
      FlutterError.onError = old;
    }
  });
}
