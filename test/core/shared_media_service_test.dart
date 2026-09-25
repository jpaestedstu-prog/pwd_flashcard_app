import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_publisher.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_store.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_media_store.dart';

/// Files shared between tablets through Firestore on the free plan.
///
/// The Firestore half is stood in for by [_MemoryBackend] — a map standing
/// in for the `shared_media` collection — so these check the parts that can
/// go wrong on our side: the pieces, putting them back together, refusing a
/// damaged file, cleaning up after a failed upload, and the callers that
/// swap a `file://` value for a `shared://` one. The rules themselves are
/// checked against production by `tool/shared_media_rules_probe.py`.
class _MemoryBackend implements SharedMediaBackend {
  final Map<String, SharedMediaMeta> metas = {};
  final Map<String, Uint8List> chunks = {};

  /// Makes the n-th piece write fail, like a dropped connection.
  int? failOnChunk;

  /// Makes every write fail as the rules would refuse it.
  bool refuse = false;

  int chunkWrites = 0;

  void _guard() {
    if (refuse) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
    }
  }

  @override
  Future<void> writeMeta(SharedMediaMeta meta) async {
    _guard();
    metas[meta.id] = meta;
  }

  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async {
    _guard();
    if (failOnChunk == index) throw const SocketException('dropped');
    chunkWrites++;
    chunks['$id/$index'] = Uint8List.fromList(bytes);
  }

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory device;
  late _MemoryBackend backend;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('shared_media_test');
    device = await Directory('${root.path}/tablet_a').create();
    backend = _MemoryBackend();
    SharedMediaService.debugBackend = backend;
    SharedMediaService.debugDirectory = () async => device;
    AssessmentMediaStore.debugDirectory = () async => device;
  });

  tearDown(() async {
    SharedMediaService.debugBackend = null;
    SharedMediaService.debugDirectory = null;
    AssessmentMediaStore.debugDirectory = null;
    if (await root.exists()) await root.delete(recursive: true);
  });

  /// A file of [length] bytes whose content is its own position, so a
  /// piece reassembled out of order would not match.
  Future<File> fileOf(int length, [String name = 'clip.mp4']) async {
    final f = File('${root.path}/$name');
    await f.writeAsBytes(List<int>.generate(length, (i) => i % 251));
    return f;
  }

  /// Switches to a second tablet: a fresh folder, the same cloud.
  Future<void> otherTablet() async {
    final other = await Directory('${root.path}/tablet_b').create();
    SharedMediaService.debugDirectory = () async => other;
  }

  group('SharedMediaService', () {
    test('a file is stored in pieces under 1 MiB and comes back whole', () async {
      const size = SharedMediaService.chunkBytes * 2 + 123;
      final src = await fileOf(size);
      final progress = <double>[];
      final up = await const SharedMediaService().upload(
        src,
        ownerProfileId: 'teacher-1',
        ext: 'mp4',
        onProgress: progress.add,
      );
      expect(up.ok, isTrue);
      expect(up.value, startsWith(SharedMediaService.prefix));
      final id = SharedMediaService.idOf(up.value!);
      expect(backend.metas[id]!.chunkCount, 3);
      expect(backend.metas[id]!.ready, isTrue);
      for (final bytes in backend.chunks.values) {
        expect(bytes.length, lessThanOrEqualTo(1000000));
      }
      expect(progress.last, 1.0);

      await otherTablet();
      final got = await const SharedMediaService().resolve(up.value!);
      expect(got, isNotNull);
      expect(await got!.readAsBytes(), await src.readAsBytes());
      expect(got.path, endsWith('.mp4'));
    });

    test('the uploading tablet never downloads its own file', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(10),
        ownerProfileId: 't',
        ext: 'jpg',
      );
      backend.chunks.clear(); // the cloud copy is gone...
      final got = await const SharedMediaService().resolve(up.value!);
      expect(got, isNotNull, reason: '...but this tablet kept its own');
    });

    test('a damaged file is refused rather than played as noise', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(SharedMediaService.chunkBytes + 50),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      final id = SharedMediaService.idOf(up.value!);
      backend.chunks['$id/1'] = Uint8List.fromList([9, 9, 9]);
      await otherTablet();
      expect(await const SharedMediaService().resolve(up.value!), isNull);
    });

    test('a file still uploading is not handed out half-written', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(10),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      final id = SharedMediaService.idOf(up.value!);
      final m = backend.metas[id]!;
      backend.metas[id] = SharedMediaMeta(
        id: id,
        ownerProfileId: m.ownerProfileId,
        ext: m.ext,
        size: m.size,
        chunkCount: m.chunkCount,
        sha256: m.sha256,
        ready: false,
      );
      await otherTablet();
      expect(await const SharedMediaService().resolve(up.value!), isNull);
    });

    test('a dropped upload removes the pieces it managed to write', () async {
      backend.failOnChunk = 2;
      final up = await const SharedMediaService().upload(
        await fileOf(SharedMediaService.chunkBytes * 3),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      expect(up.status, SharedUploadStatus.failed);
      await Future<void>.delayed(Duration.zero);
      expect(backend.chunks, isEmpty);
      expect(backend.metas, isEmpty);
    });

    test('a refusal from the rules says so, for good', () async {
      backend.refuse = true;
      final up = await const SharedMediaService().upload(
        await fileOf(10),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      expect(up.status, SharedUploadStatus.notOwner);
    });

    test('over the size cap nothing is written at all', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(SharedMediaService.maxBytes + 1),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      expect(up.status, SharedUploadStatus.tooLarge);
      expect(backend.chunkWrites, 0);
    });

    test('without a cloud it is simply unavailable', () async {
      SharedMediaService.debugBackend = null;
      expect(const SharedMediaService().available, isFalse);
      final up = await const SharedMediaService().upload(
        await fileOf(10),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      expect(up.status, SharedUploadStatus.unavailable);
    });

    test('delete removes the cloud pieces and this tablet’s copy', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(SharedMediaService.chunkBytes + 1),
        ownerProfileId: 't',
        ext: 'mp4',
      );
      await const SharedMediaService().delete(up.value!);
      expect(backend.chunks, isEmpty);
      expect(backend.metas, isEmpty);
      expect(await const SharedMediaService().resolve(up.value!), isNull);
    });
  });

  group('the assessment module shares what it picks', () {
    Future<String> picked(String name, int size) async {
      final src = await fileOf(size, name);
      final adopted = await const AssessmentMediaStore().adopt(
        sourcePath: src.path,
        ownerKey: 'q1',
        kind: AssessmentMediaKind.photo,
      );
      return adopted.value!;
    }

    test('share swaps a picked file for a shared one and drops the copy', () async {
      final value = await picked('cat.png', 100);
      final shared = await const AssessmentMediaStore().share(
        value,
        ownerProfileId: 'teacher-1',
      );
      expect(shared.status, SharedUploadStatus.shared);
      expect(SharedMediaService.isShared(shared.value), isTrue);
      expect(await File(RoutineMediaStore.pathOf(value)).exists(), isFalse);
    });

    test('a file that cannot be shared stays on this tablet, usable', () async {
      final value = await picked('big.mp4', 10);
      backend.failOnChunk = 0;
      final shared = await const AssessmentMediaStore().share(
        value,
        ownerProfileId: 'teacher-1',
      );
      expect(shared.status, SharedUploadStatus.failed);
      expect(shared.value, value);
      expect(await File(RoutineMediaStore.pathOf(value)).exists(), isTrue);
    });

    test('a link is never uploaded', () async {
      final shared = await const AssessmentMediaStore().share(
        'https://example.com/cat.jpg',
        ownerProfileId: 'teacher-1',
      );
      expect(shared.value, 'https://example.com/cat.jpg');
      expect(backend.chunkWrites, 0);
    });

    test('discarding a shared value removes it from the cloud', () async {
      final value = await picked('cat.png', 100);
      final shared = await const AssessmentMediaStore().share(
        value,
        ownerProfileId: 't',
      );
      await const AssessmentMediaStore().discard([shared.value]);
      expect(backend.metas, isEmpty);
    });

    test('the media cache resolves a shared value to a playable file', () async {
      final value = await picked('cat.png', 100);
      final shared = await const AssessmentMediaStore().share(
        value,
        ownerProfileId: 't',
      );
      await otherTablet();
      expect(
        await AssessmentMediaCache.availabilityOf(shared.value),
        MediaAvailability.ready,
      );
      backend.chunks.clear();
      // A third tablet, which never had it and now cannot get it.
      final third = await Directory('${root.path}/tablet_c').create();
      SharedMediaService.debugDirectory = () async => third;
      expect(
        await AssessmentMediaCache.availabilityOf(shared.value),
        MediaAvailability.unreachable,
      );
    });

    test('stored values include shared files, never links', () {
      const media = AssessmentMedia(
        photo: 'shared://abc',
        video: 'https://example.com/v.mp4',
        sign: 'file:///d/assessment_media/x.mp4',
      );
      expect(media.storedValues, {
        'shared://abc',
        'file:///d/assessment_media/x.mp4',
      });
    });

    test('a learner’s tablet re-pulls when a file becomes shared', () {
      final before = AssessmentAssignment(
        id: 'as1',
        assessmentId: 'a1',
        assessmentTitle: 'A',
        assignedBy: 't',
        studentIds: const ['ana'],
        assignedAt: DateTime(2026, 9, 26),
        media: const AssessmentMedia(sign: 'file:///d/assessment_media/s.mp4'),
      );
      final after = before.withMedia(const AssessmentMedia(sign: 'shared://s'));
      expect(
        AssessmentCloudService.revisionKey(before, 'ana'),
        isNot(AssessmentCloudService.revisionKey(after, 'ana')),
      );
    });
  });

  group('files picked offline are shared on the next sync', () {
    late Directory hiveDir;

    setUp(() async {
      hiveDir = await Directory.systemTemp.createTemp('shared_media_hive');
      Hive.init(hiveDir.path);
      await Hive.openBox('progress', compactionStrategy: (_, _) => false);
    });

    tearDown(() async {
      await Hive.close();
      if (await hiveDir.exists()) await hiveDir.delete(recursive: true);
    });

    test('questions, instructions and feedback all end up shared', () async {
      Future<String> pick(String name) async {
        final src = await fileOf(20, name);
        return (await const AssessmentMediaStore().adopt(
          sourcePath: src.path,
          ownerKey: name,
          kind: AssessmentMediaKind.photo,
        )).value!;
      }

      final q = await pick('q.png');
      final ins = await pick('ins.mp4');
      final fb = await pick('fb.mp4');
      await AssessmentService.saveAssessment(
        'teacher-1',
        Assessment(
          id: 'a1',
          title: 'Animals',
          type: AssessmentType.custom,
          questions: [
            AssessmentQuestion(
              id: 'q1',
              questionText: 'Which?',
              correctAnswer: 'Cat',
              choices: const ['Cat', 'Dog'],
              media: AssessmentMedia(photo: q),
            ),
          ],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        AssessmentAssignment(
          id: 'as1',
          assessmentId: 'a1',
          assessmentTitle: 'Animals',
          assignedBy: 'teacher-1',
          studentIds: const ['ana'],
          assignedAt: DateTime(2026, 9, 26),
          media: AssessmentMedia(sign: ins),
        ).withFeedback(
          'ana',
          AssessmentFeedback(
            note: 'Good',
            media: AssessmentMedia(video: fb),
            updatedAt: DateTime(2026, 9, 26, 10),
          ),
        ),
      );

      final changed = await const AssessmentMediaPublisher().publishPending(
        'teacher-1',
      );
      expect(changed, 2);

      final a = AssessmentService.getAssessments('teacher-1').single;
      expect(SharedMediaService.isShared(a.questions.single.media.photo), isTrue);
      final asg = AssessmentService.getAssignments('teacher-1').single;
      expect(SharedMediaService.isShared(asg.media.sign), isTrue);
      expect(
        SharedMediaService.isShared(asg.feedbackFor('ana')!.media.video),
        isTrue,
      );
      expect(asg.feedbackFor('ana')!.note, 'Good');

      // Nothing left to do on the next sync.
      expect(
        await const AssessmentMediaPublisher().publishPending('teacher-1'),
        0,
      );
    });

    test('choice pictures picked offline are shared too', () async {
      final src = await fileOf(20, 'cat.png');
      final cat = (await const AssessmentMediaStore().adopt(
        sourcePath: src.path,
        ownerKey: 'q1_choice0',
        kind: AssessmentMediaKind.photo,
      )).value!;
      await AssessmentService.saveAssessment(
        'teacher-1',
        Assessment(
          id: 'a1',
          title: 'A',
          type: AssessmentType.custom,
          questions: [
            AssessmentQuestion(
              id: 'q1',
              questionText: 'Which says meow?',
              correctAnswer: 'Cat',
              choices: const ['Cat', 'Dog'],
              choiceImages: {'Cat': cat, 'Dog': 'https://example.com/dog.png'},
            ),
          ],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ),
      );
      expect(
        await const AssessmentMediaPublisher().publishPending('teacher-1'),
        1,
      );
      final q = AssessmentService.getAssessments('teacher-1').single.questions
          .single;
      expect(SharedMediaService.isShared(q.choiceImages['Cat']!), isTrue);
      expect(q.choiceImages['Dog'], 'https://example.com/dog.png');
    });

    test('offline, nothing is re-saved and the files stay put', () async {
      final src = await fileOf(20, 'q.png');
      final q = (await const AssessmentMediaStore().adopt(
        sourcePath: src.path,
        ownerKey: 'q',
        kind: AssessmentMediaKind.photo,
      )).value!;
      await AssessmentService.saveAssessment(
        'teacher-1',
        Assessment(
          id: 'a1',
          title: 'A',
          type: AssessmentType.custom,
          questions: [
            AssessmentQuestion(
              id: 'q1',
              questionText: 'Which?',
              correctAnswer: 'Cat',
              choices: const ['Cat', 'Dog'],
              media: AssessmentMedia(photo: q),
            ),
          ],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ),
      );
      backend.failOnChunk = 0;
      expect(
        await const AssessmentMediaPublisher().publishPending('teacher-1'),
        0,
      );
      expect(
        AssessmentService.getAssessments('teacher-1').single.questions.single
            .media.photo,
        q,
      );
    });
  });

  group('routine media', () {
    test('clearing a shared routine file removes it from the cloud', () async {
      final up = await const SharedMediaService().upload(
        await fileOf(10),
        ownerProfileId: 't',
        ext: 'jpg',
      );
      await const RoutineMediaStore().discard(up.value!);
      expect(backend.metas, isEmpty);
    });
  });
}
