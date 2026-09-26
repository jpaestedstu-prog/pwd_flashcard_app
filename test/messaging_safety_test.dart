import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/messaging/models/composer_presentation.dart';
import 'package:pwdpwdpwd/features/messaging/models/friend_models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/providers/messaging_providers.dart';
import 'package:pwdpwdpwd/features/messaging/screens/messaging_screen.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/broadcast_sheet.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/friend_ui.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Messages, second pass: the gaps found driving it on a tablet.
///
///   * Blocking a friend who had written to you left them in the inbox with a
///     working composer — the history fallback re-added them.
///   * A report told the child "Sent to a grown-up" while landing in a
///     collection no grown-up can read.
///   * A teacher was offered "Remove friend" / "Block" on their own student.
///   * A learner's "Hi friend!" arrived under a pink "Encouragement" banner.
///   * Screen readers heard "H, try" — the avatar initial, never the sender.

const _me = 'me';

LocalMessage _msg(
  String id, {
  required String from,
  required String to,
  String content = 'hello',
  MessageType type = MessageType.text,
  bool isRead = false,
  int minute = 0,
}) => LocalMessage(
  id: id,
  senderId: from,
  senderName: from,
  recipientId: to,
  content: content,
  type: type,
  timestamp: DateTime(2026, 9, 26, 10, minute),
  isRead: isRead,
);

Conversation _peer(
  String id, {
  String role = 'student',
  bool connected = true,
  List<InboxGroup> groups = const [],
  List<LocalMessage> messages = const [],
}) => Conversation(
  otherProfileId: id,
  otherProfileName: id,
  otherProfileRole: role,
  isConnected: connected,
  groups: groups,
  messages: messages,
);

UserProfile _profile(
  UserRole role, {
  String? classroomId,
  DisabilityType disability = DisabilityType.none,
}) => UserProfile(
  id: _me,
  name: 'Me',
  role: role,
  createdAt: DateTime(2026),
  classroomId: classroomId,
  disabilityType: disability,
);

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._profile);
  final UserProfile? _profile;
  @override
  UserProfile? build() => _profile;
}

void main() {
  group('assembleInbox', () {
    test('a blocked peer never comes back through the history fallback', () {
      // The on-device bug: block a friend who has written to you, and the
      // fallback re-added them because they had "inbound messages".
      final inbox = assembleInbox(
        myProfileId: _me,
        peers: const [],
        messages: [_msg('1', from: 'bully', to: _me)],
        blockedIds: const {'bully'},
      );
      expect(inbox, isEmpty);
    });

    test('a blocked directory peer is dropped too', () {
      final inbox = assembleInbox(
        myProfileId: _me,
        peers: [_peer('bully')],
        messages: const [],
        blockedIds: const {'bully'},
      );
      expect(inbox, isEmpty);
    });

    test('history without a link is shown read-only', () {
      final inbox = assembleInbox(
        myProfileId: _me,
        peers: [_peer('friend')],
        messages: [
          _msg('1', from: 'friend', to: _me, minute: 1),
          _msg('2', from: 'ex-friend', to: _me, minute: 2),
        ],
      );
      final byId = {for (final c in inbox) c.otherProfileId: c};
      expect(byId['friend']!.isConnected, isTrue);
      expect(byId['ex-friend']!.isConnected, isFalse);
      // Newest first.
      expect(inbox.first.otherProfileId, 'ex-friend');
    });

    test('my own messages alone never resurrect a thread', () {
      final inbox = assembleInbox(
        myProfileId: _me,
        peers: const [],
        messages: [_msg('1', from: _me, to: 'someone')],
      );
      expect(inbox, isEmpty);
    });

    test('directory metadata survives the merge', () {
      final inbox = assembleInbox(
        myProfileId: _me,
        peers: [
          const Conversation(
            otherProfileId: 'deaf',
            otherProfileName: 'Deaf',
            otherProfileRole: 'student',
            otherDisabilityIndex: 1,
            groups: [InboxGroup(id: 'g', name: 'Hearing Class')],
          ),
        ],
        messages: [_msg('1', from: 'deaf', to: _me)],
      );
      expect(inbox.single.otherDisabilityIndex, 1);
      expect(inbox.single.groups.single.name, 'Hearing Class');
      expect(inbox.single.messages, hasLength(1));
    });
  });

  group('badges', () {
    ProviderContainer container({
      Set<String> blocked = const {},
      List<FriendRequest> requests = const [],
    }) {
      final c = ProviderContainer(
        overrides: [
          profileProvider.overrideWith(
            () => _StubProfileNotifier(_profile(UserRole.student)),
          ),
          activeProfileMessagesProvider.overrideWith(
            (ref) => Stream.value([
              _msg('a', from: 'friend', to: _me),
              _msg('b', from: 'bully', to: _me),
              _msg('c', from: 'bully', to: _me),
            ]),
          ),
          blockedProfileIdsProvider.overrideWith(
            (ref) => Stream.value(blocked),
          ),
          incomingFriendRequestsProvider.overrideWith(
            (ref) => Stream.value(requests),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('a blocked sender never badges the Messages tile', () async {
      final c = container(blocked: const {'bully'});
      await c.read(activeProfileMessagesProvider.future);
      await c.read(blockedProfileIdsProvider.future);
      expect(c.read(unreadMessageCountProvider), 1);
    });

    test('the tile counts waiting friend requests too', () async {
      final c = container(
        requests: [
          FriendRequest(
            id: 'x_me',
            fromProfileId: 'x',
            toProfileId: _me,
            fromOwnerUid: 'u',
            fromDisplayName: 'X',
            status: FriendRequestStatus.pending,
            createdAt: DateTime(2026),
          ),
        ],
      );
      await c.read(activeProfileMessagesProvider.future);
      await c.read(blockedProfileIdsProvider.future);
      await c.read(incomingFriendRequestsProvider.future);
      expect(c.read(unreadMessageCountProvider), 3);
      expect(c.read(messagesTileBadgeProvider), 4);
    });
  });

  group('quick replies', () {
    test('only an educator chip is an encouragement', () {
      expect(
        QuickEncouragements.typeFor(senderRole: 'teacher'),
        MessageType.encouragement,
      );
      expect(
        QuickEncouragements.typeFor(senderRole: 'parent'),
        MessageType.encouragement,
      );
      for (final role in ['student', 'child', 'player']) {
        expect(QuickEncouragements.typeFor(senderRole: role), MessageType.text);
      }
    });
  });

  group('message wording', () {
    test('a sign previews as a sign, not as typed text', () {
      final sign = _msg('1', from: 'x', to: _me, content: 'Apple',
          type: MessageType.sign);
      expect(MessageWording.preview(sign, isFilipino: false), '🤟 Sign: Apple');
      expect(
        MessageWording.preview(sign, isFilipino: true),
        '🤟 Senyas: Apple',
      );
    });

    test('a sticker is named in both languages', () {
      final sticker = _msg('1', from: 'x', to: _me, content: '👍',
          type: MessageType.sticker);
      expect(MessageWording.preview(sticker, isFilipino: false), '👍 thumbs up');
      expect(MessageWording.speakable(sticker, isFilipino: true), 'thumbs up');
      expect(
        MessageWording.speakable(
          _msg('2', from: 'x', to: _me, content: '🌈', type: MessageType.sticker),
          isFilipino: true,
        ),
        'bahaghari',
      );
    });

    test('a received bubble is announced by the sender name', () {
      final label = MessageWording.bubbleLabel(
        _msg('1', from: 'x', to: _me, content: 'try'),
        isMine: false,
        otherName: 'Hearing Student',
        isFilipino: false,
      );
      expect(label, startsWith('Hearing Student: try'));
    });

    test('my bubble carries its read receipt in words', () {
      final label = MessageWording.bubbleLabel(
        _msg('1', from: _me, to: 'x', content: 'hi', isRead: true),
        isMine: true,
        otherName: 'X',
        isFilipino: false,
      );
      expect(label, startsWith('You: hi'));
      expect(label, endsWith(', read'));
    });

    test('read-aloud text drops emoji', () {
      expect(MessageWording.stripEmoji('Great job! Keep it up! 🌟'),
          'Great job! Keep it up!');
      expect(MessageWording.stripEmoji("I'm proud of you! 💪"),
          "I'm proud of you!");
      expect(MessageWording.stripEmoji('Tapos na po ako ✅'), 'Tapos na po ako');
      expect(MessageWording.stripEmoji('👨‍👩‍👦'), isEmpty);
    });

    test('an unknown future type still reads as text', () {
      final json = _msg('1', from: 'x', to: _me).toJson()..['type'] = 99;
      expect(LocalMessage.fromJson(json).type, MessageType.text);
      // `report` was appended, so every older index keeps its meaning.
      expect(MessageType.sign.index, 4);
      expect(MessageType.report.index, 5);
    });
  });

  group('safety reports', () {
    final teacher = _peer('kevin', role: 'teacher');
    final parent = _peer('mommy', role: 'parent');

    test('a report reaches every grown-up except the one reported', () {
      expect(
        SafetyReport.recipients(
          grownUps: [teacher, parent],
          reportedId: 'bully',
        ).map((c) => c.otherProfileId),
        ['kevin', 'mommy'],
      );
      expect(
        SafetyReport.recipients(
          grownUps: [teacher, parent],
          reportedId: 'kevin',
        ).map((c) => c.otherProfileId),
        ['mommy'],
      );
    });

    test('friends and history-only threads never receive a report', () {
      expect(
        SafetyReport.recipients(
          grownUps: [
            _peer('friend'),
            _peer('old-teacher', role: 'teacher', connected: false),
          ],
          reportedId: 'bully',
        ),
        isEmpty,
      );
    });

    test('the report quotes with curly quotes and is clipped', () {
      final text = SafetyReport.content(
        reportedName: 'Bully',
        reason: 'Mean words',
        quote: 'x' * 200,
        isFilipino: false,
      );
      expect(text, startsWith('I reported Bully: Mean words. They wrote: “'));
      expect(text, endsWith('…”'));
      expect(text.contains('"'), isFalse);
    });

    test('one report message per recipient, typed as a report', () {
      var n = 0;
      final messages = SafetyReport.messages(
        reporterId: _me,
        reporterName: 'Me',
        recipients: [teacher, parent],
        content: 'c',
        newId: () => 'id${n++}',
      );
      expect(messages.map((m) => m.recipientId), ['kevin', 'mommy']);
      expect(messages.every((m) => m.type == MessageType.report), isTrue);
      expect(messages.map((m) => m.id).toSet(), hasLength(2));
    });

    test('an unread report flags the educator inbox row', () {
      final convo = _peer('kid', messages: [
        _msg('1', from: 'kid', to: _me, type: MessageType.report),
      ]);
      expect(convo.hasUnreadReport, isTrue);
      expect(
        _peer('kid', messages: [
          _msg('1', from: 'kid', to: _me, type: MessageType.report,
              isRead: true),
        ]).hasUnreadReport,
        isFalse,
      );
    });
  });

  group('recipient hints and read aloud', () {
    test('a Deaf learner gets a sign suggestion', () {
      final hint = RecipientHint.forLearner(
        DisabilityType.hearing.index,
        isFilipino: false,
      )!;
      expect(hint.suggestsSign, isTrue);
      expect(hint.text, contains('sign'));
    });

    test('no hint without needs or without a category', () {
      expect(
        RecipientHint.forLearner(DisabilityType.none.index, isFilipino: false),
        isNull,
      );
      expect(RecipientHint.forLearner(null, isFilipino: false), isNull);
      expect(RecipientHint.forLearner(99, isFilipino: false), isNull);
    });

    test('every category with needs has a hint in both languages', () {
      for (final type in DisabilityType.values) {
        if (type == DisabilityType.none) continue;
        expect(
          RecipientHint.forLearner(type.index, isFilipino: false)?.text,
          isNotEmpty,
        );
        expect(
          RecipientHint.forLearner(type.index, isFilipino: true)?.text,
          isNotEmpty,
        );
      }
    });

    test('read aloud is off only for Deaf / hard-of-hearing learners', () {
      for (final type in DisabilityType.values) {
        expect(
          ComposerPresentation.forType(type).readAloud,
          type != DisabilityType.hearing,
          reason: type.name,
        );
      }
    });
  });

  group('broadcast targets', () {
    const g1 = InboxGroup(id: 'g1', name: 'Hearing Class');
    const g2 = InboxGroup(id: 'g2', name: 'Family', isHomeGroup: true);
    final convos = [
      _peer('a', groups: const [g1]),
      _peer('b', groups: const [g2]),
      _peer('left', connected: false, groups: const [g1]),
    ];

    test('everyone linked, never a learner who left', () {
      expect(broadcastTargets(convos).map((c) => c.otherProfileId), ['a', 'b']);
    });

    test('filtered to one group', () {
      expect(
        broadcastTargets(convos, groupId: 'g1').map((c) => c.otherProfileId),
        ['a'],
      );
    });

    test('one message per learner, same words and time', () {
      var n = 0;
      final msgs = broadcastMessages(
        sender: _profile(UserRole.teacher),
        targets: broadcastTargets(convos),
        content: 'No class tomorrow',
        type: MessageType.text,
        newId: () => 'm${n++}',
        now: DateTime(2026, 9, 26),
      );
      expect(msgs.map((m) => m.recipientId), ['a', 'b']);
      expect(msgs.map((m) => m.timestamp).toSet(), hasLength(1));
    });
  });

  group('widgets', () {
    setUpAll(() async {
      Hive.init('./build/test_cache/messaging_safety');
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

    Future<void> pumpScreen(
      WidgetTester tester, {
      required UserProfile profile,
      required List<LocalMessage> messages,
      Set<String> blocked = const {},
    }) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          const MessagingScreen(),
          overrides: [
            profileProvider.overrideWith(() => _StubProfileNotifier(profile)),
            activeProfileMessagesProvider.overrideWith(
              (ref) => Stream.value(messages),
            ),
            blockedProfileIdsProvider.overrideWith(
              (ref) => Stream.value(blocked),
            ),
            incomingFriendRequestsProvider.overrideWith(
              (ref) => Stream.value(const <FriendRequest>[]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('an ex-friend thread is readable but has no composer',
        (tester) async {
      await pumpScreen(
        tester,
        profile: _profile(UserRole.student),
        messages: [
          _msg('1', from: 'ExFriend', to: _me, content: 'hi there'),
        ],
      );
      await tester.tap(find.text('ExFriend'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining("You're not friends anymore"), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Send a sticker'), findsNothing);
      // The history itself is still there.
      expect(find.text('hi there'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('a blocked sender is not in the inbox at all', (tester) async {
      await pumpScreen(
        tester,
        profile: _profile(UserRole.student),
        messages: [_msg('1', from: 'Bully', to: _me, content: 'mean')],
        blocked: const {'Bully'},
      );
      expect(find.text('Bully'), findsNothing);
      expect(find.textContaining('No friends yet'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('a parent is told about their home group, not classes',
        (tester) async {
      await pumpScreen(
        tester,
        profile: _profile(UserRole.parent),
        messages: const [],
      );
      expect(find.textContaining('No children in your home group'),
          findsOneWidget);
      expect(find.textContaining('class code'), findsNothing);
      await settle(tester);
    });

    Future<void> openSheet(
      WidgetTester tester, {
      required UserProfile me,
      required Conversation convo,
      List<Conversation> grownUps = const [],
      VoidCallback? onSeeProgress,
    }) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPeerActionsSheet(
                    context,
                    me: me,
                    conversation: convo,
                    isFilipino: false,
                    onDone: () {},
                    grownUps: grownUps,
                    onSeeProgress: onSeeProgress,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a teacher gets no friend actions on their own student',
        (tester) async {
      await openSheet(
        tester,
        me: _profile(UserRole.teacher),
        convo: _peer(
          'Deaf Student',
          groups: const [InboxGroup(id: 'g', name: 'Hearing Class')],
        ),
        onSeeProgress: () {},
      );
      expect(find.text('Remove friend'), findsNothing);
      expect(find.text('Block'), findsNothing);
      expect(find.text('Report'), findsNothing);
      expect(find.textContaining('in your class (Hearing Class)'),
          findsOneWidget);
      expect(find.text('See their progress'), findsOneWidget);
    });

    testWidgets('a learner report names the grown-ups it reaches',
        (tester) async {
      await openSheet(
        tester,
        me: _profile(UserRole.student),
        convo: _peer('Bully'),
        grownUps: [
          _peer('Sir Kevin', role: 'teacher'),
          _peer('Mommy', role: 'parent'),
        ],
      );
      expect(find.text('Tells Sir Kevin, Mommy.'), findsOneWidget);
      expect(find.text('Remove friend'), findsOneWidget);
    });

    testWidgets('reporting the teacher tells only the parent', (tester) async {
      await openSheet(
        tester,
        me: _profile(UserRole.child),
        convo: _peer('Sir Kevin', role: 'teacher'),
        grownUps: [
          _peer('Sir Kevin', role: 'teacher'),
          _peer('Mommy', role: 'parent'),
        ],
      );
      expect(find.text('Tells Mommy.'), findsOneWidget);
      expect(find.text('Remove friend'), findsNothing);
    });

    testWidgets('with no grown-up, the report says so honestly',
        (tester) async {
      await openSheet(
        tester,
        me: _profile(UserRole.player),
        convo: _peer('Stranger'),
      );
      expect(find.text('Saves a report. Tell a grown-up too.'), findsOneWidget);
    });

    testWidgets('classmates can be asked with one tap', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AddFriendDialog(
              me: _profile(UserRole.student, classroomId: 'c1'),
              isFilipino: false,
              suggestions: (_) async => [
                DirectoryEntry(
                  username: 'ana-1234',
                  profileId: 'ana',
                  name: 'Ana',
                  roleIndex: UserRole.student.index,
                  ownerUid: 'u',
                  updatedAt: DateTime(2026),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Or pick someone from your class'), findsOneWidget);
      expect(find.text('🧑‍🎓 Ana'), findsOneWidget);
      expect(find.bySemanticsLabel('Ask Ana to be friends'), findsOneWidget);
    });

    testWidgets('no class, no suggestions', (tester) async {
      await tester.pumpWidget(
        app(
          Scaffold(
            body: AddFriendDialog(
              me: _profile(UserRole.player),
              isFilipino: false,
              suggestions: (_) async => fail('should not be asked'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('from your class'), findsNothing);
    });

    testWidgets('broadcast counts only the chosen group', (tester) async {
      const g1 = InboxGroup(id: 'g1', name: 'Hearing Class');
      const g2 = InboxGroup(id: 'g2', name: 'Visual Class');
      await tester.pumpWidget(
        app(
          Scaffold(
            body: BroadcastSheet(
              me: _profile(UserRole.teacher),
              isFilipino: false,
              groups: const [g1, g2],
              conversations: [
                _peer('a', groups: const [g1]),
                _peer('b', groups: const [g1]),
                _peer('c', groups: const [g2]),
                _peer('gone', connected: false, groups: const [g1]),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Send to 3 learners'), findsOneWidget);
      // Nothing to send yet.
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Send to 3 learners'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Hearing Class (2)'));
      await tester.pump();
      expect(find.text('Send to 2 learners'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'No class tomorrow');
      await tester.pump();
      final enabled = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Send to 2 learners'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(enabled.onPressed, isNotNull);
    });
  });

  group('big text on a small phone', () {
    // The worst case the overflow matrix knows: 2.0x font on 360x640. Every
    // new Messages surface has to survive it without a RenderFlex stripe.
    setUpAll(() async {
      Hive.init('./build/test_cache/messaging_safety_big');
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
    });

    Widget big(Widget home, {List<Override> overrides = const []}) =>
        ProviderScope(
          overrides: overrides,
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
            home: home,
          ),
        );

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    const longName = 'Maria Clara Dela Cruz Santos';

    testWidgets('educator inbox, report bubble and read-only bar',
        (tester) async {
      phone(tester);
      await tester.pumpWidget(
        big(
          const MessagingScreen(),
          overrides: [
            profileProvider.overrideWith(
              () => _StubProfileNotifier(_profile(UserRole.teacher)),
            ),
            activeProfileMessagesProvider.overrideWith(
              (ref) => Stream.value([
                _msg('1', from: longName, to: _me, content: 'Hello po!'),
                _msg(
                  '2',
                  from: longName,
                  to: _me,
                  type: MessageType.report,
                  minute: 2,
                  content: SafetyReport.content(
                    reportedName: 'Juan Miguel Reyes Bautista',
                    reason: 'They are bullying me',
                    quote: 'a long unkind message that goes on and on',
                    isFilipino: false,
                  ),
                ),
                _msg('3', from: 'Ana', to: _me, content: 'hi'),
              ]),
            ),
            blockedProfileIdsProvider.overrideWith(
              (ref) => Stream.value(const <String>{}),
            ),
            incomingFriendRequestsProvider.overrideWith(
              (ref) => Stream.value(const <FriendRequest>[]),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget); // the search box

      await tester.tap(find.text(longName));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      expect(find.text('Safety report'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('broadcast sheet', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        big(
          Scaffold(
            body: BroadcastSheet(
              me: _profile(UserRole.parent),
              isFilipino: true,
              groups: const [
                InboxGroup(id: 'a', name: 'Hearing Impairment Group',
                    isHomeGroup: true),
                InboxGroup(id: 'b', name: 'Cognitive/Learning Group',
                    isHomeGroup: true),
              ],
              conversations: [
                _peer('x', groups: const [
                  InboxGroup(id: 'a', name: 'Hearing Impairment Group',
                      isHomeGroup: true),
                ]),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('classmate suggestions', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        big(
          Scaffold(
            body: AddFriendDialog(
              me: _profile(UserRole.student, classroomId: 'c1'),
              isFilipino: true,
              suggestions: (_) async => [
                for (final n in [longName, 'Ana', 'Juan Miguel Bautista'])
                  DirectoryEntry(
                    username: '$n-1',
                    profileId: n,
                    name: n,
                    roleIndex: UserRole.student.index,
                    ownerUid: 'u',
                    updatedAt: DateTime(2026),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('educator peer sheet', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        big(
          Scaffold(
            body: PeerActionsSheet(
              me: _profile(UserRole.teacher),
              conversation: _peer(
                longName,
                groups: const [
                  InboxGroup(id: 'g', name: 'No Accessibility Needs Class'),
                ],
              ),
              isFilipino: true,
              onDone: () {},
              onSeeProgress: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
