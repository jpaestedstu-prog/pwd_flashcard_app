import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/models/settings_presentation.dart';
import 'package:pwdpwdpwd/features/settings/screens/edit_profile_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Edit Profile's accessibility section, per kind of profile.
///
/// A Student's or a Child's accessibility needs are their Teacher's or
/// Parent's to manage (Manage Classes / Home Groups), so the learner sees
/// them — and who sets them — without a way to change them. A guest or a
/// Player still picks their own; an educator has none.

class _Stub extends ProfileNotifier {
  _Stub(this._kind);
  final ProfileKind _kind;

  @override
  UserProfile? build() => UserProfile(
    id: 'edit-${_kind.name}',
    name: 'Ana',
    role: switch (_kind) {
      ProfileKind.guestPlayer || ProfileKind.player => UserRole.player,
      ProfileKind.student => UserRole.student,
      ProfileKind.child => UserRole.child,
      ProfileKind.teacher => UserRole.teacher,
      ProfileKind.parent => UserRole.parent,
    },
    isGuestPlayer: _kind == ProfileKind.guestPlayer,
    disabilityType: DisabilityType.hearing,
    createdAt: DateTime(2026),
  );
}

/// Every text on the whole form, scrolled top to bottom.
Future<Set<String>> _wholeForm(WidgetTester tester, ProfileKind kind) async {
  tester.view.physicalSize = const Size(800, 1280) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [profileProvider.overrideWith(() => _Stub(kind))],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditProfileScreen(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  final seen = <String>{};
  void collect() {
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      final text = widget.data ?? widget.textSpan?.toPlainText();
      if (text != null) seen.add(text);
    }
  }

  final position =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  collect();
  for (var i = 0; i < 200 && position.extentAfter > 0; i++) {
    position.jumpTo(position.pixels + 300);
    await tester.pump(const Duration(milliseconds: 300));
    collect();
  }
  expect(position.extentAfter, 0, reason: 'reached the end');
  await tester.pumpWidget(const SizedBox.shrink());
  return seen;
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/edit_profile_accessibility');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  const picker =
      'Changing this will offer to auto-configure accessibility settings';
  const byTeacher =
      'Set by your teacher in Manage Classes. Ask them if something needs to change.';
  const byParent =
      'Set by your parent in Home Groups. Ask them if something needs to change.';

  testWidgets('a Student sees their needs, set by their teacher', (
    tester,
  ) async {
    final seen = await _wholeForm(tester, ProfileKind.student);
    expect(seen, contains(byTeacher));
    expect(seen, contains('Hearing Impairment'));
    expect(seen, isNot(contains(picker)));
    // No other category to pick, and no supports to change.
    expect(seen, isNot(contains('Visual Impairment')));
    expect(seen, isNot(contains('Learner Support')));
  });

  testWidgets('a Child sees their needs, set by their parent', (tester) async {
    final seen = await _wholeForm(tester, ProfileKind.child);
    expect(seen, contains(byParent));
    expect(seen, contains('Hearing Impairment'));
    expect(seen, isNot(contains(picker)));
    expect(seen, isNot(contains('Visual Impairment')));
  });

  for (final kind in const [ProfileKind.guestPlayer, ProfileKind.player]) {
    testWidgets('a ${kind.name} still picks their own', (tester) async {
      final seen = await _wholeForm(tester, kind);
      expect(seen, contains(picker));
      expect(seen, contains('Visual Impairment'));
      expect(seen, contains('Learner Support'));
      expect(seen, isNot(contains(byTeacher)));
      expect(seen, isNot(contains(byParent)));
    });
  }

  for (final kind in const [ProfileKind.teacher, ProfileKind.parent]) {
    testWidgets('a ${kind.name} has no category of their own', (tester) async {
      final seen = await _wholeForm(tester, kind);
      expect(seen, isNot(contains(picker)));
      expect(seen, isNot(contains(byTeacher)));
      expect(seen, isNot(contains(byParent)));
      expect(seen, isNot(contains('Hearing Impairment')));
    });
  }
}
