import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/stories/widgets/story_fsl_button.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/fsl_video_sheet.dart';

/// Behaviour parity: the Stories FSL button must now mirror Flashcards →
/// Cards → FSL. Both resolve a clip and then present the shared
/// [showFslVideoSheet] / [showFslUnavailableSheet] surfaces — a modal bottom
/// sheet — rather than (as Stories used to) jumping straight to the fullscreen
/// player and falling back to a SnackBar.
///
/// The success path needs a real downloadable clip, so it isn't exercised
/// here. The unavailable path is fully offline: a blank [pageUrl] makes
/// `FslAssetsService.videoSourceForUrl` return null without any network or
/// Hive work, which lets us assert the bottom-sheet fallback deterministically.
void main() {
  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            // Blank URL → resolves to null with no network/Hive, exercising
            // the "unavailable" branch.
            child: StoryFslButton(
              square: true,
              pageUrl: '',
              cacheKey: 'test_story_fsl',
              label: 'Apple',
              secondaryLabel: 'Mansanas',
              color: Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'tapping the Stories FSL button surfaces the shared unavailable sheet, '
    'not a SnackBar',
    (tester) async {
      await pumpButton(tester);

      await tester.tap(find.text('FSL'));
      await tester.pumpAndSettle();

      // Same friendly bottom sheet Flashcards → Cards → FSL shows.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        find.text('No FSL video available yet for "Apple".'),
        findsOneWidget,
      );
      // The old Stories behaviour (a SnackBar) must be gone.
      expect(find.byType(SnackBar), findsNothing);
    },
  );
}
