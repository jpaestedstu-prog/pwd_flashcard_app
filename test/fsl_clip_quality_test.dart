import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/fsl_clip_quality.dart';

/// Which copy of a sign clip a device plays, and the order its sources are
/// tried in. A friend's phone froze on the full-HD originals (1080p at 60
/// frames a second, 8 MB each) or never started them; phones now get the
/// light copies of the same recordings.
void main() {
  group('chooseFslClipQuality (the automatic choice)', () {
    test('a phone gets the light copies, whatever else is true', () {
      expect(
        chooseFslClipQuality(
          isPhone: true,
          decodesFullHd60: true,
          metered: false,
        ),
        FslClipQuality.light,
      );
    });

    test('a tablet on Wi-Fi that decodes 1080p60 keeps the originals', () {
      expect(
        chooseFslClipQuality(
          isPhone: false,
          decodesFullHd60: true,
          metered: false,
        ),
        FslClipQuality.full,
      );
    });

    test('a tablet whose decoder is not rated for 1080p60 gets light', () {
      expect(
        chooseFslClipQuality(isPhone: false, decodesFullHd60: false),
        FslClipQuality.light,
      );
    });

    test('a low-memory (Android Go) device gets light', () {
      expect(
        chooseFslClipQuality(
          isPhone: false,
          decodesFullHd60: true,
          lowRam: true,
        ),
        FslClipQuality.light,
      );
    });

    test('a metered connection (mobile data, a hotspot) gets light', () {
      expect(
        chooseFslClipQuality(
          isPhone: false,
          decodesFullHd60: true,
          metered: true,
        ),
        FslClipQuality.light,
      );
    });

    test('unknown facts alone never force the light copies on a tablet', () {
      expect(
        chooseFslClipQuality(isPhone: false),
        FslClipQuality.full,
      );
    });
  });

  group('FslQualityChoice.parse', () {
    test('reads the stored names back', () {
      for (final c in FslQualityChoice.values) {
        expect(FslQualityChoice.parse(c.name), c);
      }
    });

    test('anything else is automatic', () {
      expect(FslQualityChoice.parse(null), FslQualityChoice.auto);
      expect(FslQualityChoice.parse('hd'), FslQualityChoice.auto);
      expect(FslQualityChoice.parse(3), FslQualityChoice.auto);
    });
  });

  group('fslClipPlan (the order sources are tried in)', () {
    const light = 'https://site/assets/videos/fsl/dog.mp4';
    const download = 'https://github.com/x/releases/download/v1/animals__dog.mp4';
    const stream = 'https://res.cloudinary.com/x/video/upload/DOG.mp4';

    test('light: the light copy, then the 720p twin, then the original', () {
      expect(
        fslClipPlan(
          quality: FslClipQuality.light,
          light: light,
          download: download,
          stream: stream,
        ),
        const [
          FslClipSource(light, FslClipQuality.light),
          FslClipSource(stream, FslClipQuality.full, resolve: true),
          FslClipSource(download, FslClipQuality.full),
        ],
      );
    });

    test('full: the original, its twin, and the light copy last', () {
      expect(
        fslClipPlan(
          quality: FslClipQuality.full,
          light: light,
          download: download,
          stream: stream,
        ),
        const [
          FslClipSource(download, FslClipQuality.full),
          FslClipSource(stream, FslClipQuality.full, resolve: true),
          FslClipSource(light, FslClipQuality.light),
        ],
      );
    });

    test('a sign without a light copy still plays its own sources, '
        'the smaller one first when light is wanted', () {
      expect(
        fslClipPlan(
          quality: FslClipQuality.light,
          download: download,
          stream: stream,
        ),
        const [
          FslClipSource(stream, FslClipQuality.full, resolve: true),
          FslClipSource(download, FslClipQuality.full),
        ],
      );
    });

    test('blank and missing sources are left out', () {
      expect(
        fslClipPlan(quality: FslClipQuality.full, light: '', download: download),
        const [FslClipSource(download, FslClipQuality.full)],
      );
      expect(fslClipPlan(quality: FslClipQuality.light), isEmpty);
    });
  });
}
