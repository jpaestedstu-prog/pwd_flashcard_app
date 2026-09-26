import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/cloud_sync_outcome.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/deleted_learner_cleanup.dart';
import 'package:pwdpwdpwd/features/assessment/services/shared_media_sweep.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_media_store.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_service.dart';

/// Shared files are removed when what they belong to is: a profile's own
/// uploads when it is deleted, the feedback and routines an educator made
/// for a learner who deleted their profile, and a routine's files when the
/// routine goes — never a file something else still uses.

class _MemoryBackend implements SharedMediaBackend {
  final Map<String, SharedMediaMeta> metas = {};
  final Map<String, Uint8List> chunks = {};

  @override
  Future<void> writeMeta(SharedMediaMeta meta) async => metas[meta.id] = meta;
  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async =>
      chunks['$id/$index'] = Uint8List.fromList(bytes);
  @override
  Future<SharedMediaMeta?> readMeta(String id) async => metas[id];
  @override
  Future<Uint8List?> readChunk(String id, int index) async =>
      chunks['$id/$index'];
  @override
  Future<void> deleteChunk(String id, int index) async =>
      chunks.remove('$id/$index');
  @override
  Future<void> deleteMeta(String id) async => metas.remove(id);
  @override
  Future<List<String>> idsOwnedBy(String ownerProfileId) async => [
    for (final m in metas.values)
      if (m.ownerProfileId == ownerProfileId) m.id,
  ];
}

late Directory _root;
late _MemoryBackend _backend;

Future<String> _share(String owner, String name) async {
  final f = File('${_root.path}${Platform.pathSeparator}$name');
  await f.writeAsString('bytes of $name');
  final result = await const SharedMediaService().upload(
    f,
    ownerProfileId: owner,
    ext: 'jpg',
  );
  return result.value!;
}

bool _inCloud(String value) =>
    _backend.metas.containsKey(SharedMediaService.idOf(value));

AssessmentAssignment _assignment(
  String id,
  List<String> learners, {
  Map<String, AssessmentFeedback> feedback = const {},
}) => AssessmentAssignment(
  id: id,
  assessmentId: 'a-$id',
  assessmentTitle: 'Test $id',
  assignedBy: 'teacher-1',
  studentIds: learners,
  assignedAt: DateTime(2026, 9, 20),
  feedback: feedback,
);

Routine _routine(String id, String child, {String photo = ''}) => Routine(
  id: id,
  childProfileId: child,
  setterProfileId: 'teacher-1',
  setterRole: UserRole.teacher,
  name: 'Morning',
  steps: [
    RoutineStep(
      id: 's-$id',
      activity: RoutineActivity.values.first,
      photoUrl: photo,
    ),
  ],
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
);

void main() {
  setUp(() async {
    _root = await Directory.systemTemp.createTemp('orphan_cleanup');
    _backend = _MemoryBackend();
    SharedMediaService.debugBackend = _backend;
    SharedMediaService.debugDirectory = () async => _root;
    RoutineMediaStore.debugDirectory = () async => _root;
  });

  tearDown(() async {
    SharedMediaService.debugBackend = null;
    SharedMediaService.debugDirectory = null;
    RoutineMediaStore.debugDirectory = null;
    RoutineService.debugSharedInUse = null;
    DeletedLearnerCleanup.debugMissingProfiles = null;
    DeletedLearnerCleanup.debugRoutines = null;
    DeletedLearnerCleanup.debugPolicyLearners = null;
    DeletedLearnerCleanup.debugForgetLearner = null;
    if (await _root.exists()) await _root.delete(recursive: true);
  });

  // ─── A deleted profile's own files ───────────────────────

  test('deleting a profile\'s files takes every one it shared, and only '
      'those', () async {
    final a1 = await _share('ana', 'a1.jpg');
    final a2 = await _share('ana', 'a2.jpg');
    final b1 = await _share('ben', 'b1.jpg');

    final removed = await const SharedMediaService().deleteAllOwnedBy('ana');

    expect(removed, 2);
    expect(_inCloud(a1), isFalse);
    expect(_inCloud(a2), isFalse);
    expect(_inCloud(b1), isTrue);
    expect(_backend.chunks.keys.where((k) => !k.startsWith(
      SharedMediaService.idOf(b1),
    )), isEmpty, reason: 'their pieces go too');
    // This tablet's copies go as well.
    final left = await Directory(
      '${_root.path}${Platform.pathSeparator}shared_media',
    ).list().map((e) => e.uri.pathSegments.last).toList();
    expect(left.where((n) => n.startsWith(SharedMediaService.idOf(a1))), isEmpty);
  });

  // ─── An educator's side, when a learner is gone ──────────

  group('what an educator made for a learner who is gone', () {
    test('the learner leaves an assignment with others on it, with their '
        'feedback and its files; an assignment left with nobody goes', () {
      final feedbackAna = AssessmentFeedback(
        note: 'Well done',
        media: const AssessmentMedia(photo: 'shared://ana-photo'),
        updatedAt: DateTime(2026, 9, 21),
      );
      final feedbackBen = AssessmentFeedback(
        note: 'Good',
        media: const AssessmentMedia(sign: 'shared://ben-sign'),
        updatedAt: DateTime(2026, 9, 21),
      );
      final plan = DeletedLearnerCleanup.planAssignments([
        _assignment(
          'both',
          ['ana', 'ben'],
          feedback: {'ana': feedbackAna, 'ben': feedbackBen},
        ),
        _assignment('only-ana', ['ana']),
        _assignment('only-ben', ['ben']),
      ], {'ana'});

      expect(plan.update.single.id, 'both');
      expect(plan.update.single.studentIds, ['ben']);
      expect(plan.update.single.feedback.keys, ['ben']);
      expect(plan.remove.single.id, 'only-ana');
      expect(plan.media, {'shared://ana-photo'});
    });

    test('only the routines set for them', () {
      final stale = DeletedLearnerCleanup.routinesFor([
        _routine('r1', 'ana'),
        _routine('r2', 'ben'),
      ], {'ana'});
      expect(stale.map((r) => r.id), ['r1']);
    });

    group('on the educator\'s tablet', () {
      setUpAll(() async {
        const dir = './build/test_cache/orphan_cleanup';
        try {
          final d = Directory(dir);
          if (d.existsSync()) d.deleteSync(recursive: true);
        } catch (_) {}
        Hive.init(dir);
        for (final name in const ['profiles', 'progress', 'routines']) {
          if (!Hive.isBoxOpen(name)) {
            await Hive.openBox(name, compactionStrategy: (_, _) => false);
          }
        }
      });

      tearDownAll(() async {
        await Hive.deleteFromDisk().timeout(
          const Duration(seconds: 15),
          onTimeout: () => <void>[],
        );
      });

      test('clears assignments, feedback files and routines — and keeps a '
          'file a copy for another learner still uses', () async {
        final anaFeedback = await _share('teacher-1', 'fb.jpg');
        final anaRoutinePhoto = await _share('teacher-1', 'step.jpg');
        final sharedWithBen = await _share('teacher-1', 'both.jpg');

        await AssessmentService.saveAssignment(
          'teacher-1',
          _assignment(
            'x',
            ['ana', 'ben'],
            feedback: {
              'ana': AssessmentFeedback(
                media: AssessmentMedia(photo: anaFeedback),
                updatedAt: DateTime(2026, 9, 21),
              ),
            },
          ),
        );
        await AssessmentService.saveAssignment(
          'teacher-1',
          _assignment('y', ['ana']),
        );
        final anaRoutine = _routine('ra', 'ana', photo: anaRoutinePhoto);
        final anaCopy = _routine('rb', 'ana', photo: sharedWithBen);
        final benCopy = _routine('rc', 'ben', photo: sharedWithBen);
        for (final r in [anaRoutine, anaCopy, benCopy]) {
          await HiveService.cacheRoutine(r, cloudSynced: true);
        }

        DeletedLearnerCleanup.debugRoutines = (_) async =>
            [anaRoutine, anaCopy, benCopy];
        DeletedLearnerCleanup.debugMissingProfiles = (ids) async =>
            ids.intersection({'ana'});

        final saved = <AssessmentAssignment>[];
        final deleted = <String>[];
        final result = await const DeletedLearnerCleanup().run(
          'teacher-1',
          saveAssignment: (a) async {
            saved.add(a);
            await AssessmentService.saveAssignment('teacher-1', a);
            return CloudSyncOutcome.synced;
          },
          deleteAssignment: (id) async {
            deleted.add(id);
            return CloudSyncOutcome.synced;
          },
        );

        expect(result.assignments, 2);
        expect(result.routines, 2);
        expect(saved.single.studentIds, ['ben']);
        expect(deleted, ['y']);
        expect(_inCloud(anaFeedback), isFalse, reason: 'feedback file');
        expect(_inCloud(anaRoutinePhoto), isFalse, reason: 'routine file');
        expect(_inCloud(sharedWithBen), isTrue,
            reason: 'Ben\'s copy of the routine still shows it');
        expect(HiveService.getCachedRoutine('ra'), isNull);
        expect(HiveService.getCachedRoutine('rc'), isNotNull);
      });

      test('the sweep deletes only old files nothing refers to', () async {
        final abandoned = await _share('teacher-9', 'lost.jpg');
        final fresh = await _share('teacher-9', 'fresh.jpg');
        final inTest = await _share('teacher-9', 'q.jpg');
        final inRoutine = await _share('teacher-9', 'r.jpg');
        final inCloudRoutine = await _share('teacher-9', 'c.jpg');
        final inResult = await _share('teacher-9', 'v.mp4');

        await AssessmentService.saveAssessment(
          'teacher-9',
          Assessment(
            id: 'sw-a',
            title: 'Sweep',
            type: AssessmentType.custom,
            questions: [
              AssessmentQuestion(
                id: 'q',
                questionText: 'Q',
                correctAnswer: 'A',
                choices: const ['A', 'B'],
                media: AssessmentMedia(photo: inTest),
              ),
            ],
            createdBy: 'teacher-9',
            createdAt: DateTime(2026, 9),
          ),
        );
        await HiveService.cacheRoutine(
          _routine('sw-r', 'kid', photo: inRoutine),
          cloudSynced: true,
        );
        await AssessmentService.saveResult(
          'kid-9',
          AssessmentResult(
            id: 'sw-res',
            assessmentId: 'sw-a',
            profileId: 'kid-9',
            type: AssessmentType.custom,
            score: 0,
            totalQuestions: 0,
            answers: [
              QuestionAnswer(
                questionId: 'v',
                givenAnswer: inResult,
                isCorrect: false,
                responseTimeMs: 1,
                needsReview: true,
              ),
            ],
            completedAt: DateTime(2026, 9, 20),
            durationSeconds: 1,
          ),
        );
        RoutineService.debugSharedInUse = (value, except) async =>
            value == inCloudRoutine;
        final now = DateTime(2026, 9, 26, 12);
        final old = now.subtract(const Duration(days: 2));
        // A photo sent in Messages: named by a message, not by anything the
        // sweep can see, and expired on its own schedule instead.
        final inMessage = await _share('teacher-9', 'message.jpg');
        SharedMediaSweep.debugOwned = (_) async => [
          for (final v in [abandoned, inTest, inRoutine, inCloudRoutine, inResult])
            (id: SharedMediaService.idOf(v), createdAt: old, purpose: null),
          (id: SharedMediaService.idOf(fresh), createdAt: now, purpose: null),
          (
            id: SharedMediaService.idOf(inMessage),
            createdAt: old,
            purpose: SharedMediaMeta.purposeMessage,
          ),
        ];
        addTearDown(() => SharedMediaSweep.debugOwned = null);

        final removed = await const SharedMediaSweep().run(
          'teacher-9',
          now: now,
        );

        expect(removed, 1);
        expect(_inCloud(abandoned), isFalse);
        expect(_inCloud(fresh), isTrue, reason: 'may be an open editor');
        expect(_inCloud(inTest), isTrue);
        expect(_inCloud(inRoutine), isTrue);
        expect(_inCloud(inCloudRoutine), isTrue);
        expect(_inCloud(inResult), isTrue);
        expect(_inCloud(inMessage), isTrue,
            reason: "a message photo is not the sweep's to remove");
      });

      test('the sweep does nothing when this tablet may not hold every '
          'result', () async {
        final orphan = await _share('kid-full', 'x.mp4');
        for (var i = 0; i < AssessmentService.resultsKept; i++) {
          await AssessmentService.saveResult(
            'kid-full',
            AssessmentResult(
              id: 'full-$i',
              assessmentId: 'a',
              profileId: 'kid-full',
              type: AssessmentType.custom,
              score: 1,
              totalQuestions: 1,
              answers: const [],
              completedAt: DateTime(2026, 9).add(Duration(minutes: i)),
              durationSeconds: 1,
            ),
          );
        }
        SharedMediaSweep.debugOwned = (_) async => [
          (
            id: SharedMediaService.idOf(orphan),
            createdAt: DateTime(2026),
            purpose: null,
          ),
        ];
        addTearDown(() => SharedMediaSweep.debugOwned = null);
        expect(await const SharedMediaSweep().run('kid-full'), 0);
        expect(_inCloud(orphan), isTrue);
      });

      test('a gone learner known only by a time limit, alarm, unlock or '
          'routine-day action loses those too — and only a gone one', () async {
        DeletedLearnerCleanup.debugRoutines = (_) async => const [];
        DeletedLearnerCleanup.debugPolicyLearners = (_) async => {
          'cara',
          'dan',
        };
        DeletedLearnerCleanup.debugMissingProfiles = (ids) async =>
            ids.intersection({'cara'});
        final forgotten = <String>[];
        DeletedLearnerCleanup.debugForgetLearner = (setter, learner) async =>
            forgotten.add('$setter/$learner');

        await const DeletedLearnerCleanup().run(
          'teacher-9',
          saveAssignment: (_) async => CloudSyncOutcome.synced,
          deleteAssignment: (_) async => CloudSyncOutcome.synced,
        );

        expect(forgotten, ['teacher-9/cara']);
      });

      test('a learner whose profile is on this tablet is never counted as '
          'gone, and nothing happens when the server cannot say', () async {
        await HiveService.saveProfile(
          UserProfile(
            id: 'local-kid',
            name: 'Local',
            role: UserRole.student,
            createdAt: DateTime(2026),
          ),
        );
        await AssessmentService.saveAssignment(
          'teacher-2',
          _assignment('z', ['local-kid']),
        );
        DeletedLearnerCleanup.debugRoutines = (_) async => const [];
        var asked = <String>{};
        DeletedLearnerCleanup.debugMissingProfiles = (ids) async {
          asked = ids;
          return ids;
        };
        Future<CloudSyncOutcome> refuse(_) async =>
            throw StateError('must not be called');

        final result = await const DeletedLearnerCleanup().run(
          'teacher-2',
          saveAssignment: refuse,
          deleteAssignment: refuse,
        );
        expect(asked, isEmpty);
        expect(result.assignments, 0);

        // Offline: the lookup throws, and nothing is touched.
        await AssessmentService.saveAssignment(
          'teacher-3',
          _assignment('w', ['far-away']),
        );
        DeletedLearnerCleanup.debugMissingProfiles = (_) async =>
            throw const SocketException('offline');
        final offline = await const DeletedLearnerCleanup().run(
          'teacher-3',
          saveAssignment: refuse,
          deleteAssignment: refuse,
        );
        expect(offline.assignments, 0);
      });
    });
  });

  // ─── A routine's own files ───────────────────────────────

  group('a routine\'s files', () {
    test('its shared files are listed on the cloud document', () {
      final r = _routine('r', 'ana', photo: 'shared://p1');
      expect(r.storedMedia, {'shared://p1'});
      expect(r.toJson()['media_refs'], ['shared://p1']);
      expect(_routine('q', 'ana', photo: 'https://x/y.jpg').storedMedia, isEmpty);
    });

    test('a file goes only when no routine here or in the cloud uses it',
        () async {
      const dir = './build/test_cache/orphan_cleanup_routines';
      try {
        final d = Directory(dir);
        if (d.existsSync()) d.deleteSync(recursive: true);
      } catch (_) {}
      Hive.init(dir);
      if (!Hive.isBoxOpen('routines')) {
        await Hive.openBox('routines', compactionStrategy: (_, _) => false);
      }
      addTearDown(() => Hive.close());

      final unused = await _share('teacher-1', 'u.jpg');
      final usedHere = await _share('teacher-1', 'h.jpg');
      final usedInCloud = await _share('teacher-1', 'c.jpg');
      await HiveService.cacheRoutine(
        _routine('other', 'ben', photo: usedHere),
        cloudSynced: true,
      );
      RoutineService.debugSharedInUse = (value, except) async =>
          value == usedInCloud;

      await const RoutineService().discardUnusedMedia(
        {unused, usedHere, usedInCloud},
        exceptRoutineId: 'gone',
      );
      expect(_inCloud(unused), isFalse);
      expect(_inCloud(usedHere), isTrue);
      expect(_inCloud(usedInCloud), isTrue);
    });
  });
}
