import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/accessibility/stt_service.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/classroom.dart';
import 'package:pwdpwdpwd/data/models/classroom_member.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/features/messaging/models/composer_presentation.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/providers/messaging_providers.dart';
import 'package:pwdpwdpwd/features/messaging/screens/messaging_screen.dart';
import 'package:pwdpwdpwd/features/messaging/services/friend_service.dart';
import 'package:pwdpwdpwd/features/messaging/services/message_media.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/friend_ui.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/inline_pickers.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/message_media_view.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Messages, third pass: parent approval for a Child's friends, photos and
/// recorded sign videos, speak-to-type, and pickers a head-control learner
/// can actually reach.

const _me = 'teacher-me';

UserProfile _profile(
  UserRole role, {
  String id = _me,
  String? homeGroupId,
  DisabilityType disability = DisabilityType.none,
}) => UserProfile(
  id: id,
  name: 'Me',
  role: role,
  createdAt: DateTime(2026),
  homeGroupId: homeGroupId,
  disabilityType: disability,
);

FriendRequest _request({
  FriendRequestStatus status = FriendRequestStatus.pending,
  String? fromGroup,
  String? toGroup,
  bool fromApproved = false,
  bool toApproved = false,
}) => FriendRequest(
  id: 'a_b',
  fromProfileId: 'a',
  toProfileId: 'b',
  fromOwnerUid: 'u',
  fromDisplayName: 'Ana',
  status: status,
  createdAt: DateTime(2026, 9, 26),
  fromHomeGroupId: fromGroup,
  toHomeGroupId: toGroup,
  fromApproved: fromApproved,
  toApproved: toApproved,
);

LocalMessage _media(
  String id,
  MessageType type, {
  String from = 'kid',
  DateTime? at,
  String? caption,
}) => LocalMessage(
  id: id,
  senderId: from,
  senderName: from,
  recipientId: 'other',
  content: 'shared://$id',
  type: type,
  timestamp: at ?? DateTime(2026, 9, 26, 10),
  caption: caption,
);

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._profile);
  final UserProfile? _profile;
  @override
  UserProfile? build() => _profile;
}

class _GazeOnNotifier extends GazeSettingsNotifier {
  @override
  GazeSettings build() => const GazeSettings(enabled: true);
}

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

/// A scriptable recogniser for speak-to-type.
class _FakeStt extends SttService {
  _FakeStt({this.available = true});
  final bool available;
  bool listening = false;
  void Function(String text, bool isFinal)? onResult;

  @override
  Future<bool> init() async => available;
  @override
  bool get isListening => listening;
  @override
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
    bool partialResults = true,
  }) async {
    this.onResult = onResult;
    listening = true;
  }

  @override
  Future<void> stopListening() async => listening = false;
  @override
  Future<void> cancel() async => listening = false;
}

/// In-memory stand-in for the Firestore pieces behind shared media.
class _MemoryBackend implements SharedMediaBackend {
  final metas = <String, SharedMediaMeta>{};
  final chunks = <String, Uint8List>{};

  @override
  Future<void> writeMeta(SharedMediaMeta meta) async => metas[meta.id] = meta;
  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async =>
      chunks['$id/$index'] = bytes;
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

void main() {
  group('parent approval — the request model', () {
    test('new statuses survive the wire both ways', () {
      for (final status in FriendRequestStatus.values) {
        expect(FriendRequestStatusExt.fromWire(status.wire), status);
      }
      expect(FriendRequestStatus.awaitingParent.wire, 'awaiting_parent');
      expect(FriendRequestStatus.parentDeclined.wire, 'parent_declined');
    });

    test('approval fields round-trip through JSON', () {
      final r = _request(
        status: FriendRequestStatus.awaitingParent,
        fromGroup: 'g1',
        toGroup: 'g2',
        fromApproved: true,
      );
      final back = FriendRequest.fromJson(r.toJson());
      expect(back.fromHomeGroupId, 'g1');
      expect(back.toHomeGroupId, 'g2');
      expect(back.fromApproved, isTrue);
      expect(back.toApproved, isFalse);
      // A request with no child on either side writes none of it.
      final plain = _request().toJson();
      expect(plain.containsKey('from_home_group_id'), isFalse);
      expect(plain.containsKey('from_approved'), isFalse);
    });

    test('a Child in no family group is told, not refused with an error', () {
      expect(
        FriendService.isChildWithoutGroup(_profile(UserRole.child)),
        isTrue,
      );
      expect(
        FriendService.isChildWithoutGroup(
          _profile(UserRole.child, homeGroupId: 'g'),
        ),
        isFalse,
      );
      expect(
        FriendService.isChildWithoutGroup(_profile(UserRole.student)),
        isFalse,
      );
    });

    test('the new friend messages have Filipino wording', () {
      for (final english in [
        "You're almost friends — a grown-up still needs to say yes.",
        'A grown-up needs to add you to their family group before you can '
            'make friends.',
      ]) {
        final fil = FriendActionException(english).messageOf(filipino: true);
        expect(fil, isNot(english), reason: english);
        expect(fil, isNotEmpty);
      }
    });

    test('only a Child in a home group needs a parent', () {
      expect(
        FriendService.needsParentApproval(
          _profile(UserRole.child, homeGroupId: 'g'),
        ),
        isTrue,
      );
      expect(
        FriendService.needsParentApproval(_profile(UserRole.child)),
        isFalse,
        reason: 'no group, no parent in the app to ask',
      );
      for (final role in [UserRole.student, UserRole.player, UserRole.teacher]) {
        expect(
          FriendService.needsParentApproval(_profile(role, homeGroupId: 'g')),
          isFalse,
        );
      }
    });

    test('a request finishes only when every parent involved said yes', () {
      expect(
        _request(
          status: FriendRequestStatus.awaitingParent,
          fromGroup: 'g1',
        ).readyToFinish,
        isFalse,
      );
      expect(
        _request(
          status: FriendRequestStatus.awaitingParent,
          fromGroup: 'g1',
          fromApproved: true,
          toGroup: 'g2',
        ).readyToFinish,
        isFalse,
        reason: 'the other child\'s parent has not answered',
      );
      expect(
        _request(
          status: FriendRequestStatus.awaitingParent,
          fromGroup: 'g1',
          fromApproved: true,
          toGroup: 'g2',
          toApproved: true,
        ).readyToFinish,
        isTrue,
      );
      expect(
        _request(fromGroup: 'g1', fromApproved: true).readyToFinish,
        isFalse,
        reason: 'the recipient has not said yes yet',
      );
    });

    test('a parent sees their child\'s side, and only until they answer', () {
      final sent = _request(fromGroup: 'mine');
      expect(sent.awaitsParentIn({'mine'}), isTrue,
          reason: 'a parent may answer as soon as their child asks');
      expect(sent.awaitsParentIn({'theirs'}), isFalse);
      expect(
        _request(fromGroup: 'mine', fromApproved: true).awaitsParentIn({'mine'}),
        isFalse,
      );
      expect(
        _request(
          status: FriendRequestStatus.parentDeclined,
          fromGroup: 'mine',
        ).awaitsParentIn({'mine'}),
        isFalse,
      );
      expect(
        _request(
          status: FriendRequestStatus.awaitingParent,
          toGroup: 'mine',
        ).awaitsParentIn({'mine'}),
        isTrue,
      );
    });

    test('a request waiting on a grown-up is open but not the child\'s to '
        'answer', () {
      final waiting = _request(status: FriendRequestStatus.awaitingParent);
      expect(waiting.isOpen, isTrue);
      expect(waiting.isActionable, isFalse);
      expect(_request().isActionable, isTrue);
      expect(_request(status: FriendRequestStatus.accepted).isOpen, isFalse);
    });
  });

  group('photos and sign videos', () {
    test('five a day, counted per sender per calendar day', () {
      final now = DateTime(2026, 9, 26, 18);
      final messages = [
        for (var i = 0; i < 4; i++) _media('p$i', MessageType.photo),
        _media('y', MessageType.video, at: DateTime(2026, 9, 25, 10)),
        _media('o', MessageType.photo, from: 'someone-else'),
      ];
      expect(MessageMedia.sentToday(messages, 'kid', now: now), 4);
      expect(MessageMedia.canSendMore(messages, 'kid', now: now), isTrue);
      final full = [...messages, _media('v', MessageType.video)];
      expect(MessageMedia.canSendMore(full, 'kid', now: now), isFalse);
    });

    test('a week-old media message reads as expired', () {
      final now = DateTime(2026, 9, 26);
      expect(
        MessageMedia.isExpired(
          _media('a', MessageType.photo, at: DateTime(2026, 9, 18)),
          now: now,
        ),
        isTrue,
      );
      expect(
        MessageMedia.isExpired(
          _media('b', MessageType.photo, at: DateTime(2026, 9, 24)),
          now: now,
        ),
        isFalse,
      );
    });

    test('the wording names the photo or video, and the caption', () {
      final video = _media('v', MessageType.video, caption: 'Good morning');
      expect(
        MessageWording.preview(video, isFilipino: false),
        '🎬 Video: Good morning',
      );
      expect(
        MessageWording.bubbleLabel(
          video,
          isMine: false,
          otherName: 'Ana',
          isFilipino: false,
        ),
        startsWith('Ana: sent a video: Good morning'),
      );
      expect(
        MessageWording.speakable(video, isFilipino: false),
        'A video. Good morning',
      );
      expect(
        MessageWording.preview(_media('p', MessageType.photo), isFilipino: true),
        '📷 Larawan',
      );
    });

    test('photo and video were appended, so older types keep their index', () {
      expect(MessageType.report.index, 5);
      expect(MessageType.photo.index, 6);
      expect(MessageType.video.index, 7);
      final json = _media('x', MessageType.video, caption: 'Hi').toJson();
      final back = LocalMessage.fromJson(json);
      expect(back.type, MessageType.video);
      expect(back.caption, 'Hi');
      expect(back.isMedia, isTrue);
    });

    test('photos and sign videos follow the accessibility type', () {
      final visual = ComposerPresentation.forType(DisabilityType.visual);
      expect(visual.photos, isFalse);
      expect(visual.signVideos, isFalse);
      final hearing = ComposerPresentation.forType(DisabilityType.hearing);
      expect(hearing.signVideos, isTrue);
      expect(hearing.dictation, isFalse,
          reason: 'recognisers read Deaf speech poorly; signs are faster');
      expect(
        ComposerPresentation.forType(DisabilityType.cognitive).dictation,
        isFalse,
        reason: 'no text field to dictate into',
      );
      for (final t in [
        DisabilityType.visual,
        DisabilityType.motor,
        DisabilityType.none,
      ]) {
        expect(ComposerPresentation.forType(t).dictation, isTrue, reason: t.name);
      }
      // Educators get everything.
      final teacher = ComposerPresentation.forProfile(_profile(UserRole.teacher));
      expect(teacher.photos && teacher.signVideos && teacher.dictation, isTrue);
    });

    group('storage', () {
      late _MemoryBackend backend;
      late Directory dir;

      setUp(() async {
        backend = _MemoryBackend();
        SharedMediaService.debugBackend = backend;
        dir = await Directory.systemTemp.createTemp('msg_media');
        SharedMediaService.debugDirectory = () async => dir;
        MessageMediaRetention.resetForTesting();
      });

      tearDown(() async {
        SharedMediaService.debugBackend = null;
        SharedMediaService.debugDirectory = null;
        MessageMediaRetention.debugOwned = null;
        MessageMediaRetention.resetForTesting();
        await dir.delete(recursive: true);
      });

      Future<String> share(String name, {String? purpose}) async {
        final f = File('${dir.path}${Platform.pathSeparator}$name');
        await f.writeAsString('bytes of $name');
        final result = await const SharedMediaService().upload(
          f,
          ownerProfileId: 'kid',
          ext: 'jpg',
          purpose: purpose,
        );
        return result.value!;
      }

      test('a message upload is tagged, so the 24-hour sweep leaves it', () async {
        final value = await share('m.jpg', purpose: SharedMediaMeta.purposeMessage);
        final meta = backend.metas[SharedMediaService.idOf(value)]!;
        expect(meta.purpose, SharedMediaMeta.purposeMessage);
        expect(meta.toJson()['purpose'], 'message');
        expect(
          SharedMediaMeta.tryFromJson(meta.id, meta.toJson())!.purpose,
          'message',
        );
      });

      test('retention deletes only week-old MESSAGE files, once a session',
          () async {
        final now = DateTime(2026, 9, 26);
        final oldMessage = await share('old.jpg',
            purpose: SharedMediaMeta.purposeMessage);
        final newMessage = await share('new.jpg',
            purpose: SharedMediaMeta.purposeMessage);
        final oldAssessment = await share('quiz.jpg');
        MessageMediaRetention.debugOwned = (_) async => [
          (
            id: SharedMediaService.idOf(oldMessage),
            createdAt: DateTime(2026, 9, 10),
            purpose: SharedMediaMeta.purposeMessage,
          ),
          (
            id: SharedMediaService.idOf(newMessage),
            createdAt: DateTime(2026, 9, 25),
            purpose: SharedMediaMeta.purposeMessage,
          ),
          (
            id: SharedMediaService.idOf(oldAssessment),
            createdAt: DateTime(2026, 9, 2),
            purpose: null,
          ),
        ];

        expect(await const MessageMediaRetention().run('kid', now: now), 1);
        expect(backend.metas.containsKey(SharedMediaService.idOf(oldMessage)),
            isFalse);
        expect(backend.metas.containsKey(SharedMediaService.idOf(newMessage)),
            isTrue);
        expect(
          backend.metas.containsKey(SharedMediaService.idOf(oldAssessment)),
          isTrue,
          reason: 'assessment files are not this sweep\'s to remove',
        );
        // Once per session.
        expect(await const MessageMediaRetention().run('kid', now: now), 0);
      });
    });
  });

  group('widgets', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/messaging_media');
      for (final name in const <String>[
        'profiles',
        'settings',
        'progress',
        'custom_cards',
        'sessions',
        'friends_cache',
        'friend_requests_cache',
        'friend_directory_cache',
        'classrooms',
        'classroom_members',
      ]) {
        if (!Hive.isBoxOpen(name)) {
          await Hive.openBox(name, compactionStrategy: (_, _) => false);
        }
      }
      // A class with one learner, so the teacher has a live (linked) thread
      // without Firebase. Seeded here: Hive writes inside testWidgets hang.
      await HiveService.cacheClassroom(
        Classroom(
          id: 'class-1',
          code: 'ABC123',
          name: 'Hearing Class',
          teacherId: _me,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await HiveService.addMemberLocal(
        ClassroomMember(
          classroomId: 'class-1',
          profileId: 'kid-1',
          displayName: 'Ana Test',
          joinedAt: DateTime(2026),
        ),
      );
      // The child's own cache of their open requests (what the sheet shows
      // offline).
      await HiveService.saveFriendRequestsCache('b', [
        _request(status: FriendRequestStatus.awaitingParent).toJson(),
      ]);
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk()
          .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
    });

    Widget app(Widget home, {List<Override> overrides = const []}) =>
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a parent approves their child\'s new friend', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: ParentApprovalsSheet(
              initialRequests: [_request(fromGroup: 'mine')],
              myGroupIds: const {'mine'},
              isFilipino: false,
              lookup: (_) async => {
                'b': DirectoryEntry(
                  username: 'ben-1',
                  profileId: 'b',
                  name: 'Ben',
                  roleIndex: UserRole.student.index,
                  ownerUid: 'u',
                  updatedAt: DateTime(2026),
                ),
              },
            ),
          ),
          overrides: [
            parentApprovalsProvider.overrideWith(
              (ref) => const Stream<List<FriendRequest>>.empty(),
            ),
          ],
        ),
      );
      await tester.pump();
      expect(find.text('Ana wants to be friends with Ben.'), findsOneWidget);
      await tester.tap(find.text('Say yes'));
      await tester.pump();
      expect(find.text('Nothing waiting.'), findsOneWidget);
    });

    testWidgets('a child sees their yes waiting on a grown-up', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: FriendRequestsSheet(
              me: _profile(UserRole.child, id: 'b', homeGroupId: 'g'),
              isFilipino: false,
              initialRequests: [
                _request(status: FriendRequestStatus.awaitingParent),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('You said yes. Waiting for a grown-up.'), findsOneWidget);
      expect(find.byTooltip('Accept'), findsNothing);
    });

    testWidgets('a media bubble says when it cannot load, and when it expired',
        (tester) async {
      MessageMediaBody.debugResolve = (_) async => null;
      addTearDown(() => MessageMediaBody.debugResolve = null);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Column(
              children: [
                MessageMediaBody(
                  message: _media(
                    'fresh',
                    MessageType.video,
                    at: DateTime.now(),
                    caption: 'Hello',
                  ),
                  isFilipino: false,
                ),
                MessageMediaBody(
                  message: _media(
                    'old',
                    MessageType.photo,
                    at: DateTime.now().subtract(const Duration(days: 10)),
                  ),
                  isFilipino: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text("Can't load it yet. Tap to try again."), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('This photo expired after a week.'), findsOneWidget);
    });

    testWidgets('the sign panel goes topic first, then words', (tester) async {
      const cards = [
        Flashcard(
          id: '1',
          wordEnglish: 'Cat',
          wordFilipino: 'Pusa',
          category: FlashcardCategory.animals,
        ),
        Flashcard(
          id: '2',
          wordEnglish: 'Red',
          wordFilipino: 'Pula',
          category: FlashcardCategory.colorsAndShapes,
        ),
      ];
      FlashcardCategory? picked;
      await tester.pumpWidget(
        app(
          Scaffold(
            body: InlineSignPanel(
              isFilipino: false,
              signable: cards,
              category: null,
              isFocused: (i) => i == 1,
              closeFocused: false,
              backFocused: false,
              onCategory: (c) => picked = c,
              onWord: (_) {},
              onBack: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      expect(find.text('Pick a topic'), findsOneWidget);
      expect(InlineSignPanel.topicsOf(cards), [
        FlashcardCategory.animals,
        FlashcardCategory.colorsAndShapes,
      ]);
      await tester.tap(find.textContaining(FlashcardCategory.animals.label));
      expect(picked, FlashcardCategory.animals);
      expect(
        InlineSignPanel.wordsIn(cards, FlashcardCategory.animals)
            .map((c) => c.wordEnglish),
        ['Cat'],
      );
    });

    group('the thread with gaze on', () {
      setUp(() {
        while (gazeCameraOwners.isBusy) {
          gazeCameraOwners.release();
        }
      });
      tearDown(() {
        while (gazeCameraOwners.isBusy) {
          gazeCameraOwners.release();
        }
      });

      Future<VoiceControlMixin> pumpGazeThread(
        WidgetTester tester, {
        SttService? stt,
      }) async {
        tester.view.physicalSize = const Size(800, 1280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            MessagingScreen(
              camerasLoader: () async => const <CameraDescription>[],
              detectorFactory: _FakeDetector.new,
            ),
            overrides: [
              profileProvider.overrideWith(
                () => _StubProfileNotifier(_profile(UserRole.teacher)),
              ),
              activeProfileMessagesProvider.overrideWith(
                (ref) => Stream.value(const <LocalMessage>[]),
              ),
              blockedProfileIdsProvider.overrideWith(
                (ref) => Stream.value(const <String>{}),
              ),
              incomingFriendRequestsProvider.overrideWith(
                (ref) => Stream.value(const <FriendRequest>[]),
              ),
              gazeSettingsProvider.overrideWith(_GazeOnNotifier.new),
              sttServiceProvider.overrideWithValue(
                stt ?? _FakeStt(available: false),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final voice =
            tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;
        // Open the learner's thread by name, hands-free.
        voice.onVoiceCommand('Ana Test');
        await tester.pump(const Duration(milliseconds: 300));
        return voice;
      }

      testWidgets('the composer shows its tools by name', (tester) async {
        await pumpGazeThread(tester);
        expect(find.text('Ana Test'), findsWidgets);
        for (final label in ['Sign', 'Sticker', 'Video', 'Photo']) {
          expect(find.text(label), findsOneWidget, reason: label);
        }
        expect(find.byTooltip('Speak a message'), findsOneWidget);
        await settle(tester);
      });

      testWidgets('"send a sticker" opens the stickers IN the thread, where '
          'gaze can reach them', (tester) async {
        final voice = await pumpGazeThread(tester);
        voice.onVoiceCommand('send a sticker');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InlineStickerPanel), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing,
            reason: 'a modal sheet is out of the gaze D-pad\'s reach');
        // Every sticker is a named cell — "close" is one too.
        voice.onVoiceCommand('close');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InlineStickerPanel), findsNothing);
        await settle(tester);
      });

      testWidgets('"send a sign" opens the topic panel in the thread',
          (tester) async {
        final voice = await pumpGazeThread(tester);
        voice.onVoiceCommand('send a sign');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InlineSignPanel), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        await settle(tester);
      });

      testWidgets('"speak a message" reaches dictation, and a missing '
          'recogniser is said plainly', (tester) async {
        final voice = await pumpGazeThread(tester);
        voice.onVoiceCommand('speak a message');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Speech input is not available on this device.'),
            findsOneWidget);
        expect(dictationMicLease.isHeld, isFalse);
        await settle(tester);
      });

      testWidgets('dictation writes into the field and hands the mic back',
          (tester) async {
        final stt = _FakeStt();
        final voice = await pumpGazeThread(tester, stt: stt);
        voice.onVoiceCommand('speak a message');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        expect(dictationMicLease.isHeld, isTrue,
            reason: 'voice commands stand down while the learner speaks');
        expect(find.text('Listening… speak now'), findsOneWidget);

        stt.onResult!('hello teacher', true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('hello teacher'), findsOneWidget);
        expect(dictationMicLease.isHeld, isFalse,
            reason: 'a final result gives the microphone back');
        await settle(tester);
      });

      testWidgets('a double tap starts ONE dictation and gives the mic back',
          (tester) async {
        final stt = _FakeStt();
        final voice = await pumpGazeThread(tester, stt: stt);
        // Two activations in quick succession — a double tap, or a gaze dwell
        // that fires twice — before the first has finished starting.
        voice.onVoiceCommand('speak a message');
        voice.onVoiceCommand('speak a message');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        expect(dictationMicLease.isHeld, isTrue);

        stt.onResult!('hello', true);
        await tester.pump(const Duration(milliseconds: 100));
        expect(dictationMicLease.isHeld, isFalse,
            reason: 'taken once, given back once: voice commands resume');
        await settle(tester);
      });

      testWidgets('a dictation that ends in silence still hands the mic back',
          (tester) async {
        final stt = _FakeStt();
        final voice = await pumpGazeThread(tester, stt: stt);
        voice.onVoiceCommand('speak a message');
        await tester.pump(const Duration(milliseconds: 400));
        expect(dictationMicLease.isHeld, isTrue);
        // The recogniser times out on silence: no final result, ever.
        stt.listening = false;
        await tester.pump(const Duration(seconds: 3));
        expect(dictationMicLease.isHeld, isFalse);
        await settle(tester);
      });

      testWidgets('Back closes the picker, then the thread, then leaves',
          (tester) async {
        final voice = await pumpGazeThread(tester);
        voice.onVoiceCommand('send a sticker');
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InlineStickerPanel), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(InlineStickerPanel), findsNothing);
        expect(find.text('Photo'), findsOneWidget, reason: 'still in the thread');

        await tester.binding.handlePopRoute();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Photo'), findsNothing, reason: 'back at the inbox');
        expect(find.text('Ana Test'), findsOneWidget);
        await settle(tester);
      });
    });

    testWidgets('the new composer fits 2.0x text on a small phone',
        (tester) async {
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileProvider.overrideWith(
              () => _StubProfileNotifier(_profile(UserRole.teacher)),
            ),
            activeProfileMessagesProvider.overrideWith(
              (ref) => Stream.value(const <LocalMessage>[]),
            ),
            blockedProfileIdsProvider.overrideWith(
              (ref) => Stream.value(const <String>{}),
            ),
            incomingFriendRequestsProvider.overrideWith(
              (ref) => Stream.value(const <FriendRequest>[]),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: const MessagingScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Ana Test'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Photo'), findsOneWidget);
      await settle(tester);
    });
  });
}
