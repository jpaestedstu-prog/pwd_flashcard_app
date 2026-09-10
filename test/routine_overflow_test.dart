import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_presentation.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_media.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_step_card.dart';

import 'support/device_matrix.dart';

/// Layout guard for the Routine widgets across the tablet matrix and the
/// accessibility font scales.
///
/// The routine surfaces are unusually exposed to this: a step card stacks a
/// title, a time chip, a duration chip, an FSL chip and up to three media
/// icons on one row, and the learners most likely to be running at 2.0x font
/// are exactly the ones the one-step-at-a-time layouts were designed for.

/// A step with every chip lit at once — the widest a card can get.
const _maximal = RoutineStep(
  id: 'max',
  activity: RoutineActivity.homework,
  hour: 16,
  minute: 0,
  durationMinutes: 45,
  note: 'Finish the Filipino worksheet before starting the maths one',
  photoUrl: 'https://example.test/p.png',
  gifUrl: 'https://example.test/g.gif',
  videoUrl: 'https://example.test/v.mp4',
  audioUrl: 'https://example.test/a.mp3',
);

/// A long Filipino compound — the wrapping case that breaks mid-word in
/// narrow columns if a title is not allowed to wrap.
const _longTitle = RoutineStep(
  id: 'long',
  activity: RoutineActivity.custom,
  title: 'Pagsasaayos ng mga gamit sa silid-aralan pagkatapos ng klase',
  titleFilipino: 'Pagsasaayos ng mga gamit sa silid-aralan pagkatapos ng klase',
  emoji: '🧹',
  hour: 15,
  minute: 30,
  durationMinutes: 20,
);

void main() {
  setUpAll(() async {
    // The cards embed the 3D motion kit, which reads reduced-motion from the
    // Hive-backed settingsProvider; settings are per-profile, so the profiles
    // box is needed too.
    Hive.init('./build/test_cache/routine_overflow');
    for (final name in const ['settings', 'profiles']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  testWidgets('a fully-loaded step card survives every device and font scale',
      (tester) async {
    for (final type in DisabilityType.values) {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => RoutineStepCard(
          step: _maximal,
          done: false,
          isNext: true,
          filipino: false,
          presentation: RoutinePresentation.forType(type),
          hasSigns: true,
          onToggle: () {},
          onOpen: () {},
        ),
        host: LayoutHost.scrollable,
      );
    }
  });

  testWidgets('a long Filipino title wraps rather than overflowing',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => RoutineStepCard(
        step: _longTitle,
        done: false,
        isNext: true,
        filipino: true,
        presentation:
            RoutinePresentation.forType(DisabilityType.cognitive),
        hasSigns: false,
        onToggle: () {},
        onOpen: () {},
      ),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('a completed card survives the matrix too', (tester) async {
    // The strikethrough title and the green fill are a different layout path
    // from the pending one.
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => RoutineStepCard(
        step: _maximal,
        done: true,
        isNext: false,
        filipino: false,
        presentation: RoutinePresentation.forType(DisabilityType.motor),
        hasSigns: true,
        onToggle: () {},
        onOpen: () {},
      ),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('the media placeholder survives the matrix at full width',
      (tester) async {
    for (final kind in RoutineMediaKind.values) {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => RoutineMediaPlaceholder(
          kind: kind,
          stepEmoji: '🪥',
          filipino: true,
        ),
        host: LayoutHost.scrollable,
      );
    }
  });

  testWidgets('the compact placeholder fits its fixed preview cell at every '
      'font scale', (tester) async {
    // The bug this guards: the step editor's "what the learner will see"
    // strip is a row of fixed-size cells, and a fixed height does not grow
    // when the caption inside it wraps to a second line. It overflowed by
    // 30 px the first time a caption wrapped. Rendering the placeholder in a
    // *bounded* box — not a scrollable one — is what makes that visible.
    for (final scale in kTextScales) {
      for (final kind in RoutineMediaKind.values) {
        for (final filipino in const [false, true]) {
          await pumpResponsive(
            tester,
            Center(
              child: SizedBox(
                width: routinePreviewTileWidth(scale),
                height: routinePreviewTileHeight(scale),
                child: RoutineMediaPlaceholder(
                  kind: kind,
                  stepEmoji: '🪥',
                  filipino: filipino,
                  compact: true,
                ),
              ),
            ),
            size: const Size(360, 640),
            textScale: scale,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'compact $kind placeholder overflowed at ${scale}x '
                '(filipino: $filipino)',
          );
        }
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
