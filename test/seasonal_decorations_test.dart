import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/seasonal_events.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/seasonal_event_provider.dart';
import 'package:pwdpwdpwd/widgets/seasonal_decorations.dart';

/// Keeps `settingsProvider` off Hive — the widget only reads `reducedMotion`.
class _FixedSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

/// Seasonal confetti must decorate the screen without eating the words on it.
///
/// The particle layer is painted *over* whatever screen it decorates, so at
/// full strength a flag or a flower lands on a label and takes a letter with
/// it — the home tile read "Playe🎊Profile" on the tablet, and a flag sat on
/// the XP counter. Legibility is the one thing this app cannot trade away.
void main() {
  final event = SeasonalEvents.allEvents.first;

  Widget host({bool showBanner = true, bool showParticles = true}) {
    return ProviderScope(
      overrides: [
        seasonalEventProvider.overrideWithValue(event),
        settingsProvider.overrideWith(_FixedSettings.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              const Center(child: Text('Player Profile')),
              SeasonalDecorations(
                showBanner: showBanner,
                showParticles: showParticles,
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('particles never paint at full opacity over content', (
    tester,
  ) async {
    await tester.pumpWidget(host(showBanner: false));
    await tester.pump();

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<EmojiParticlePainter>()
        .toList();

    expect(
      painters,
      isNotEmpty,
      reason: 'the particle layer should be painted while an event is active',
    );
    for (final painter in painters) {
      expect(
        painter.opacity,
        lessThan(1.0),
        reason: 'opaque confetti obscures the label underneath it',
      );
      expect(painter.opacity, greaterThan(0.0));
    }
  });

  testWidgets('the decoration layer never swallows a tap', (tester) async {
    // The particles cover the whole screen; if they took pointers, every tile
    // under them would go dead.
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seasonalEventProvider.overrideWithValue(event),
          settingsProvider.overrideWith(_FixedSettings.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: ElevatedButton(
                    onPressed: () => tapped = true,
                    child: const Text('Player Profile'),
                  ),
                ),
                const SeasonalDecorations(showBanner: false),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Player Profile'));
    expect(tapped, isTrue);
  });

  testWidgets('text under the decorations still renders', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump();

    expect(find.text('Player Profile'), findsOneWidget);
  });

  testWidgets('the banner takes its own space instead of covering content', (
    tester,
  ) async {
    // As an overlay the banner sat on the first row of home tiles and stayed
    // there while the page scrolled underneath, so "Assessments", "Learning",
    // "My Portfolio" and "My Goals" were unreadable until it was dismissed.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seasonalEventProvider.overrideWithValue(event),
          settingsProvider.overrideWith(_FixedSettings.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: SeasonalBannerStrip()),
                SliverToBoxAdapter(
                  child: SizedBox(height: 80, child: Text('Assessments')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bannerBottom = tester.getRect(find.text(event.name)).bottom;
    final tileTop = tester.getRect(find.text('Assessments')).top;

    expect(
      tileTop,
      greaterThanOrEqualTo(bannerBottom),
      reason: 'the first tile must start below the banner, not underneath it',
    );
  });

  testWidgets('the banner can still be dismissed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          seasonalEventProvider.overrideWithValue(event),
          settingsProvider.overrideWith(_FixedSettings.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SeasonalBannerStrip()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(event.name), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text(event.name), findsNothing);
  });

  testWidgets('no event means no decoration at all', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [seasonalEventProvider.overrideWithValue(null)],
        child: const MaterialApp(
          home: Scaffold(body: SeasonalDecorations()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byType(CustomPaint).evaluate().map(
        (e) => (e.widget as CustomPaint).painter,
      ),
      isNot(contains(isA<EmojiParticlePainter>())),
    );
  });
}
