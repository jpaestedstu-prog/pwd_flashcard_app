import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/seasonal_events.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/seasonal_event_provider.dart';
import 'package:pwdpwdpwd/widgets/seasonal_decorations.dart';

import 'support/all_screens.dart';
import 'support/readability.dart';
import 'support/real_fonts.dart';

/// Home's holiday banner, for every event of the year: on a 360 dp phone at
/// large text its words stay whole. The page sweeps only meet a banner while
/// an event is on, which is how "Halloween" breaking as "Hallowee / n" went
/// unseen until the last week of October.
void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openSweepBoxes('seasonal_banner_readability');
  });
  tearDownAll(closeSweepBoxes);

  for (final event in SeasonalEvents.allEvents) {
    for (final language in const ['en', 'fil']) {
      for (final scale in const [1.3, 2.0]) {
        testWidgets('${event.id} banner reads whole in $language at ${scale}x',
            (tester) async {
          tester.view.physicalSize = const Size(360, 640) * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(ProviderScope(
            overrides: [
              sweepProfileOverride(UserRole.student),
              seasonalEventProvider.overrideWithValue(event),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(
                body: SingleChildScrollView(child: SeasonalBannerStrip()),
              ),
            ),
          ));
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(SeasonalBannerStrip), findsOneWidget);
          expectReadable(tester, at: '${event.id} $language ${scale}x');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
