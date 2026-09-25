import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/learner_support.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media_presentation.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_store.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_panel.dart';

/// Pictures, video, sound and sign language on assessments, assignments and
/// feedback — the data, the per-learner presentation, and the files.
///
/// Plain `test()` only: the Hive-backed cases write to the box, which must
/// never happen inside `testWidgets` in this repo (see
/// `assignment_loop_test.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const photo = 'https://res.cloudinary.com/demo/image/upload/cat.jpg';
  const sign = 'https://res.cloudinary.com/demo/video/upload/cat_fsl.mp4';
  const audio = 'https://res.cloudinary.com/demo/video/upload/cat.m4a';

  AssessmentQuestion question(String id, {AssessmentMedia? media}) =>
      AssessmentQuestion(
        id: id,
        questionText: 'Which animal is this?',
        correctAnswer: 'Cat',
        choices: const ['Cat', 'Dog', 'Bird', 'Fish'],
        category: FlashcardCategory.animals,
        media: media ?? AssessmentMedia.none,
      );

  // ─── The data ────────────────────────────────────────────

  group('AssessmentMedia', () {
    test('round-trips every slot and the description', () {
      const media = AssessmentMedia(
        photo: photo,
        gif: 'assets/x.gif',
        video: 'https://example.com/v.mp4',
        audio: audio,
        sign: sign,
        description: 'A small cat on a mat',
      );
      expect(AssessmentMedia.fromJson(media.toJson()), media);
    });

    test('stores only the filled slots', () {
      const media = AssessmentMedia(photo: photo);
      expect(media.toJson(), {'photo': photo});
      expect(AssessmentMedia.none.toJson(), isEmpty);
    });

    test('reads anything malformed as no media rather than throwing', () {
      expect(AssessmentMedia.fromJson(null), AssessmentMedia.none);
      expect(AssessmentMedia.fromJson('nonsense'), AssessmentMedia.none);
      expect(AssessmentMedia.fromJson(const [1, 2]), AssessmentMedia.none);
      // Hive hands maps back as Map<dynamic, dynamic>, with whatever types.
      final hive = <dynamic, dynamic>{'photo': photo, 'sign': 42};
      final read = AssessmentMedia.fromJson(hive);
      expect(read.photo, photo);
      expect(read.sign, isEmpty);
    });

    test('a description alone is not media, but it is worth storing', () {
      const words = AssessmentMedia(description: 'hello');
      expect(words.hasAny, isFalse);
      expect(words.isEmpty, isFalse);
      expect(AssessmentMedia.none.isEmpty, isTrue);
    });

    test('knows which of its files live on this device', () {
      const media = AssessmentMedia(
        photo: 'file:///data/app/assessment_media/q1_photo_1.jpg',
        sign: sign,
      );
      expect(media.deviceFiles, {
        'file:///data/app/assessment_media/q1_photo_1.jpg',
      });
      expect(media.hasDeviceFiles, isTrue);
      expect(const AssessmentMedia(sign: sign).hasDeviceFiles, isFalse);
    });

    test('withSlot fills and clears one slot and keeps the rest', () {
      final media = AssessmentMedia.none
          .withSlot(AssessmentMediaKind.photo, '  $photo  ')
          .withSlot(AssessmentMediaKind.sign, sign)
          .withDescription('A cat');
      expect(media.photo, photo, reason: 'values are trimmed');
      expect(media.supplied, [AssessmentMediaKind.photo, AssessmentMediaKind.sign]);
      final cleared = media.withSlot(AssessmentMediaKind.photo, '');
      expect(cleared.has(AssessmentMediaKind.photo), isFalse);
      expect(cleared.sign, sign);
      expect(cleared.description, 'A cat');
    });
  });

  group('AssessmentQuestion', () {
    test('a question without media stores exactly what it stored before', () {
      expect(question('q1').toJson().containsKey('media'), isFalse);
    });

    test('an older stored question reads back with no media', () {
      final json = question('q1').toJson()..remove('media');
      expect(AssessmentQuestion.fromJson(json).media, AssessmentMedia.none);
    });

    test('media survives a round trip', () {
      final q = question(
        'q1',
        media: const AssessmentMedia(photo: photo, sign: sign),
      );
      expect(AssessmentQuestion.fromJson(q.toJson()).media, q.media);
    });
  });

  group('AssessmentAssignment', () {
    AssessmentAssignment assignment() => AssessmentAssignment(
      id: 'as1',
      assessmentId: 'a1',
      assessmentTitle: 'Animals',
      assignedBy: 'teacher-1',
      studentIds: const ['ana', 'ben'],
      assignedAt: DateTime(2026, 9, 25),
      instructions: 'Watch, then choose.',
      media: const AssessmentMedia(sign: sign),
    );

    test('instruction media and feedback survive a round trip', () {
      final a = assignment().withFeedback(
        'ana',
        AssessmentFeedback(
          note: 'Great signing!',
          media: const AssessmentMedia(audio: audio),
          updatedAt: DateTime(2026, 9, 26, 10),
        ),
      );
      final back = AssessmentAssignment.fromJson(a.toJson());
      expect(back.media, a.media);
      expect(back.feedbackFor('ana')?.note, 'Great signing!');
      expect(back.feedbackFor('ana')?.media.audio, audio);
      expect(back.feedbackFor('ana')?.updatedAt, DateTime(2026, 9, 26, 10));
      expect(back.feedbackFor('ben'), isNull);
    });

    test('an assignment with neither stores no new keys', () {
      final plain = AssessmentAssignment(
        id: 'as2',
        assessmentId: 'a1',
        assessmentTitle: 'Animals',
        assignedBy: 't',
        studentIds: const ['ana'],
        assignedAt: DateTime(2026, 9, 25),
      ).toJson();
      expect(plain.containsKey('media'), isFalse);
      expect(plain.containsKey('feedback'), isFalse);
    });

    test('withFeedback replaces, and null or empty removes', () {
      final at = DateTime(2026, 9, 26);
      var a = assignment().withFeedback(
        'ana',
        AssessmentFeedback(note: 'One', updatedAt: at),
      );
      a = a.withFeedback('ana', AssessmentFeedback(note: 'Two', updatedAt: at));
      expect(a.feedbackFor('ana')?.note, 'Two');
      expect(a.withFeedback('ana', null).feedbackFor('ana'), isNull);
      expect(
        a.withFeedback('ana', AssessmentFeedback(updatedAt: at)).feedback,
        isEmpty,
      );
      // Everything else about the assignment is untouched.
      expect(a.media, assignment().media);
      expect(a.instructions, assignment().instructions);
    });

    test('a malformed feedback entry is skipped, not fatal', () {
      final json = assignment().toJson()
        ..['feedback'] = {
          'ana': {'note': 'Well done', 'updatedAt': '2026-09-26T10:00:00'},
          'ben': 'garbage',
          'cy': {'updatedAt': 'not a date'},
        };
      final back = AssessmentAssignment.fromJson(json);
      expect(back.feedback.keys, ['ana']);
    });

    test("its live revision moves only when this learner's feedback does", () {
      final a = assignment();
      final at = DateTime(2026, 9, 26, 10);
      final withAna = a.withFeedback(
        'ana',
        AssessmentFeedback(note: 'Good', updatedAt: at),
      );
      expect(
        AssessmentCloudService.revisionKey(a, 'ana'),
        isNot(AssessmentCloudService.revisionKey(withAna, 'ana')),
        reason: "new feedback must wake the learner's listener",
      );
      expect(
        AssessmentCloudService.revisionKey(a, 'ben'),
        AssessmentCloudService.revisionKey(withAna, 'ben'),
        reason: "a classmate's feedback is not a change for Ben",
      );
      // The cloud copy and this device's copy agree after a round trip, so
      // an unchanged row never triggers a pull.
      expect(
        AssessmentCloudService.revisionKey(
          AssessmentAssignment.fromJson(withAna.toJson()),
          'ana',
        ),
        AssessmentCloudService.revisionKey(withAna, 'ana'),
      );
    });

    test('deviceFiles gathers instructions and every feedback', () {
      const own = 'file:///x/assessment_media/as1_sign_1.mp4';
      const fb = 'file:///x/assessment_media/fb_as1_ana_photo_2.jpg';
      final a = AssessmentAssignment(
        id: 'as1',
        assessmentId: 'a1',
        assessmentTitle: 'Animals',
        assignedBy: 't',
        studentIds: const ['ana'],
        assignedAt: DateTime(2026, 9, 25),
        media: const AssessmentMedia(sign: own),
      ).withFeedback(
        'ana',
        AssessmentFeedback(
          media: const AssessmentMedia(photo: fb),
          updatedAt: DateTime(2026, 9, 26),
        ),
      );
      expect(a.deviceFiles, {own, fb});
    });
  });

  group('the service keeps media when it rebuilds questions', () {
    test('fewer choices does not take the pictures away', () {
      final narrowed = AssessmentService.limitChoices([
        question('q1', media: const AssessmentMedia(photo: photo, sign: sign)),
      ], 2);
      expect(narrowed.single.choices, hasLength(2));
      expect(narrowed.single.media.photo, photo);
      expect(narrowed.single.media.sign, sign);
    });

    test('the parallel post-test keeps each item its media', () {
      final pre = Assessment(
        id: 'pre',
        title: 'Class Pre-Test',
        type: AssessmentType.preTest,
        questions: [question('q1', media: const AssessmentMedia(photo: photo))],
        createdBy: 't',
        createdAt: DateTime(2026, 9),
      );
      final post = AssessmentService.createClassPostTest(pre);
      expect(post.questions.single.media.photo, photo);
    });
  });

  // ─── The presentation ────────────────────────────────────

  group('AssessmentMediaPresentation per category', () {
    const all = AssessmentMedia(
      photo: photo,
      gif: 'assets/a.gif',
      video: 'https://example.com/v.mp4',
      audio: audio,
      sign: sign,
    );

    AssessmentMediaPresentation of(DisabilityType t) =>
        AssessmentMediaPresentation.forType(t);

    test('Hearing: the signed version leads and plays, captions show', () {
      final p = of(DisabilityType.hearing);
      expect(p.kindsFor(all).first, AssessmentMediaKind.sign);
      expect(p.kindsFor(all).last, AssessmentMediaKind.audio);
      expect(p.autoplaySign, isTrue);
      expect(p.showCaptions, isTrue);
      expect(p.offerReadAloud, isFalse);
    });

    test('Visual: sound first, read-aloud offered, no sign video', () {
      final p = of(DisabilityType.visual);
      expect(p.kindsFor(all).first, AssessmentMediaKind.audio);
      expect(p.kindsFor(all), isNot(contains(AssessmentMediaKind.sign)));
      expect(p.offerReadAloud, isTrue);
      expect(p.largeControls, isTrue);
    });

    test('Cognitive: one thing at a time, no sign video', () {
      final p = of(DisabilityType.cognitive);
      expect(p.leadOnly, isTrue);
      expect(p.kindsFor(all).first, AssessmentMediaKind.photo);
      expect(p.kindsFor(all), isNot(contains(AssessmentMediaKind.sign)));
      expect(p.showCaptions, isTrue);
    });

    test('Motor: videos start themselves, controls are big', () {
      final p = of(DisabilityType.motor);
      expect(p.autoplayVideo, isTrue);
      expect(p.autoplaySign, isTrue);
      expect(p.largeControls, isTrue);
    });

    test('Multiple: every alternative on', () {
      final p = of(DisabilityType.multiple);
      expect(p.kindsFor(all), contains(AssessmentMediaKind.sign));
      expect(p.showCaptions, isTrue);
      expect(p.offerReadAloud, isTrue);
      expect(p.leadOnly, isFalse);
    });

    test('None: everything, nothing automatic', () {
      final p = of(DisabilityType.none);
      expect(p.kindsFor(all), hasLength(5));
      expect(p.autoplaySign || p.autoplayVideo, isFalse);
    });

    test('every category shows every slot it shows at all exactly once', () {
      for (final t in DisabilityType.values) {
        final kinds = of(t).kindsFor(all);
        expect(kinds.toSet(), hasLength(kinds.length), reason: t.name);
        expect(of(t).order.toSet(), AssessmentMediaKind.values.toSet(),
            reason: '${t.name} must order every kind');
      }
    });

    test('an unfilled slot is never shown', () {
      final p = of(DisabilityType.hearing);
      expect(p.kindsFor(const AssessmentMedia(photo: photo)), [
        AssessmentMediaKind.photo,
      ]);
      expect(p.showsAnything(AssessmentMedia.none), isFalse);
    });
  });

  group('the learner\'s own supports adjust it', () {
    AssessmentMediaPresentation of(
      DisabilityType t,
      Set<LearnerSupportOption> s,
    ) => AssessmentMediaPresentation.forLearner(t, s);

    test('a Deaf learner on written words gets captions, not signs', () {
      final p = of(DisabilityType.hearing, {
        LearnerSupportOption.writtenCaptions,
      });
      expect(p.showSign, isFalse);
      expect(p.showCaptions, isTrue);
    });

    test('an ASL signer is told the clip is filmed in FSL', () {
      final p = of(DisabilityType.hearing, {LearnerSupportOption.signAsl});
      expect(p.showSign, isTrue);
      expect(p.signSystemDiffers, isTrue);
      expect(
        of(DisabilityType.hearing, {LearnerSupportOption.signFsl})
            .signSystemDiffers,
        isFalse,
      );
    });

    // "Multiple" offers every support group, so it is where a support can
    // change something its category would not have done on its own. A
    // support a category does not offer is dropped by the catalog before it
    // gets here — the category-only cases above already cover those.

    test('step by step shows one thing at a time', () {
      expect(of(DisabilityType.multiple, const {}).leadOnly, isFalse);
      expect(
        of(DisabilityType.multiple, {LearnerSupportOption.stepByStep}).leadOnly,
        isTrue,
      );
    });

    test('audio first moves the sound to the front and reads aloud', () {
      final p = of(DisabilityType.multiple, {
        LearnerSupportOption.audioFirst,
      });
      expect(p.order.first, AssessmentMediaKind.audio);
      expect(p.offerReadAloud, isTrue);
    });

    test('picture prompts put pictures first', () {
      final p = of(DisabilityType.multiple, {
        LearnerSupportOption.picturePrompts,
        // Large print instead of audio first, so the sound is not promoted
        // over the pictures.
        LearnerSupportOption.largePrint,
      });
      expect(p.order.take(2), [
        AssessmentMediaKind.photo,
        AssessmentMediaKind.gif,
      ]);
    });

    test('switch input gets autoplay and big controls', () {
      final touch = of(DisabilityType.multiple, {
        LearnerSupportOption.inputTouch,
      });
      expect(touch.autoplayVideo, isFalse);
      final p = of(DisabilityType.multiple, {LearnerSupportOption.inputSwitch});
      expect(p.autoplayVideo, isTrue);
      expect(p.autoplaySign, isTrue);
      expect(p.largeControls, isTrue);
    });
  });

  group('whose presentation', () {
    UserProfile profile(UserRole role, DisabilityType t) => UserProfile(
      id: 'p',
      name: 'P',
      role: role,
      createdAt: DateTime(2026),
      disabilityType: t,
    );

    test('an educator previews everything, whatever their own category', () {
      final p = AssessmentMediaPresentation.forProfile(
        profile(UserRole.teacher, DisabilityType.visual),
      );
      expect(p.showSign, isTrue);
      expect(p.showCaptions, isTrue);
      expect(p.autoplaySign || p.autoplayVideo, isFalse);
    });

    test('a learner gets their own', () {
      final p = AssessmentMediaPresentation.forProfile(
        profile(UserRole.child, DisabilityType.hearing),
      );
      expect(p.autoplaySign, isTrue);
    });

    test('nobody signed in gets the plain one', () {
      expect(AssessmentMediaPresentation.forProfile(null).leadOnly, isFalse);
    });
  });

  group('tips for the educator', () {
    test('each category gets the advice that reaches it', () {
      expect(
        AssessmentMediaAdviceX.forLearner(DisabilityType.hearing, const {}),
        AssessmentMediaAdvice.signAndCaption,
      );
      expect(
        AssessmentMediaAdviceX.forLearner(DisabilityType.hearing, const {
          LearnerSupportOption.writtenCaptions,
        }),
        AssessmentMediaAdvice.captionEverything,
        reason: 'a Deaf reader is not told to add a sound',
      );
      expect(
        AssessmentMediaAdviceX.forLearner(DisabilityType.visual, const {}),
        AssessmentMediaAdvice.soundAndDescription,
      );
      expect(
        AssessmentMediaAdviceX.forLearner(DisabilityType.none, const {}),
        isNull,
      );
    });
  });

  test('curlyQuotes keeps a label from blanking on Android', () {
    expect(curlyQuotes('Say "cat" twice'), 'Say “cat” twice');
    expect(curlyQuotes('no quotes'), 'no quotes');
  });

  // ─── The files ───────────────────────────────────────────

  group('AssessmentMediaLedger', () {
    const oldPhoto = 'file:///d/assessment_media/q_photo_1.jpg';
    const newPhoto = 'file:///d/assessment_media/q_photo_2.jpg';
    const cancelled = 'file:///d/assessment_media/q_sign_3.mp4';

    test('saving lets go of what was replaced and what was dropped', () {
      final ledger = AssessmentMediaLedger(
        const AssessmentMedia(photo: oldPhoto),
      )
        ..adopted(newPhoto)
        ..adopted(cancelled);
      expect(
        ledger.toDiscardOnSave(const AssessmentMedia(photo: newPhoto)),
        {oldPhoto, cancelled},
      );
    });

    test('cancelling keeps the saved file and drops only new picks', () {
      final ledger = AssessmentMediaLedger(
        const AssessmentMedia(photo: oldPhoto),
      )..adopted(newPhoto);
      expect(ledger.toDiscardOnCancel(), {newPhoto});
    });
  });

  group('AssessmentMediaStore', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('assessment_media_store');
      AssessmentMediaStore.debugDirectory = () async => root;
    });

    tearDown(() async {
      AssessmentMediaStore.debugDirectory = null;
      AssessmentMediaStore.debugPick = null;
      if (await root.exists()) await root.delete(recursive: true);
    });

    Future<File> source(String name) async {
      final f = File('${root.path}${Platform.pathSeparator}$name');
      await f.writeAsBytes(const [1, 2, 3, 4]);
      return f;
    }

    test('a picked file is copied in under a fresh name each time', () async {
      final src = await source('clip.mp4');
      AssessmentMediaStore.debugPick = (_) async => src.path;
      const store = AssessmentMediaStore();
      final a = await store.pickAndAdopt(
        ownerKey: 'q 1',
        kind: AssessmentMediaKind.sign,
      );
      final b = await store.pickAndAdopt(
        ownerKey: 'q 1',
        kind: AssessmentMediaKind.sign,
      );
      expect(a.status, MediaPickStatus.added);
      expect(a.value, startsWith('file://'));
      expect(a.value, contains('assessment_media'));
      expect(a.value, endsWith('.mp4'));
      expect(a.value, isNot(b.value), reason: 'a re-pick must not overwrite');
      expect(AssessmentMediaStore.isOwnFile(a.value!), isTrue);
      expect(await File(a.value!.substring(7)).exists(), isTrue);
    });

    test('cancelling the picker adds nothing', () async {
      AssessmentMediaStore.debugPick = (_) async => null;
      final r = await const AssessmentMediaStore().pickAndAdopt(
        ownerKey: 'q1',
        kind: AssessmentMediaKind.photo,
      );
      expect(r.status, MediaPickStatus.cancelled);
      expect(r.value, isNull);
    });

    test('a file that vanished before the copy fails cleanly', () async {
      final r = await const AssessmentMediaStore().adopt(
        sourcePath: '${root.path}/nope.jpg',
        ownerKey: 'q1',
        kind: AssessmentMediaKind.photo,
      );
      expect(r.status, MediaPickStatus.failed);
    });

    test('discard deletes its own files and nothing else', () async {
      final outside = await source('keep_me.jpg');
      AssessmentMediaStore.debugPick = (_) async => outside.path;
      final adopted = await const AssessmentMediaStore().pickAndAdopt(
        ownerKey: 'q1',
        kind: AssessmentMediaKind.photo,
      );
      await const AssessmentMediaStore().discard([
        adopted.value!,
        'file://${outside.path}',
      ]);
      expect(await File(adopted.value!.substring(7)).exists(), isFalse);
      expect(await outside.exists(), isTrue,
          reason: 'a file:// value outside the store is never deleted');
    });

    test('discardUnreferenced keeps a file something still uses', () async {
      final src = await source('p.jpg');
      AssessmentMediaStore.debugPick = (_) async => src.path;
      const store = AssessmentMediaStore();
      final used = (await store.pickAndAdopt(
        ownerKey: 'a',
        kind: AssessmentMediaKind.photo,
      )).value!;
      final orphan = (await store.pickAndAdopt(
        ownerKey: 'b',
        kind: AssessmentMediaKind.photo,
      )).value!;
      await store.discardUnreferenced([used, orphan], referenced: {used});
      expect(await File(used.substring(7)).exists(), isTrue);
      expect(await File(orphan.substring(7)).exists(), isFalse);
    });
  });

  group('AssessmentMediaCache', () {
    tearDown(() => AssessmentMediaCache.debugFetch = null);

    test('a picked file from another tablet is "other device"', () async {
      expect(
        await AssessmentMediaCache.availabilityOf(
          'file:///nowhere/assessment_media/x.jpg',
        ),
        MediaAvailability.otherDevice,
      );
    });

    test('a bundled asset is always ready', () async {
      expect(
        await AssessmentMediaCache.availabilityOf('assets/images/x.png'),
        MediaAvailability.ready,
      );
    });

    test('a link that will not download is unreachable', () async {
      AssessmentMediaCache.debugFetch = (_) async => null;
      expect(
        await AssessmentMediaCache.availabilityOf(photo),
        MediaAvailability.unreachable,
      );
    });

    test('prepare returns only what is still missing', () async {
      final here = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}here.jpg',
      )..writeAsBytesSync(const [1]);
      addTearDown(() => here.deleteSync());
      AssessmentMediaCache.debugFetch = (url) async =>
          url == photo ? here : null;
      final missing = await AssessmentMediaCache.prepare([photo, sign]);
      expect(missing, [sign]);
    });

    test('a learner is only held up by media they will be shown', () {
      final test = Assessment(
        id: 'a',
        title: 'T',
        type: AssessmentType.custom,
        questions: [
          question('q1', media: const AssessmentMedia(photo: photo, sign: sign)),
        ],
        createdBy: 't',
        createdAt: DateTime(2026, 9),
      );
      expect(
        AssessmentMediaCache.valuesIn(
          test,
          AssessmentMediaPresentation.forType(DisabilityType.visual),
        ),
        [photo],
        reason: 'a learner who cannot use a sign video does not wait for one',
      );
      expect(
        AssessmentMediaCache.valuesIn(
          test,
          AssessmentMediaPresentation.forType(DisabilityType.hearing),
        ),
        unorderedEquals([photo, sign]),
      );
    });
  });

  // ─── What the progress box refers to ─────────────────────

  group('with the progress box', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('assessment_media_hive');
      Hive.init(dir.path);
      for (final name in const ['progress', 'profiles']) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    });

    tearDown(() async {
      await Hive.close();
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    const qFile = 'file:///d/assessment_media/q1_photo_1.jpg';
    const asgFile = 'file:///d/assessment_media/asg_sign_1.mp4';
    const fbFile = 'file:///d/assessment_media/fb_audio_1.m4a';

    Future<void> seed() async {
      await AssessmentService.saveAssessment(
        'teacher-1',
        Assessment(
          id: 'a1',
          title: 'Animals',
          type: AssessmentType.custom,
          questions: [question('q1', media: const AssessmentMedia(photo: qFile))],
          createdBy: 'teacher-1',
          createdAt: DateTime(2026, 9),
        ),
      );
      final base = AssessmentAssignment(
        id: 'as1',
        assessmentId: 'a1',
        assessmentTitle: 'Animals',
        assignedBy: 'teacher-1',
        studentIds: const ['ana', 'ben'],
        assignedAt: DateTime(2026, 9, 25),
        media: const AssessmentMedia(sign: asgFile),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        base
            .withFeedback(
              'ana',
              AssessmentFeedback(
                note: 'Older',
                media: const AssessmentMedia(audio: fbFile),
                updatedAt: DateTime(2026, 9, 26),
              ),
            ),
      );
      await AssessmentService.saveAssignment(
        'teacher-1',
        base
            .copyAs('as2')
            .withFeedback(
              'ana',
              AssessmentFeedback(note: 'Newer', updatedAt: DateTime(2026, 9, 27)),
            ),
      );
    }

    test('every file an assessment or assignment uses is referenced', () async {
      await seed();
      expect(
        AssessmentService.referencedMediaValues(),
        containsAll([qFile, asgFile, fbFile]),
      );
    });

    test('a learner sees only their own feedback, newest first', () async {
      await seed();
      final ana = AssessmentService.getFeedbackForStudent('ana');
      expect(ana.map((f) => f.feedback.note), ['Newer', 'Older']);
      expect(AssessmentService.getFeedbackForStudent('ben'), isEmpty);
    });

    test('feedback written on the assignment reaches the learner copy', () async {
      // The learner's device stores the educator's rows under the educator's
      // key (hydrateLearner); a merged row carrying feedback must replace the
      // one without it.
      await seed();
      final updated = AssessmentService.getAssignments('teacher-1')
          .firstWhere((a) => a.id == 'as1')
          .withFeedback(
            'ben',
            AssessmentFeedback(note: 'Nice', updatedAt: DateTime(2026, 9, 28)),
          );
      await AssessmentService.mergeAssignments('teacher-1', [updated]);
      expect(
        AssessmentService.getFeedbackForStudent('ben').single.feedback.note,
        'Nice',
      );
    });
  });
}

extension on AssessmentAssignment {
  AssessmentAssignment copyAs(String newId) => AssessmentAssignment(
    id: newId,
    assessmentId: assessmentId,
    assessmentTitle: assessmentTitle,
    assignedBy: assignedBy,
    studentIds: studentIds,
    assignedAt: assignedAt,
  );
}
