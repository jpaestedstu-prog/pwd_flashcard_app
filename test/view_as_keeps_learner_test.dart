import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/core/services/learning_level_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home_group/screens/join_home_group_screen.dart';
import 'package:pwdpwdpwd/features/messaging/providers/messaging_providers.dart';
import 'package:pwdpwdpwd/features/onboarding/widgets/membership_eviction_gate.dart';
import 'package:pwdpwdpwd/features/onboarding/screens/student_profile_detail_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/membership_watcher_provider.dart';

import 'support/all_screens.dart';

/// On the tablet (4 Nov): a teacher or parent opening a learner from a list
/// saved the cloud's copy over the tablet's own. The cloud never holds a PIN, a
/// birth date or a grade, so they were gone, and a child lost their home group
/// and opened on "Join Home Group" from then on.
void main() {
  setUpAll(() => openMemoryBoxes('view_as_keeps_learner'));

  UserProfile parent() => UserProfile(
        id: 'parent-1',
        name: 'Mommy',
        role: UserRole.parent,
        createdAt: DateTime(2026),
      );

  /// As this tablet holds them: everything.
  UserProfile childHere(String id) => UserProfile(
        id: id,
        name: 'Anak',
        role: UserRole.child,
        createdAt: DateTime(2026),
        pinHash: 'hash',
        pinSalt: 'salt',
        pinHashAlgorithm: 'pbkdf2',
        birthDate: DateTime(2019, 1, 23),
        gradeLevel: GradeLevel.values.first,
        homeGroupId: 'group-1',
      );

  /// As the roster reads them from the cloud: no PIN, birth date or grade.
  UserProfile childFromCloud(String id) => UserProfile(
        id: id,
        name: 'Anak',
        role: UserRole.child,
        createdAt: DateTime(2026),
      );

  void expectWhole(UserProfile? child) {
    expect(child, isNotNull);
    expect(child!.pinHash, 'hash');
    expect(child.pinSalt, 'salt');
    expect(child.pinHashAlgorithm, 'pbkdf2');
    expect(child.birthDate, DateTime(2019, 1, 23));
    expect(child.gradeLevel, GradeLevel.values.first);
    expect(child.homeGroupId, 'group-1');
  }

  Future<ProviderContainer> educator() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await HiveService.saveProfile(parent());
    container.read(profileProvider.notifier).state = parent();
    return container;
  }

  test('looking at a learner on this tablet changes nothing about them',
      () async {
    await HiveService.saveProfile(childHere('here'));
    final before = HiveService.getProfiles().toString();
    final container = await educator();
    final notifier = container.read(profileProvider.notifier);

    await notifier.viewAsStudent(childFromCloud('here'));

    expectWhole(container.read(profileProvider));
    expect(container.read(profileProvider)!.id, 'here');
    expect(notifier.isViewingAsStudent, isTrue);
    expectWhole(HiveService.getProfileById('here'));

    await notifier.restoreEducatorProfile();

    expect(container.read(profileProvider)!.id, 'parent-1');
    expectWhole(HiveService.getProfileById('here'));
    expect(HiveService.getProfiles().toString(), contains('hash'));
    expect(before, contains('hash'));
  });

  test('messages and friends stay the viewer\'s while a learner is looked at',
      () async {
    // Andrei, owned by another device: the cloud refused his messages to this
    // tablet, and each refusal said "Something went wrong" (7 Nov).
    final container = await educator();
    final notifier = container.read(profileProvider.notifier);
    expect(container.read(messagingProfileProvider)?.id, 'parent-1');

    await notifier.viewAsStudent(childFromCloud('owned-elsewhere'));
    expect(container.read(profileProvider)?.id, 'owned-elsewhere');
    expect(container.read(messagingProfileProvider)?.id, 'parent-1');

    await notifier.restoreEducatorProfile();
    expect(container.read(messagingProfileProvider)?.id, 'parent-1');
  });

  test('a learner from another device is not left in this tablet\'s list',
      () async {
    final container = await educator();
    final notifier = container.read(profileProvider.notifier);

    await notifier.viewAsStudent(childFromCloud('elsewhere'));
    expect(container.read(profileProvider)!.id, 'elsewhere');
    expect(HiveService.getProfileById('elsewhere'), isNotNull);

    await notifier.restoreEducatorProfile();
    expect(container.read(profileProvider)!.id, 'parent-1');
    expect(HiveService.getProfileById('elsewhere'), isNull);
  });

  test('a copy owned elsewhere takes the cloud\'s words, keeps what it never holds',
      () {
    final here = childHere('x').copyWith(ownerUid: () => 'other-device');
    final fromCloud = childFromCloud('x').copyWith(name: 'New Name');

    expect(
      identical(
        learnerToView(fromCloud, childHere('x'), deviceUid: 'this-device'),
        fromCloud,
      ),
      isFalse,
    );
    final kept = learnerToView(fromCloud, here, deviceUid: 'this-device');
    expect(kept.name, 'New Name');
    expectWhole(kept);
  });

  test('a copy owned here is the very object: nothing is written', () {
    final here = childHere('y').copyWith(ownerUid: () => 'this-device');
    expect(
      identical(
        learnerToView(childFromCloud('y'), here, deviceUid: 'this-device'),
        here,
      ),
      isTrue,
    );
    final unowned = childHere('y');
    expect(
      identical(
        learnerToView(childFromCloud('y'), unowned, deviceUid: 'this-device'),
        unowned,
      ),
      isTrue,
    );
  });

  test('signing in on a device that holds the profile keeps what the cloud lacks',
      () {
    final source =
        File('lib/core/services/sync_service.dart').readAsStringSync();
    expect(source, contains('p.keepingPrivateFieldsOf(here)'));
    final kept = childFromCloud('z').keepingPrivateFieldsOf(childHere('z'));
    expectWhole(kept);
  });

  test('a child read from the cloud keeps their home group', () {
    final source = File('lib/data/remote/firestore_repository.dart')
        .readAsStringSync();
    expect(source, contains("homeGroupId: r['home_group_id'] as String?"));
    expect(source, contains("r['learning_level']"));
  });

  group('the level saved with a birth date', () {
    final seven = DateTime(DateTime.now().year - 7);

    test('a level they have stays', () {
      final learner = childFromCloud('l').copyWith(
        learningLevel: () => LearningLevel.advanced,
      );
      expect(
        LearningLevelService.levelToSave(learner, seven),
        LearningLevel.advanced,
      );
    });

    test('with none, the one first-time setup would give', () {
      expect(
        LearningLevelService.levelToSave(childFromCloud('l'), seven),
        LearningLevel.elementary,
      );
    });

    test('with no birth date, and for an educator, none', () {
      expect(LearningLevelService.levelToSave(childFromCloud('l'), null), isNull);
      expect(LearningLevelService.levelToSave(parent(), seven), isNull);
    });
  });

  testWidgets('no one is put out of a group while being looked at',
      (tester) async {
    await tester.runAsync(() => HiveService.saveProfile(childHere('looked')));
    final container = ProviderContainer(
      overrides: [
        homeGroupMembershipExistsProvider('looked')
            .overrideWith((_) => Stream.value(false)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(profileProvider.notifier);
    notifier.state = parent();
    await tester.runAsync(() => notifier.viewAsStudent(childFromCloud('looked')));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: MembershipEvictionGate(child: Text('The dashboard')),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('The dashboard'), findsOneWidget);
    expect(container.read(profileProvider)?.id, 'looked');
    expect(HiveService.getProfileById('looked')?.homeGroupId, 'group-1');
  });

  testWidgets('a learner\'s detail page offers Edit only on one\'s own profile',
      (tester) async {
    // Edit Profile edits whoever is signed in: on a learner's page, a parent
    // pressing it was editing their own profile.
    Future<ProviderContainer> show(UserProfile viewer, UserProfile shown) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(profileProvider.notifier).state = viewer;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: StudentProfileDetailScreen(profile: shown),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      return container;
    }

    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await show(parent(), childHere('detail'));
    expect(find.byIcon(Icons.edit_rounded), findsNothing);

    await show(childHere('detail'), childHere('detail'));
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
  });

  group('the Join Home Group page', () {
    tearDown(() => JoinHomeGroupScreen.debugMemberLookup = null);

    Future<ProviderContainer> pumpJoin(
      WidgetTester tester, {
      required Future<String?> Function(String) lookup,
    }) async {
      JoinHomeGroupScreen.debugMemberLookup = lookup;
      final child = childFromCloud('lost');
      await tester.runAsync(() => HiveService.saveProfile(child));
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(profileProvider.notifier).state = child;
      final router = GoRouter(
        initialLocation: '/join-home-group',
        routes: [
          GoRoute(
            path: '/join-home-group',
            builder: (_, _) => const JoinHomeGroupScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/profile-switcher',
            builder: (_, _) => const Scaffold(body: Text('The list')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      // The look-up, the save and the move, each with their own turn.
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      return container;
    }

    testWidgets('a child their group still lists goes straight in',
        (tester) async {
      final container = await pumpJoin(tester, lookup: (_) async => 'group-9');
      expect(find.text('Home'), findsOneWidget);
      expect(container.read(profileProvider)!.homeGroupId, 'group-9');
      expect(HiveService.getProfileById('lost')!.homeGroupId, 'group-9');
    });

    testWidgets('a child in no group is asked for the code', (tester) async {
      final container = await pumpJoin(tester, lookup: (_) async => null);
      expect(find.text('Home'), findsNothing);
      expect(container.read(profileProvider)!.homeGroupId, isNull);
    });

    testWidgets('offline, the page stays and nothing changes', (tester) async {
      final container = await pumpJoin(
        tester,
        lookup: (_) async => throw const SocketException('offline'),
      );
      expect(find.text('Home'), findsNothing);
      expect(container.read(profileProvider)!.homeGroupId, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Switch profile opens the list of profiles', (tester) async {
      await pumpJoin(tester, lookup: (_) async => null);
      await tester.tap(find.byIcon(Icons.switch_account_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('The list'), findsOneWidget);
    });
  });
}
