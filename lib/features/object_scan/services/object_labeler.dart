import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

import '../models/object_scan_models.dart';

/// On-device image labeler behind a small interface so the scan screen can
/// be widget-tested with a fake (the real one needs platform channels).
abstract class ObjectLabeler {
  Future<List<RecognizedLabel>> labelImage(InputImage image);
  Future<void> close();
}

/// ML Kit implementation using the bundled base model — runs fully offline.
class MlKitObjectLabeler implements ObjectLabeler {
  MlKitObjectLabeler({double confidenceThreshold = 0.55})
      : _labeler = ImageLabeler(
          options: ImageLabelerOptions(confidenceThreshold: confidenceThreshold),
        );

  final ImageLabeler _labeler;

  @override
  Future<List<RecognizedLabel>> labelImage(InputImage image) async {
    final labels = await _labeler.processImage(image);
    return [
      for (final l in labels)
        RecognizedLabel(label: l.label, confidence: l.confidence),
    ];
  }

  @override
  Future<void> close() => _labeler.close();
}

/// Maps the device orientation reported by the camera controller to the
/// clockwise degrees the frame must be rotated for ML Kit.
const Map<DeviceOrientation, int> _orientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Converts a streamed [CameraImage] (requested as NV21 on Android) into an
/// ML Kit [InputImage]. Returns null for frame formats the labeler cannot
/// consume — callers just skip those frames.
InputImage? inputImageFromCameraImage(
  CameraImage image, {
  required CameraDescription camera,
  required DeviceOrientation deviceOrientation,
}) {
  final compensation = _orientationDegrees[deviceOrientation];
  if (compensation == null) return null;
  final int rotationDegrees;
  if (camera.lensDirection == CameraLensDirection.front) {
    rotationDegrees = (camera.sensorOrientation + compensation) % 360;
  } else {
    rotationDegrees = (camera.sensorOrientation - compensation + 360) % 360;
  }
  final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (rotation == null || format != InputImageFormat.nv21) return null;
  if (image.planes.length != 1) return null;

  final plane = image.planes.first;
  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}
