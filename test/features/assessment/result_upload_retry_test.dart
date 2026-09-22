import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';

/// A test finished with no signal used to stay on the learner's tablet until
/// the next pull happened to run — the educator saw "Pending" until the
/// learner left and reopened the app. Now a missed upload starts a pull,
/// which pushes whatever the cloud is missing and keeps retrying while
/// offline (see `LearnerAssignmentSync`).
///
/// Plain `test()` against real Hive: saving a result writes.
class _Cloud extends AssessmentCloudService {
  const _Cloud({required this.uploads});
  final bool uploads;

  @override
  Future<bool> saveResult(String learnerId, AssessmentResult result) async =>
      uploads;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('result_upload_retry');
    Hive.init(dir.path);
    await Hive.openBox('progress', compactionStrategy: (_, _) => false);
  });

  tearDown(() async {
    await Hive.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  AssessmentResult result() => AssessmentResult(
    id: 'r1',
    assessmentId: 'a1',
    profileId: 'learner-1',
    type: AssessmentType.preTest,
    score: 3,
    totalQuestions: 5,
    answers: const [],
    completedAt: DateTime(2026, 9, 22),
    durationSeconds: 60,
  );

  test('a missed upload asks for a pull', () async {
    var pulls = 0;
    final notifier = AssessmentResultsNotifier(
      'learner-1',
      cloud: const _Cloud(uploads: false),
      onUploadMissed: () => pulls++,
    );
    await notifier.saveResult(result());
    expect(pulls, 1);
    notifier.dispose();
  });

  test('an upload that went through does not', () async {
    var pulls = 0;
    final notifier = AssessmentResultsNotifier(
      'learner-1',
      cloud: const _Cloud(uploads: true),
      onUploadMissed: () => pulls++,
    );
    await notifier.saveResult(result());
    expect(pulls, 0);
    notifier.dispose();
  });
}
