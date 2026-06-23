import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/blink_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/dwell_tracker.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_zone_resolver.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';

void main() {
  group('resolveGazeZone', () {
    test('no face → none', () {
      expect(resolveGazeZone(FaceSignal.absent), GazeZone.none);
    });

    test('resting head (small angles) → none', () {
      const s = FaceSignal(hasFace: true, headTurn: 3, headTilt: 2);
      expect(resolveGazeZone(s), GazeZone.none);
    });

    test('clear look right / left maps to right / left', () {
      expect(
        resolveGazeZone(const FaceSignal(hasFace: true, headTurn: 25)),
        GazeZone.right,
      );
      expect(
        resolveGazeZone(const FaceSignal(hasFace: true, headTurn: -25)),
        GazeZone.left,
      );
    });

    test('clear look up / down maps to up / down', () {
      expect(
        resolveGazeZone(const FaceSignal(hasFace: true, headTilt: 25)),
        GazeZone.up,
      );
      expect(
        resolveGazeZone(const FaceSignal(hasFace: true, headTilt: -25)),
        GazeZone.down,
      );
    });

    test('dominant axis wins when both clear the threshold', () {
      // Horizontal magnitude larger (in threshold units) → horizontal wins.
      const horizontalDominant =
          FaceSignal(hasFace: true, headTurn: 40, headTilt: 12);
      expect(resolveGazeZone(horizontalDominant), GazeZone.right);

      // Vertical magnitude clearly larger → vertical wins.
      const verticalDominant =
          FaceSignal(hasFace: true, headTurn: 13, headTilt: 40);
      expect(resolveGazeZone(verticalDominant), GazeZone.up);
    });

    test('a single axis past threshold engages even if the other is at rest',
        () {
      expect(
        resolveGazeZone(const FaceSignal(hasFace: true, headTurn: 20, headTilt: 1)),
        GazeZone.right,
      );
    });

    test('custom thresholds are respected', () {
      const s = FaceSignal(hasFace: true, headTurn: 8);
      expect(resolveGazeZone(s), GazeZone.none); // below default 12°
      expect(
        resolveGazeZone(s, turnThresholdDeg: 5),
        GazeZone.right, // above the lowered 5°
      );
    });

    test('zero threshold is guarded (never selects)', () {
      const s = FaceSignal(hasFace: true, headTurn: 30, headTilt: 30);
      expect(resolveGazeZone(s, turnThresholdDeg: 0, tiltThresholdDeg: 0),
          GazeZone.none);
    });
  });

  group('DwellTracker', () {
    test('fills progress and fires exactly once after the dwell duration', () {
      final tracker = DwellTracker(dwellDuration: const Duration(seconds: 1));
      var t = Duration.zero;

      // First frame on a zone: progress 0, not selected.
      var r = tracker.update(GazeZone.right, t);
      expect(r.progress, 0);
      expect(r.justSelected, isFalse);

      // Halfway through the dwell.
      t = const Duration(milliseconds: 500);
      r = tracker.update(GazeZone.right, t);
      expect(r.progress, closeTo(0.5, 0.001));
      expect(r.justSelected, isFalse);

      // At the dwell duration: fires once.
      t = const Duration(milliseconds: 1000);
      r = tracker.update(GazeZone.right, t);
      expect(r.progress, 1.0);
      expect(r.justSelected, isTrue);

      // Still holding: progress pinned at 1, does NOT fire again.
      t = const Duration(milliseconds: 1500);
      r = tracker.update(GazeZone.right, t);
      expect(r.progress, 1.0);
      expect(r.justSelected, isFalse);
    });

    test('changing zones resets progress and re-arms selection', () {
      final tracker = DwellTracker(dwellDuration: const Duration(seconds: 1));
      tracker.update(GazeZone.right, Duration.zero);
      var r = tracker.update(GazeZone.left, const Duration(milliseconds: 200));
      expect(r.zone, GazeZone.left);
      expect(r.progress, 0);

      r = tracker.update(GazeZone.left, const Duration(milliseconds: 1200));
      expect(r.justSelected, isTrue);
    });

    test('none never accumulates dwell', () {
      final tracker = DwellTracker(dwellDuration: const Duration(seconds: 1));
      tracker.update(GazeZone.none, Duration.zero);
      final r = tracker.update(GazeZone.none, const Duration(seconds: 5));
      expect(r.progress, 0);
      expect(r.justSelected, isFalse);
    });

    test('looking away and back re-fires (edge-triggered)', () {
      final tracker = DwellTracker(dwellDuration: const Duration(seconds: 1));
      tracker.update(GazeZone.up, Duration.zero);
      expect(tracker.update(GazeZone.up, const Duration(seconds: 1)).justSelected,
          isTrue);
      // Look away…
      tracker.update(GazeZone.none, const Duration(milliseconds: 1100));
      // …and back: dwell starts over and fires again.
      tracker.update(GazeZone.up, const Duration(milliseconds: 1200));
      expect(
        tracker.update(GazeZone.up, const Duration(milliseconds: 2200)).justSelected,
        isTrue,
      );
    });

    test('reset clears in-flight dwell', () {
      final tracker = DwellTracker(dwellDuration: const Duration(seconds: 1));
      tracker.update(GazeZone.down, Duration.zero);
      tracker.reset();
      final r = tracker.update(GazeZone.down, const Duration(milliseconds: 900));
      expect(r.progress, 0); // timer restarted from the reset
      expect(r.justSelected, isFalse);
    });
  });

  group('BlinkDetector', () {
    test('fires once after both eyes held shut past the hold duration', () {
      final blink = BlinkDetector(holdDuration: const Duration(milliseconds: 500));
      expect(blink.update(0.1, 0.1, Duration.zero), isFalse);
      expect(
        blink.update(0.1, 0.1, const Duration(milliseconds: 300)),
        isFalse,
      );
      expect(
        blink.update(0.1, 0.1, const Duration(milliseconds: 500)),
        isTrue,
      );
      // Still shut: does not re-fire.
      expect(
        blink.update(0.1, 0.1, const Duration(milliseconds: 800)),
        isFalse,
      );
    });

    test('one eye open does not count as a blink', () {
      final blink = BlinkDetector(holdDuration: const Duration(milliseconds: 500));
      blink.update(0.1, 0.9, Duration.zero);
      expect(
        blink.update(0.1, 0.9, const Duration(milliseconds: 800)),
        isFalse,
      );
    });

    test('re-arms after eyes reopen', () {
      final blink = BlinkDetector(holdDuration: const Duration(milliseconds: 500));
      blink.update(0.1, 0.1, Duration.zero);
      expect(
        blink.update(0.1, 0.1, const Duration(milliseconds: 500)),
        isTrue,
      );
      // Reopen…
      blink.update(0.9, 0.9, const Duration(milliseconds: 600));
      // …blink again.
      blink.update(0.1, 0.1, const Duration(milliseconds: 700));
      expect(
        blink.update(0.1, 0.1, const Duration(milliseconds: 1200)),
        isTrue,
      );
    });

    test('missing classification (defaults to open) never blinks', () {
      final blink = BlinkDetector();
      // FaceSignal defaults eyes to 1.0 when ML Kit cannot classify them.
      const s = FaceSignal(hasFace: true);
      expect(
        blink.update(s.leftEyeOpen, s.rightEyeOpen, const Duration(seconds: 5)),
        isFalse,
      );
    });
  });
}
