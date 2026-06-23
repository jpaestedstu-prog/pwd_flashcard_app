import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';

void main() {
  group('GazeSettings defaults', () {
    test('sensible, conservative defaults', () {
      const s = GazeSettings();
      expect(s.enabled, isFalse); // opt-in
      expect(s.sensitivity, 3);
      expect(s.dwellMs, 1500);
      expect(s.blinkEnabled, isTrue);
      expect(s.mirrorHorizontal, isTrue);
      expect(s.invertVertical, isFalse);
      expect(s.dwellDuration, const Duration(milliseconds: 1500));
      expect(s.scanMode, isFalse);
      expect(s.scanStepMs, 2000);
      expect(s.scanStepDuration, const Duration(milliseconds: 2000));
      // D-pad reach defaults to bottom-nav only, so existing behaviour is
      // unchanged until the learner opts into the Home tiles.
      expect(s.navScope, GazeNavScope.bottomNav);
      expect(s.navHomeTiles, isFalse);
    });
  });

  group('nav scope (Bottom nav + Home tiles)', () {
    test('navHomeTiles reflects the chosen scope', () {
      const combined =
          GazeSettings(navScope: GazeNavScope.bottomNavAndHomeTiles);
      expect(combined.navHomeTiles, isTrue);
    });

    test('round-trips and unknown / missing values fall back to bottom-nav', () {
      const s = GazeSettings(navScope: GazeNavScope.bottomNavAndHomeTiles);
      final restored = GazeSettings.fromMap(s.toMap());
      expect(restored.navScope, GazeNavScope.bottomNavAndHomeTiles);

      // Older blob without the key, and a corrupt value → default.
      expect(GazeSettings.fromMap({'enabled': true}).navScope,
          GazeNavScope.bottomNav);
      expect(GazeSettings.fromMap({'navScope': 'nonsense'}).navScope,
          GazeNavScope.bottomNav);
    });
  });

  group('scan fallback settings', () {
    test('scanStepMs clamps to its range', () {
      expect(const GazeSettings().copyWith(scanStepMs: 100).scanStepMs,
          GazeSettings.minScanStepMs);
      expect(const GazeSettings().copyWith(scanStepMs: 99999).scanStepMs,
          GazeSettings.maxScanStepMs);
    });

    test('scan fields round-trip and missing keys fall back', () {
      const s = GazeSettings(scanMode: true, scanStepMs: 1500);
      final restored = GazeSettings.fromMap(s.toMap());
      expect(restored.scanMode, isTrue);
      expect(restored.scanStepMs, 1500);
      // Older blob without scan keys → defaults.
      final legacy = GazeSettings.fromMap({'enabled': true});
      expect(legacy.scanMode, isFalse);
      expect(legacy.scanStepMs, 2000);
    });
  });

  group('sensitivity → threshold mapping', () {
    test('higher sensitivity yields smaller thresholds (easier to trigger)', () {
      const low = GazeSettings(sensitivity: 1);
      const high = GazeSettings(sensitivity: 5);
      expect(low.turnThresholdDeg, greaterThan(high.turnThresholdDeg));
      expect(low.tiltThresholdDeg, greaterThan(high.tiltThresholdDeg));
    });

    test('endpoints match the documented degrees', () {
      expect(const GazeSettings(sensitivity: 1).turnThresholdDeg, 20);
      expect(const GazeSettings(sensitivity: 5).turnThresholdDeg, 8);
      expect(const GazeSettings(sensitivity: 1).tiltThresholdDeg, 16);
      expect(const GazeSettings(sensitivity: 5).tiltThresholdDeg, 6);
    });

    test('mid sensitivity sits between the endpoints', () {
      const mid = GazeSettings(); // default sensitivity 3
      expect(mid.turnThresholdDeg, inInclusiveRange(8, 20));
      expect(mid.tiltThresholdDeg, inInclusiveRange(6, 16));
    });
  });

  group('copyWith clamps to valid ranges', () {
    test('sensitivity clamped 1..5', () {
      expect(const GazeSettings().copyWith(sensitivity: 99).sensitivity, 5);
      expect(const GazeSettings().copyWith(sensitivity: -3).sensitivity, 1);
    });

    test('dwellMs clamped to min/max', () {
      expect(const GazeSettings().copyWith(dwellMs: 100).dwellMs,
          GazeSettings.minDwellMs);
      expect(const GazeSettings().copyWith(dwellMs: 99999).dwellMs,
          GazeSettings.maxDwellMs);
    });

    test('unchanged fields are preserved', () {
      const s = GazeSettings(blinkEnabled: false, mirrorHorizontal: false);
      final c = s.copyWith(sensitivity: 4);
      expect(c.blinkEnabled, isFalse);
      expect(c.mirrorHorizontal, isFalse);
      expect(c.sensitivity, 4);
    });
  });

  group('serialization', () {
    test('round-trips through toMap/fromMap', () {
      const s = GazeSettings(
        enabled: true,
        sensitivity: 4,
        dwellMs: 2000,
        blinkEnabled: false,
        mirrorHorizontal: false,
        invertVertical: true,
      );
      final restored = GazeSettings.fromMap(s.toMap());
      expect(restored.enabled, isTrue);
      expect(restored.sensitivity, 4);
      expect(restored.dwellMs, 2000);
      expect(restored.blinkEnabled, isFalse);
      expect(restored.mirrorHorizontal, isFalse);
      expect(restored.invertVertical, isTrue);
    });

    test('null map → defaults', () {
      final s = GazeSettings.fromMap(null);
      expect(s.sensitivity, const GazeSettings().sensitivity);
      expect(s.enabled, isFalse);
    });

    test('missing / wrong-typed keys fall back to defaults', () {
      final s = GazeSettings.fromMap({'sensitivity': 'oops', 'enabled': 1});
      expect(s.sensitivity, 3); // bad string → default
      expect(s.enabled, isFalse); // non-bool → default
    });

    test('numeric (double) values are coerced and clamped', () {
      final s = GazeSettings.fromMap({'sensitivity': 4.0, 'dwellMs': 99999.0});
      expect(s.sensitivity, 4);
      expect(s.dwellMs, GazeSettings.maxDwellMs);
    });
  });
}
