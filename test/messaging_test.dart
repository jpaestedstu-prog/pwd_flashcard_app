import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/widgets/pro_surface.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_dpad_scope.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/voice_control_mixin.dart';
import 'package:pwdpwdpwd/features/home/widgets/home_tile.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/services/friend_service.dart';
import 'package:pwdpwdpwd/features/messaging/providers/messaging_providers.dart';
import 'package:pwdpwdpwd/features/messaging/screens/messaging_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// The Messages surface across Player-with-Progress, Student/Child, and
/// Teacher/Parent profiles.
///
/// These lock the behaviours that were previously broken or missing:
/// unread accounting, role-appropriate quick replies, a composer draft that
/// survives a quick-reply tap, and an inbox that tells each audience the
/// right thing when it's empty.

const _me = 'me-profile';
const _peer = 'peer-profile';

LocalMessage _msg({
  required String id,
  required String from,
  required String to,
  String content = 'hello',
  bool isRead = false,
  DateTime? at,
  MessageType type = MessageType.text,
}) =>
    LocalMessage(
      id: id,
      senderId: from,
      senderName: from,
      recipientId: to,
      content: content,
      type: type,
      timestamp: at ?? DateTime(2026, 8, 10, 15, 42),
      isRead: isRead,
    );

Conversation _convo(List<LocalMessage> messages, {String role = 'student'}) =>
    Conversation(
      otherProfileId: _peer,
      otherProfileName: 'Peer',
      otherProfileRole: role,
      messages: messages,
    );

UserProfile _profile(UserRole role, {bool guest = false}) => UserProfile(
      id: _me,
      name: 'Test User',
      role: role,
      isGuestPlayer: guest,
      createdAt: DateTime(2026),
    );

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._profile);
  final UserProfile? _profile;
  @override
  UserProfile? build() => _profile;
}

/// Gaze Control on, so [GazeDpadScope] arms instead of staying inert.
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

void main() {
  group('unread accounting', () {
    test('counts only messages the peer sent me and I have not opened', () {
      final convo = _convo([
        _msg(id: 'a', from: _peer, to: _me),
        _msg(id: 'b', from: _peer, to: _me),
        _msg(id: 'c', from: _peer, to: _me, isRead: true),
      ]);
      expect(convo.unreadCount, 2);
      expect(convo.unreadMessages.map((m) => m.id), ['a', 'b']);
    });

    test('my own unsent-receipt messages never count as unread', () {
      // The regression this exists for: the original getter was
      // `!isRead && senderId != otherProfileId`, which counted MY OWN
      // outgoing messages (they stay `isRead: false` until the recipient
      // opens them) and so badged every thread I had ever written in.
      final convo = _convo([
        _msg(id: 'mine-1', from: _me, to: _peer),
        _msg(id: 'mine-2', from: _me, to: _peer),
      ]);
      expect(convo.unreadCount, 0);
      expect(convo.unreadMessages, isEmpty);
    });

    test('a fully-read thread reports zero', () {
      final convo = _convo([
        _msg(id: 'a', from: _peer, to: _me, isRead: true),
        _msg(id: 'b', from: _me, to: _peer),
      ]);
      expect(convo.unreadCount, 0);
    });

    test('an empty thread reports zero', () {
      expect(_convo(const []).unreadCount, 0);
      expect(_convo(const []).lastMessage, isNull);
    });
  });

  group('role-aware quick replies', () {
    test('an educator writing to a learner gets encouragements', () {
      final chips = QuickEncouragements.forAudience(
        senderRole: 'teacher',
        recipientRole: 'student',
      );
      expect(chips, same(QuickEncouragements.encouragements));
      expect(chips.map((c) => c['en']), contains("I'm proud of you! 💪"));
    });

    test('a parent writing to their child also gets encouragements', () {
      expect(
        QuickEncouragements.forAudience(
          senderRole: 'parent',
          recipientRole: 'child',
        ),
        same(QuickEncouragements.encouragements),
      );
    });

    test('a learner writing to their teacher gets learner phrases', () {
      // The bug: a student was offered "I'm proud of you!" to send to their
      // own teacher, because one educator-voiced list was used both ways.
      final chips = QuickEncouragements.forAudience(
        senderRole: 'student',
        recipientRole: 'teacher',
      );
      expect(chips, same(QuickEncouragements.toEducator));
      expect(chips.map((c) => c['en']), contains('I need help please 🙋'));
      expect(
        chips.map((c) => c['en']),
        isNot(contains("I'm proud of you! 💪")),
      );
    });

    test('a learner writing to a friend gets peer phrases', () {
      final chips = QuickEncouragements.forAudience(
        senderRole: 'player',
        recipientRole: 'student',
      );
      expect(chips, same(QuickEncouragements.toFriend));
      expect(chips.map((c) => c['en']), contains('Want to play? 🎮'));
    });

    test('every chip carries both languages and is non-empty', () {
      for (final list in [
        QuickEncouragements.encouragements,
        QuickEncouragements.toEducator,
        QuickEncouragements.toFriend,
      ]) {
        for (final chip in list) {
          expect(chip['en'], isNotNull);
          expect(chip['fil'], isNotNull);
          expect(chip['en']!.trim(), isNotEmpty);
          expect(chip['fil']!.trim(), isNotEmpty);
        }
      }
    });
  });

  group('message time formatting', () {
    test('clock renders a 12-hour time with a padded minute', () {
      expect(MessageTime.clock(DateTime(2026, 8, 10, 15, 42)), '3:42 PM');
      expect(MessageTime.clock(DateTime(2026, 8, 10, 9, 5)), '9:05 AM');
    });

    test('midnight and noon do not render as hour zero', () {
      expect(MessageTime.clock(DateTime(2026, 8, 10)), '12:00 AM');
      expect(MessageTime.clock(DateTime(2026, 8, 10, 12)), '12:00 PM');
    });

    test('relative ages step from Now through a calendar date', () {
      final now = DateTime(2026, 8, 10, 12);
      String rel(Duration ago) => MessageTime.relative(
            now.subtract(ago),
            isFilipino: false,
            now: now,
          );
      expect(rel(const Duration(seconds: 20)), 'Now');
      expect(rel(const Duration(minutes: 5)), '5m');
      expect(rel(const Duration(hours: 3)), '3h');
      expect(rel(const Duration(days: 2)), '2d');
      expect(rel(const Duration(days: 30)), '07/11');
    });

    test('relative localises the freshest bucket', () {
      final now = DateTime(2026, 8, 10, 12);
      expect(
        MessageTime.relative(now, isFilipino: true, now: now),
        'Ngayon',
      );
    });

    test('day labels name today and yesterday', () {
      final now = DateTime(2026, 8, 10, 12);
      expect(
        MessageTime.dayLabel(now, isFilipino: false, now: now),
        'Today',
      );
      expect(
        MessageTime.dayLabel(
          now.subtract(const Duration(days: 1)),
          isFilipino: false,
          now: now,
        ),
        'Yesterday',
      );
      expect(
        MessageTime.dayLabel(
          now.subtract(const Duration(days: 1)),
          isFilipino: true,
          now: now,
        ),
        'Kahapon',
      );
      expect(
        MessageTime.dayLabel(
          DateTime(2026, 7, 4),
          isFilipino: false,
          now: now,
        ),
        '2026-07-04',
      );
    });
  });

  group('inbox audience', () {
    test('students, children, and progress players use friends', () {
      expect(profileUsesFriends(_profile(UserRole.student)), isTrue);
      expect(profileUsesFriends(_profile(UserRole.child)), isTrue);
      expect(profileUsesFriends(_profile(UserRole.player)), isTrue);
    });

    test('guest players and educators do not', () {
      expect(
        profileUsesFriends(_profile(UserRole.player, guest: true)),
        isFalse,
      );
      expect(profileUsesFriends(_profile(UserRole.teacher)), isFalse);
      expect(profileUsesFriends(_profile(UserRole.parent)), isFalse);
    });

    test('a guest player is its own inbox kind, not an educator', () {
      // The bug: `isEducator = !usesFriends` put guest players in the
      // educator branch, so a child in Player mode was told "no students in
      // your classes yet".
      expect(
        inboxKindFor(_profile(UserRole.player, guest: true)),
        InboxKind.guestPlayer,
      );
      expect(
        inboxKindFor(_profile(UserRole.teacher)),
        InboxKind.educatorRoster,
      );
      expect(
        inboxKindFor(_profile(UserRole.parent)),
        InboxKind.educatorRoster,
      );
      expect(
        inboxKindFor(_profile(UserRole.student)),
        InboxKind.learnerWithFriends,
      );
      expect(
        inboxKindFor(_profile(UserRole.player)),
        InboxKind.learnerWithFriends,
      );
    });
  });

  group('safeguarding rules', () {
    // Reporting is the one route a child has if an adult behaves badly, and
    // it must not cost them their teacher. `reportUser(alsoBlock:)` carries
    // that decision, and the sheet derives it from the peer's role.
    bool alsoBlockForRole(String role) {
      final r = role.toLowerCase();
      final isEducator = r == 'teacher' || r == 'parent';
      return !isEducator;
    }

    test('reporting a classroom educator does not block them', () {
      expect(alsoBlockForRole('teacher'), isFalse);
      expect(alsoBlockForRole('parent'), isFalse);
    });

    test('reporting a peer learner does block them', () {
      expect(alsoBlockForRole('student'), isTrue);
      expect(alsoBlockForRole('child'), isTrue);
      expect(alsoBlockForRole('player'), isTrue);
    });

    test('block ids are directional, so a block is never inferable in reverse',
        () {
      final forward = FriendService.blockId('a', 'b');
      final reverse = FriendService.blockId('b', 'a');
      expect(forward, 'a_b');
      expect(reverse, 'b_a');
      expect(forward, isNot(reverse));
      // Unlike Friendship.makeId, which is a sorted pair and therefore the
      // same doc from either side.
      expect(Friendship.makeId('a', 'b'), Friendship.makeId('b', 'a'));
    });
  });

  group('unread badge provider', () {
    ProviderContainer containerFor(UserProfile? profile) {
      final container = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(profile)),
          activeProfileMessagesProvider.overrideWith(
            (ref) => Stream.value([
              _msg(id: 'a', from: _peer, to: _me),
              _msg(id: 'b', from: _peer, to: _me),
              _msg(id: 'c', from: _peer, to: _me, isRead: true),
              _msg(id: 'mine', from: _me, to: _peer),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('counts inbound unread for the active profile', () async {
      final container = containerFor(_profile(UserRole.student));
      await container.read(activeProfileMessagesProvider.future);
      expect(container.read(unreadMessageCountProvider), 2);
    });

    test('is zero when there is no active profile', () {
      final container = containerFor(null);
      expect(container.read(unreadMessageCountProvider), 0);
    });

    test('is zero while the stream is still loading', () {
      final container = ProviderContainer(
        overrides: [
          profileProvider
              .overrideWith(() => _StubProfileNotifier(_profile(UserRole.student))),
          activeProfileMessagesProvider.overrideWith(
            (ref) => const Stream<List<LocalMessage>>.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(unreadMessageCountProvider), 0);
    });
  });

  group('tile unread badges', () {
    Widget harness(Widget child) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 200, height: 160, child: child),
            ),
          ),
        );

    testWidgets('HomeTile draws a count when there are unread messages',
        (tester) async {
      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
          badgeCount: 3,
        ),
      ));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('HomeTile draws nothing at zero or null', (tester) async {
      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
          badgeCount: 0,
        ),
      ));
      expect(find.text('0'), findsNothing);

      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
        ),
      ));
      expect(find.textContaining('new'), findsNothing);
    });

    testWidgets('HomeTile caps the badge at 99+', (tester) async {
      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
          badgeCount: 250,
        ),
      ));
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('ProActionTile draws the educator badge', (tester) async {
      await tester.pumpWidget(harness(
        ProActionTile(
          icon: Icons.message_rounded,
          label: 'Messages',
          onTap: () {},
          badgeCount: 7,
        ),
      ));
      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('a badge does not change the tile geometry', (tester) async {
      // Caught on-device: the badge Stack handed its non-positioned child
      // *loose* constraints, so a badged tile shrink-wrapped and drew
      // narrower than its unbadged neighbours, with the pip floating in the
      // gap beside it instead of on the corner.
      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
        ),
      ));
      final plain = tester.getSize(find.byType(HomeTile));

      await tester.pumpWidget(harness(
        HomeTile(
          emoji: '💌',
          label: 'Messages',
          gradient: const [Colors.purple, Colors.deepPurple],
          onTap: () {},
          badgeCount: 4,
        ),
      ));
      expect(tester.getSize(find.byType(HomeTile)), plain);

      await tester.pumpWidget(harness(
        ProActionTile(
          icon: Icons.message_rounded,
          label: 'Messages',
          onTap: () {},
        ),
      ));
      final plainPro = tester.getSize(find.byType(ProActionTile));

      await tester.pumpWidget(harness(
        ProActionTile(
          icon: Icons.message_rounded,
          label: 'Messages',
          onTap: () {},
          badgeCount: 4,
        ),
      ));
      expect(tester.getSize(find.byType(ProActionTile)), plainPro);
    });

    testWidgets('a badged tile stays overflow-free at 2.0x text scale',
        (tester) async {
      // Big-font learners are the ones most likely to have the badge crowd
      // the label, so the pip is drawn outside the padded content.
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 160,
                height: 140,
                child: HomeTile(
                  emoji: '💌',
                  label: 'Messages',
                  gradient: const [Colors.purple, Colors.deepPurple],
                  onTap: () {},
                  compact: true,
                  badgeCount: 12,
                ),
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('messaging screen shell', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/messaging');
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
        if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
      }
    });

    tearDownAll(() async {
      await Hive.deleteFromDisk()
          .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
    });

    Future<void> pumpInbox(WidgetTester tester, UserProfile profile) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileProvider.overrideWith(() => _StubProfileNotifier(profile)),
          activeProfileMessagesProvider
              .overrideWith((ref) => Stream.value(const <LocalMessage>[])),
        ],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MessagingScreen(),
        ),
      ));
      await tester.pump();
    }

    testWidgets('a guest player is not told about classes they cannot have',
        (tester) async {
      await pumpInbox(tester, _profile(UserRole.player, guest: true));
      expect(find.textContaining('No students in your classes'), findsNothing);
      expect(find.textContaining('Player mode stays on this device'),
          findsOneWidget);
      // Guest players have no cloud identity, so no friend tools.
      expect(find.text('Add Friend'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an educator sees the roster empty state', (tester) async {
      await pumpInbox(tester, _profile(UserRole.teacher));
      expect(
        find.textContaining('No students in your classes'),
        findsOneWidget,
      );
      expect(find.text('Add Friend'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a progress player gets friend tools and the friends copy',
        (tester) async {
      await pumpInbox(tester, _profile(UserRole.player));
      expect(find.textContaining('No friends yet'), findsOneWidget);
      expect(find.text('Add Friend'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('gaze users get a way out and a reachable Add Friend',
        (tester) async {
      // The gap this closes: the Home hub publishes a "Messages" gaze cell
      // (gaze_hub_coverage_test), so a head-only learner could *open*
      // Messages — and then reach nothing inside it, including the back
      // arrow. Messages was a room with no door.
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      addTearDown(() {
        while (gazeCameraOwners.isBusy) {
          gazeCameraOwners.release();
        }
      });

      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileProvider.overrideWith(
              () => _StubProfileNotifier(_profile(UserRole.player))),
          activeProfileMessagesProvider
              .overrideWith((ref) => Stream.value(const <LocalMessage>[])),
          gazeSettingsProvider.overrideWith(_GazeOnNotifier.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MessagingScreen(
            camerasLoader: () async => const <CameraDescription>[],
            detectorFactory: _FakeDetector.new,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      // The hands-free exit exists.
      expect(find.byType(GazeDpadScope), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);

      // And the screen's own control is addressable by name, so a spoken
      // command or a blink on the ring reaches it.
      final voice =
          tester.state(find.byType(GazeDpadScope)) as VoiceControlMixin;
      voice.onVoiceCommand('add friend');
      await tester.pump();
      expect(find.text('Add a friend'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
