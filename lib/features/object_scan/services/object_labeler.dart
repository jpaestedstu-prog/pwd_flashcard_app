import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/object_scan_models.dart';

/// On-device image labeler behind a small interface so the scan screen can
/// be widget-tested with a fake (the real one needs platform channels).
abstract class ObjectLabeler {
  /// Labels a captured photo on disk. ML Kit reads the file at full
  /// resolution and applies its EXIF rotation itself.
  Future<List<RecognizedLabel>> labelPhoto(String filePath);

  Future<void> close();
}

/// ML Kit implementation using the bundled base model — runs fully offline.
///
/// The default threshold is deliberately high: Word Hunt only ever shows
/// vocabulary words that are really in the photo, so low-confidence guesses
/// (the "phantom cat" problem) are dropped before mapping.
class MlKitObjectLabeler implements ObjectLabeler {
  MlKitObjectLabeler({double confidenceThreshold = 0.70})
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
        );

  final ImageLabeler _labeler;

  @override
  Future<List<RecognizedLabel>> labelPhoto(String filePath) async {
    final labels = await _labeler.processImage(InputImage.fromFilePath(filePath));
    return [
      for (final l in labels)
        RecognizedLabel(label: l.label, confidence: l.confidence),
    ];
  }

  @override
  Future<void> close() => _labeler.close();
}
