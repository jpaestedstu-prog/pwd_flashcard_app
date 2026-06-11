import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_template_picker_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/enhanced_create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/flashcard_viewer_screen.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/hard_words_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// Overflow matrix for the core flashcard screens (deck list, card viewer,
/// hard-words list, create-card form). Each is rendered at its first frame
/// across every tablet size × orientation × accessibility font scale and
/// asserted to lay out without an overflow.

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/flashcard_screens');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
  });

  tearDownAll(() async => Hive.deleteFromDisk());

  testWidgets('DeckListScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(tester, () => const DeckListScreen());
  });

  testWidgets('HardWordsScreen survives the device matrix', (tester) async {
    await expectScreenNoOverflowAcrossDevices(tester, () => const HardWordsScreen());
  });

  testWidgets('FlashcardViewerScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const FlashcardViewerScreen(
        category: FlashcardCategory.familyAndGreetings,
      ),
    );
  });

  testWidgets('CreateFlashcardScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const CreateFlashcardScreen(),
    );
  });

  testWidgets('EnhancedCreateFlashcardScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const EnhancedCreateFlashcardScreen(),
    );
  });

  testWidgets('DeckTemplatePickerScreen survives the device matrix',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => const DeckTemplatePickerScreen(),
    );
  });

  // The viewer's card *back* (English↔Filipino, listen buttons, example
  // sentence) only renders once the card is flipped, so the first-frame matrix
  // can't reach it. Flip it at the most punishing viewports and assert the back
  // lays out without overflow.
  testWidgets('FlashcardViewer card back (flipped) never overflows',
      (tester) async {
    const punishing = <DeviceSize>[
      DeviceSize('phone landscape', Size(640, 360), devicePixelRatio: 3.0),
      DeviceSize('7" landscape', Size(960, 600)),
    ];
    for (final device in punishing) {
      for (final scale in <double>[1.0, 2.0]) {
        tester.view.physicalSize = device.size * device.devicePixelRatio;
        tester.view.devicePixelRatio = device.devicePixelRatio;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const FlashcardViewerScreen(
                category: FlashcardCategory.familyAndGreetings,
              ),
            ),
          ),
        );
        await tester.pump();

        // Tap the card to flip it, then let the 650 ms flip animation finish.
        await tester.tap(find.byType(PageView));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        Object? firstError;
        for (Object? e = tester.takeException();
            e != null;
            e = tester.takeException()) {
          firstError ??= e;
        }
        expect(
          firstError,
          isNull,
          reason: 'Card back overflow at $device, textScale ${scale}x:'
              '\n$firstError',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
