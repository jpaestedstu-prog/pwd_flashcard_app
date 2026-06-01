import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/survey/models/smileyometer_models.dart';
import 'package:pwdpwdpwd/features/survey/models/survey_models.dart';
import 'package:pwdpwdpwd/features/survey/services/smileyometer_service.dart';

void main() {
  group('SmileyometerResult', () {
    test('meanRating averages the face ratings', () {
      final r = SmileyometerResult(
        id: '1',
        profileId: 'p',
        completedAt: DateTime(2026),
        ratings: const [1, 2, 3],
      );
      expect(r.meanRating, 2.0);
    });

    test('meanRating is 0 with no ratings', () {
      final r = SmileyometerResult(
        id: '1',
        profileId: 'p',
        completedAt: DateTime(2026),
        ratings: const [],
      );
      expect(r.meanRating, 0);
    });

    test('fromJson clamps ratings to 1..3', () {
      final r = SmileyometerResult.fromJson({
        'id': '1',
        'profileId': 'p',
        'completedAt': DateTime(2026).toIso8601String(),
        'ratings': [0, 5, 2],
      });
      expect(r.ratings, [1, 3, 2]);
    });

    test('toJson/fromJson round-trips', () {
      final r = SmileyometerResult(
        id: 'abc',
        profileId: 'p7',
        completedAt: DateTime(2026, 6, 1, 10, 30),
        ratings: const [3, 2, 3],
      );
      final restored = SmileyometerResult.fromJson(r.toJson());
      expect(restored.id, 'abc');
      expect(restored.profileId, 'p7');
      expect(restored.completedAt, DateTime(2026, 6, 1, 10, 30));
      expect(restored.ratings, [3, 2, 3]);
    });
  });

  group('SmileyometerService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('smiley_test');
      Hive.init(tempDir.path);
      await Hive.openBox('progress');
    });

    tearDown(() async {
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('save then get round-trips per profile', () async {
      final result =
          SmileyometerService.createResult(profileId: 'p1', ratings: [3, 2, 3]);
      await SmileyometerService.saveResult(result);

      final got = SmileyometerService.getResults('p1');
      expect(got.length, 1);
      expect(got.first.ratings, [3, 2, 3]);
      expect(SmileyometerService.hasCompleted('p1'), isTrue);
      expect(SmileyometerService.hasCompleted('p2'), isFalse);
      expect(SmileyometerService.getAllResults().length, 1);
    });
  });

  group('SUS Filipino scale anchors', () {
    test('has 5 distinct anchors with the correct Strongly Disagree', () {
      const labels = SusQuestions.scaleLabelsFilipino;
      expect(labels.length, 5);
      expect(labels.first, 'Lubos na Hindi Sang-ayon');
      expect(labels.toSet().length, 5, reason: 'anchors must be distinct');
    });
  });
}
