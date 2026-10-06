import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/stories/widgets/story_cover_card.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

/// A locked story cover used to do nothing at all when chosen — on the tablet
/// a learner picking one with a switch could not tell a lock from a press
/// that went nowhere. It now says what opens it, and still never opens.
class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

void main() {
  Widget host(Widget card) => ProviderScope(
    overrides: [settingsProvider.overrideWith(_StubAppSettings.new)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: SizedBox(width: 320, height: 220, child: card)),
      ),
    ),
  );

  testWidgets('a locked cover says what opens it, and does not open',
      (tester) async {
    var opened = 0;
    var hinted = 0;
    await tester.pumpWidget(host(StoryCoverCard(
      story: SeedStories.all.first,
      unlocked: false,
      onTap: () => opened++,
      onLockedTap: () => hinted++,
    )));
    await tester.tap(find.byType(StoryCoverCard));
    expect(hinted, 1);
    expect(opened, 0);
  });

  testWidgets('an open cover opens, and gives no hint', (tester) async {
    var opened = 0;
    var hinted = 0;
    await tester.pumpWidget(host(StoryCoverCard(
      story: SeedStories.all.first,
      unlocked: true,
      onTap: () => opened++,
      onLockedTap: () => hinted++,
    )));
    await tester.tap(find.byType(StoryCoverCard));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opened, 1);
    expect(hinted, 0);
  });

  test('the hint counts the words still to learn, in English and Filipino',
      () {
    final en = AppLocalizationsEn();
    expect(en.storyUnlockHint(1), 'Learn 1 more word to open this story');
    expect(en.storyUnlockHint(7), 'Learn 7 more words to open this story');
    final fil = AppLocalizationsFil();
    expect(fil.storyUnlockHint(7), contains('7'));
    expect(fil.storyUnlockHint(7), isNot(contains('Learn')));
  });
}
