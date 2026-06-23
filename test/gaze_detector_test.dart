import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';

Face _face(Rect box) =>
    Face(boundingBox: box, landmarks: const {}, contours: const {});

void main() {
  group('faceSignalFromAngles', () {
    test('marks the signal as having a face', () {
      expect(faceSignalFromAngles().hasFace, isTrue);
    });

    test('front-camera mirror flips yaw so user-right is positive', () {
      // ML Kit raw yaw is mirrored on the front camera; default un-mirrors it.
      final s = faceSignalFromAngles(rawEulerY: -20);
      expect(s.headTurn, 20); // now positive → user looking right
    });

    test('mirrorHorizontal:false leaves yaw untouched', () {
      final s = faceSignalFromAngles(rawEulerY: -20, mirrorHorizontal: false);
      expect(s.headTurn, -20);
    });

    test('invertVertical flips pitch when requested', () {
      expect(faceSignalFromAngles(rawEulerX: 15).headTilt, 15);
      expect(
        faceSignalFromAngles(rawEulerX: 15, invertVertical: true).headTilt,
        -15,
      );
    });

    test('missing eye probabilities default to open (1.0)', () {
      final s = faceSignalFromAngles();
      expect(s.leftEyeOpen, 1.0);
      expect(s.rightEyeOpen, 1.0);
    });

    test('passes through real eye probabilities', () {
      final s = faceSignalFromAngles(leftEyeOpen: 0.1, rightEyeOpen: 0.2);
      expect(s.leftEyeOpen, 0.1);
      expect(s.rightEyeOpen, 0.2);
    });
  });

  group('largestFace', () {
    test('returns null for no faces', () {
      expect(largestFace(const []), isNull);
    });

    test('picks the face with the biggest bounding box', () {
      final small = _face(const Rect.fromLTWH(0, 0, 10, 10));
      final big = _face(const Rect.fromLTWH(0, 0, 100, 80));
      final medium = _face(const Rect.fromLTWH(0, 0, 50, 50));
      expect(largestFace([small, big, medium]), same(big));
    });

    test('returns the only face when there is one', () {
      final only = _face(const Rect.fromLTWH(0, 0, 30, 30));
      expect(largestFace([only]), same(only));
    });
  });
}
