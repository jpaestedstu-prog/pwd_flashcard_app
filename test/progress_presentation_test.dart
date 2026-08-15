import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/accessibility_presets.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/progress/models/progress_presentation.dart';

/// The adaptive matrix for the Progress tab, in the same shape as the
/// companion's. Pure policy — no widgets, no Hive — so every category can be
/// checked cheaply and the reasoning stays visible.
void main() {
  ProgressPresentation forType(
    DisabilityType type, {
    AppSettings settings = const AppSettings(),
    bool player = false,
  }) => ProgressPresentation.forProfile(type, settings, isPlayerMode: player);

  group('page length adapts to who is reading it', () {
    test('cognitive and multiple get the short page', () {
      for (final type in const [
        DisabilityType.cognitive,
        DisabilityType.multiple,
      ]) {
        final show = forType(type);
        expect(show.isEssential, isTrue, reason: type.name);
        expect(show.showStarGrid, isFalse);
        expect(show.showLockedAchievements, isFalse);
        expect(show.showWeekly, isFalse);
        expect(show.showChartScreens, isFalse);
        expect(show.maxRecentGames, 5);
      }
    });

    test('visual and motor keep the full page', () {
      // Their barrier is legibility and input, not length — shortening the
      // page would cost them information without removing a barrier.
      for (final type in const [
        DisabilityType.visual,
        DisabilityType.motor,
      ]) {
        final show = forType(type);
        expect(show.isEssential, isFalse, reason: type.name);
        expect(show.showStarGrid, isTrue);
        expect(show.showWeekly, isTrue);
        expect(show.maxRecentGames, 10);
      }
    });

    test('hearing and no-needs keep the full page', () {
      for (final type in const [
        DisabilityType.hearing,
        DisabilityType.none,
      ]) {
        expect(forType(type).isEssential, isFalse, reason: type.name);
      }
    });
  });

  group('the spoken summary follows the modality, not the diagnosis', () {
    // Checked against the real presets rather than hand-made settings, because
    // what matters is what an actual profile of that type ends up with.
    ProgressPresentation withPreset(DisabilityType type) => forType(
      type,
      settings: AccessibilityPresets.presetFor(type),
    );

    test('every category whose preset enables TTS is offered it', () {
      for (final type in DisabilityType.values) {
        if (type == DisabilityType.hearing) continue;
        expect(withPreset(type).speakSummary, isTrue, reason: type.name);
      }
    });

    test('a Deaf learner is not offered a spoken summary', () {
      // Their preset turns TTS off; a button that reads the page aloud is not
      // an accessibility win here, it is noise.
      expect(withPreset(DisabilityType.hearing).speakSummary, isFalse);
    });

    test('visual and multiple keep it even with TTS switched off by hand', () {
      // The ring and the charts have no audible form at all, so for these two
      // the button is the only way the page says anything.
      const ttsOff = AppSettings(ttsEnabled: false);
      expect(
        forType(DisabilityType.visual, settings: ttsOff).speakSummary,
        isTrue,
      );
      expect(
        forType(DisabilityType.multiple, settings: ttsOff).speakSummary,
        isTrue,
      );
      expect(
        forType(DisabilityType.none, settings: ttsOff).speakSummary,
        isFalse,
      );
    });
  });

  group('sign progress leads for the learners it is for', () {
    test('only a hearing profile puts signing first', () {
      for (final type in DisabilityType.values) {
        expect(
          forType(type).signFirst,
          type == DisabilityType.hearing,
          reason: type.name,
        );
      }
    });
  });

  group('player mode', () {
    test('keeps its own progress but not the analytics dashboards', () {
      final show = forType(DisabilityType.none, player: true);
      expect(show.showChartScreens, isFalse);
      // Everything that is genuinely the player's own still shows.
      expect(show.showWeekly, isTrue);
      expect(show.showStarGrid, isTrue);
      expect(show.maxRecentGames, 10);
    });
  });

  group('reduced motion', () {
    test('turns the entrance animations off for every category', () {
      const reduced = AppSettings(reducedMotion: true);
      for (final type in DisabilityType.values) {
        expect(forType(type, settings: reduced).animate, isFalse,
            reason: type.name);
      }
    });

    test('is on by default', () {
      expect(forType(DisabilityType.none).animate, isTrue);
    });
  });
}
