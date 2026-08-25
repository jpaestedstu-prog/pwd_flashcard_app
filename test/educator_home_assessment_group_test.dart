import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/screens/educator_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Both educator roles get the Assessments & Progress group.
///
/// It existed only in `_buildTeacherChips`. A Parent — who enrols children
/// exactly as a teacher enrols students — had no tile into the assessment
/// module anywhere in the app, so "Assign Tasks" and "Track Progress" were
/// teacher-only in practice even though nothing about them is.
///
/// The two rosters differ in one place by design: a teacher's fourth tile
/// manages classes, a parent's manages home groups.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: 'Educator',
    role: _role,
    createdAt: DateTime(2026),
  );
}

void main() {
  setUpAll(() async {
    const cacheDir = './build/test_cache/educator_home_assessment_group';
    try {
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {
      // Still locked by a stray flutter_tester — Hive reports it below.
    }
    Hive.init(cacheDir);
    for (final name in const [
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
    await Hive.deleteFromDisk().timeout(
      const Duration(seconds: 15),
      onTimeout: () => <void>[],
    );
  });

  Future<void> pumpHome(WidgetTester tester, UserRole role) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [profileProvider.overrideWith(() => _StubProfileNotifier(role))],
        child: const MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EducatorHomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  /// The group sits well below the fold in a lazy `CustomScrollView`.
  ///
  /// Plain pumps, never `pumpAndSettle`: this screen's animated gradient
  /// backdrop never stops, so settling waits forever.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(CustomScrollView),
      const Offset(0, -320),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final role in const [UserRole.teacher, UserRole.parent]) {
    testWidgets('${role.name} home carries Assessments & Progress', (
      tester,
    ) async {
      await pumpHome(tester, role);
      await scrollTo(tester, find.text('ASSESSMENTS & PROGRESS'));

      expect(find.text('ASSESSMENTS & PROGRESS'), findsOneWidget);
      expect(find.text('Assessments'), findsOneWidget);
      expect(find.text('Assign Tasks'), findsOneWidget);
      expect(find.text('Track Progress'), findsOneWidget);
    });
  }

  testWidgets('the teacher\'s fourth tile manages classes', (tester) async {
    await pumpHome(tester, UserRole.teacher);
    await scrollTo(tester, find.text('ASSESSMENTS & PROGRESS'));

    expect(find.text('Manage Classes'), findsOneWidget);
    expect(find.text('Manage Groups'), findsNothing);
  });

  testWidgets('the parent\'s fourth tile manages home groups', (tester) async {
    await pumpHome(tester, UserRole.parent);
    await scrollTo(tester, find.text('ASSESSMENTS & PROGRESS'));

    expect(
      find.text('Manage Groups'),
      findsOneWidget,
      reason: 'a parent has home groups, not classes — pointing them at '
          '/classroom-manage would show them somebody else\'s surface',
    );
    expect(find.text('Manage Classes'), findsNothing);
  });
}
