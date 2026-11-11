import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_hub_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import '../../support/real_fonts.dart';

/// The Category Mastery cards on the Assessment Center keep their words
/// readable on the narrowest phone at the largest Font Size.
///
/// Under each category's name a card says "Not tested" or its best score. On
/// a 320 dp phone at 1.5x text, the Filipino "Hindi pa nasusubok" ran to three
/// lines as plain text, splitting "nasusubo / k", and the cell, sized for one
/// line of it, left the name above it one line of room: FitText drew every
/// name at 8 px (10 Nov, the UI survey, which until then had never seen these
/// cards: they were still waiting out their entrance when it measured).
///
/// Real fonts: the test font draws every glyph a full em wide, which would
/// shrink these words in the test whatever the layout.

class _Learner extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'mastery-text-learner',
    name: 'Test Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
  );
}

/// The size [paragraph] is drawn at on screen: its font size, its text
/// scale, and any squeeze applied above it (FitText's last resort).
double _drawnSize(RenderParagraph paragraph) {
  final span = paragraph.text;
  final size = (span is TextSpan ? span.style?.fontSize : null) ?? 14;
  final shown = MatrixUtils.transformRect(
    paragraph.getTransformTo(null),
    Offset.zero & paragraph.size,
  );
  return size *
      paragraph.textScaler.scale(1.0) *
      (shown.width / paragraph.size.width);
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    const cacheDir = './build/test_cache/mastery_card_text_size';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray process: Hive will say so below.
    }
    Hive.init(cacheDir);
    for (final name in const ['profiles', 'progress', 'settings']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  const views = {
    'a 320 dp phone': Size(320, 568),
    'a 360 dp phone': Size(360, 640),
    'the Villaon': Size(423, 941),
  };

  for (final locale in const ['fil', 'en']) {
    for (final MapEntry(key: label, value: view) in views.entries) {
      testWidgets(
        'the cards read at 11 px or more: $label, 1.5x text, $locale',
        (tester) async {
          tester.view.physicalSize = view;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final router = GoRouter(
            initialLocation: '/assessment',
            routes: [
              GoRoute(
                path: '/assessment',
                builder: (_, _) => const AssessmentHubScreen(),
              ),
            ],
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [profileProvider.overrideWith(_Learner.new)],
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                locale: Locale(locale),
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 2));

          final cards = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_CategoryMasteryCard',
          );
          final scroll = find.byType(CustomScrollView).first;
          final checked = <String>{};
          final small = <String>[];
          // Down the page a screen at a time: the grid is built as it scrolls
          // in, so every card is measured once it is on screen.
          for (var step = 0; step < 40; step++) {
            for (final card in cards.evaluate()) {
              for (final text in find
                  .descendant(
                    of: find.byElementPredicate((e) => identical(e, card)),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
                final paragraph = text.renderObject! as RenderParagraph;
                if (!paragraph.attached || !paragraph.hasSize) continue;
                final words = paragraph.text.toPlainText();
                if (!checked.add(words)) continue;
                final drawn = _drawnSize(paragraph);
                if (drawn < 11) {
                  small.add('"$words" at ${drawn.toStringAsFixed(1)} px');
                }
              }
            }
            final position = tester
                .state<ScrollableState>(
                  find.descendant(of: scroll, matching: find.byType(Scrollable)),
                )
                .position;
            if (position.pixels >= position.maxScrollExtent) break;
            position.jumpTo(
              (position.pixels + position.viewportDimension * 0.8).clamp(
                0.0,
                position.maxScrollExtent,
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));
          }

          expect(
            checked,
            isNotEmpty,
            reason: 'no Category Mastery card was found on the page',
          );
          expect(small, isEmpty, reason: 'text drawn below 11 px: $small');
        },
      );
    }
  }
}
