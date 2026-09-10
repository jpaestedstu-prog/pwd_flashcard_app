import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/widgets/animated_score_reveal.dart';

/// The perfect-score hint has to match the activity.
///
/// A story quiz has no difficulty setting, so "Try a harder level next!" sent
/// the reader looking for a control that does not exist. Games keep the
/// original wording — the regression risk of the fix is that it changes the
/// hint everywhere, so both directions are pinned.
void main() {
  Widget host({required bool hasLevels}) => MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AnimatedScoreReveal(
            score: 6,
            total: 6,
            rating: 3,
            starsEarned: 3,
            hasLevels: hasLevels,
            onPlayAgain: () {},
            onExit: () {},
          ),
        ),
      );

  testWidgets('a game invites the learner to move up a level', (tester) async {
    await tester.pumpWidget(host(hasLevels: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('harder level'), findsOneWidget);
  });

  testWidgets('an activity with no levels praises the result instead',
      (tester) async {
    await tester.pumpWidget(host(hasLevels: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('harder level'), findsNothing);
    expect(find.textContaining('every question right'), findsOneWidget);
  });
}
