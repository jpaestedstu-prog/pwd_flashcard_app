import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/classroom/widgets/group_management_view.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/animated_gradient_background.dart';

import 'support/screen_matrix.dart';

/// The teacher's "Manage Classes" and the parent's "Home Groups" are one
/// widget — [GroupManagementView] — behind two delegates. These tests pin
/// that down from both directions:
///
///   * **Parity**: every roster feature (join code, accessibility audience,
///     group menu, per-member menu, multi-select) is present for both
///     audiences, because both render the same tree.
///   * **Layout**: the *populated* card + roster layout survives the device ×
///     font-scale matrix. The screen-level matrices in
///     `profile_screens_overflow_test.dart` only reach the empty state (no
///     Firebase in tests), so the card layout needs its own coverage.
class _FakeDelegate extends GroupManagementDelegate {
  _FakeDelegate({
    required this.isParent,
    required this.groups,
    required this.members,
  });

  final bool isParent;
  final List<ManagedGroup> groups;
  final List<ManagedMember> members;

  /// Records what the view asked us to do, so behaviour tests can assert on
  /// the wiring without touching Firestore.
  final List<String> calls = [];

  @override
  String get screenTitle => isParent ? 'Home Groups' : 'Manage Classes';

  @override
  String get groupNoun => isParent ? 'home group' : 'class';

  @override
  String get groupNounPlural => isParent ? 'home groups' : 'classes';

  @override
  String get memberNoun => isParent ? 'child' : 'student';

  @override
  String get memberNounPlural => isParent ? 'children' : 'students';

  @override
  IconData get groupIcon =>
      isParent ? Icons.family_restroom_rounded : Icons.school_rounded;

  @override
  IconData get memberIcon =>
      isParent ? Icons.child_care_rounded : Icons.people_rounded;

  @override
  String get createHint => 'e.g. Something';

  @override
  String get leaderboardKind => isParent ? 'homeGroup' : 'classroom';

  @override
  GradientPreset get gradientPreset =>
      isParent ? GradientPreset.home : GradientPreset.assessment;

  @override
  Color get accent => isParent ? AppColors.secondary : AppColors.sectionLearning;

  @override
  String get emptyEmoji => isParent ? '👨‍👩‍👧' : '🏫';

  @override
  String get shareBlurb => 'Enter the code in the app.';

  @override
  AsyncValue<List<ManagedGroup>> watchGroups(WidgetRef ref) =>
      AsyncValue.data(groups);

  @override
  AsyncValue<List<ManagedMember>> watchMembers(WidgetRef ref, String groupId) =>
      AsyncValue.data(members);

  @override
  Future<void> refresh(WidgetRef ref) async => calls.add('refresh');

  @override
  Future<void> createGroup(
    WidgetRef ref,
    String name,
    DisabilityType accessibility,
  ) async => calls.add('create:$name');

  @override
  Future<void> renameGroup(
    WidgetRef ref,
    ManagedGroup group,
    String name,
  ) async => calls.add('rename:${group.id}:$name');

  @override
  Future<void> setAccessibility(
    WidgetRef ref,
    ManagedGroup group,
    DisabilityType accessibility,
  ) async => calls.add('accessibility:${group.id}');

  @override
  Future<void> regenerateCode(WidgetRef ref, ManagedGroup group) async =>
      calls.add('regen:${group.id}');

  @override
  Future<void> deleteGroup(WidgetRef ref, ManagedGroup group) async =>
      calls.add('delete:${group.id}');

  @override
  Future<void> renameMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
    String displayName,
  ) async => calls.add('renameMember:$profileId');

  @override
  Future<void> removeMember(
    WidgetRef ref,
    ManagedGroup group,
    String profileId,
  ) async => calls.add('removeMember:$profileId');

  @override
  Future<void> removeMembers(
    WidgetRef ref,
    ManagedGroup group,
    List<String> profileIds,
  ) async => calls.add('removeMembers:${profileIds.join(",")}');
}

ManagedGroup _group({String id = 'g1', String name = 'Grade 3 - Math'}) =>
    ManagedGroup(
      id: id,
      code: 'ABC123',
      name: name,
      accessibility: DisabilityType.hearing,
      source: Object(),
    );

List<ManagedMember> _members() => [
  ManagedMember(
    profileId: 'p1',
    displayName: 'Ana Reyes',
    joinedAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  ManagedMember(
    profileId: 'p2',
    displayName: 'Ben Cruz',
    joinedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
    id: 'test-profile',
    name: 'Test User',
    role: _role,
    createdAt: DateTime(2026),
  );
}

List<Override> _asRole(UserRole role) => [
  profileProvider.overrideWith(() => _StubProfileNotifier(role)),
];

/// `pumpAndSettle` can never be used here: [AnimatedGradientBackground] runs a
/// `repeat()`ing controller, so frames are always scheduled. Pump fixed steps
/// instead — enough to flush entrance animations, dialog/menu transitions and
/// flutter_animate's zero-duration restart timers.
Future<void> _advance(WidgetTester tester, [int steps = 5]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeDelegate delegate, {
  UserRole role = UserRole.teacher,
}) async {
  // A tall surface so the whole card — header, code row and both roster rows —
  // is on screen. At the 800x600 default the roster sits under the FAB and
  // gestures land on the wrong widget.
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _asRole(role),
      child: MaterialApp(home: GroupManagementView(delegate: delegate)),
    ),
  );
  await _advance(tester);
  // Unmount at the end so the repeating ticker and any pending one-shot
  // timers are disposed before the test framework's end-of-test assertions.
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/group_management');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'sessions',
      'error_logs',
    ]) {
      if (!Hive.isBoxOpen(name)) await Hive.openBox(name);
    }
    await SyncQueueStorage.init();
  });

  // ─── Feature parity between the two audiences ──────────────────

  for (final isParent in const [true, false]) {
    final label = isParent ? 'parent / home groups' : 'teacher / classes';

    testWidgets('$label renders the join code, audience and roster', (
      tester,
    ) async {
      final delegate = _FakeDelegate(
        isParent: isParent,
        groups: [_group()],
        members: _members(),
      );
      await _pumpView(
        tester,
        delegate,
        role: isParent ? UserRole.parent : UserRole.teacher,
      );

      expect(find.text(delegate.screenTitle), findsOneWidget);
      expect(find.text('Grade 3 - Math'), findsOneWidget);
      // Join code, accessibility audience chip, and both roster rows.
      expect(find.text('ABC123'), findsOneWidget);
      expect(
        find.textContaining(DisabilityType.hearing.label),
        findsWidgets,
      );
      expect(find.text('Ana Reyes'), findsOneWidget);
      expect(find.text('Ben Cruz'), findsOneWidget);
      // Member count uses the audience's own noun.
      expect(find.text('2 ${delegate.memberNounPlural}'), findsOneWidget);
    });

    testWidgets('$label exposes the full group action menu', (tester) async {
      final delegate = _FakeDelegate(
        isParent: isParent,
        groups: [_group()],
        members: _members(),
      );
      await _pumpView(
        tester,
        delegate,
        role: isParent ? UserRole.parent : UserRole.teacher,
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await _advance(tester);

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Accessibility'), findsOneWidget);
      expect(find.text('New join code'), findsOneWidget);
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('Delete ${delegate.groupNoun}'), findsOneWidget);
    });

    testWidgets('$label exposes the full per-member action menu', (
      tester,
    ) async {
      final delegate = _FakeDelegate(
        isParent: isParent,
        groups: [_group()],
        members: _members(),
      );
      await _pumpView(
        tester,
        delegate,
        role: isParent ? UserRole.parent : UserRole.teacher,
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
      await _advance(tester);

      for (final label in const [
        'Rename',
        'View progress',
        'Notes',
        'Time limits',
        'Alarms',
        'Unlock screen',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing "$label"');
      }
      expect(
        find.text('Remove from ${delegate.groupNoun}'),
        findsOneWidget,
      );
    });

    testWidgets('$label long-press starts multi-select and bulk removal', (
      tester,
    ) async {
      final delegate = _FakeDelegate(
        isParent: isParent,
        groups: [_group()],
        members: _members(),
      );
      await _pumpView(
        tester,
        delegate,
        role: isParent ? UserRole.parent : UserRole.teacher,
      );

      await tester.longPress(find.text('Ana Reyes'));
      await _advance(tester);
      expect(find.text('1 selected'), findsOneWidget);

      // Tapping the second row in selection mode adds it.
      await tester.tap(find.text('Ben Cruz'));
      await _advance(tester);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Remove (2)'));
      await _advance(tester);
      // Confirmation dialog, then the delegate call.
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await _advance(tester);
      expect(delegate.calls, contains('removeMembers:p1,p2'));
    });

    testWidgets('$label empty state offers to create one', (tester) async {
      final delegate = _FakeDelegate(
        isParent: isParent,
        groups: const [],
        members: const [],
      );
      await _pumpView(
        tester,
        delegate,
        role: isParent ? UserRole.parent : UserRole.teacher,
      );

      expect(find.text('No ${delegate.groupNounPlural} yet'), findsOneWidget);
      expect(find.text('Create ${delegate.groupNoun}'), findsOneWidget);
    });
  }

  testWidgets('the roster collapses and expands', (tester) async {
    final delegate = _FakeDelegate(
      isParent: false,
      groups: [_group()],
      members: _members(),
    );
    await _pumpView(tester, delegate);

    expect(find.text('Ana Reyes'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.expand_less_rounded));
    await _advance(tester);
    expect(find.text('Ana Reyes'), findsNothing);
    // The join code stays visible when collapsed — it's the thing educators
    // come here to read out loud.
    expect(find.text('ABC123'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await _advance(tester);
    expect(find.text('Ana Reyes'), findsOneWidget);
  });

  testWidgets('refresh reaches the delegate', (tester) async {
    final delegate = _FakeDelegate(
      isParent: false,
      groups: [_group()],
      members: _members(),
    );
    await _pumpView(tester, delegate);

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    expect(delegate.calls, contains('refresh'));
  });

  // ─── Populated layout across the device matrix ─────────────────

  for (final isParent in const [true, false]) {
    final label = isParent ? 'home groups' : 'classes';
    testWidgets('populated $label survive the device matrix', (tester) async {
      await expectScreenNoOverflowAcrossDevices(
        tester,
        () => GroupManagementView(
          delegate: _FakeDelegate(
            isParent: isParent,
            groups: [
              _group(),
              _group(id: 'g2', name: 'A very long second group name indeed'),
            ],
            members: _members(),
          ),
        ),
        overrides: _asRole(isParent ? UserRole.parent : UserRole.teacher),
      );
    });
  }
}
