import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_clip_quality.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/models/settings_presentation.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// The Settings screen as each kind of profile actually sees it, top to
/// bottom — the screen half of `settings_presentation_test.dart`.
///
/// What started this: Gaze Control and the game controller sat in a
/// Teacher's and a Parent's own Settings, "Classroom Mode — Monitor all
/// students" sat in a Student's, and a Parent had the Teacher's live class
/// view. Each row below is looked for on the whole list, so a row that moves
/// section still passes and a row that leaks to the wrong profile fails.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._kind, [this._type = DisabilityType.none]);
  final ProfileKind _kind;
  final DisabilityType _type;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-${_kind.name}-${_type.name}',
        name: 'Test ${_kind.name}',
        role: switch (_kind) {
          ProfileKind.guestPlayer || ProfileKind.player => UserRole.player,
          ProfileKind.student => UserRole.student,
          ProfileKind.child => UserRole.child,
          ProfileKind.teacher => UserRole.teacher,
          ProfileKind.parent => UserRole.parent,
        },
        isGuestPlayer: _kind == ProfileKind.guestPlayer,
        disabilityType: _type,
        createdAt: DateTime(2026),
      );
}

/// Keeps the Sign videos choice in memory: no Hive write from a widget test.
class _MemoryChoice extends FslQualityChoiceNotifier {
  @override
  FslQualityChoice build() => FslQualityChoice.auto;

  @override
  Future<void> set(FslQualityChoice choice) async => state = choice;
}

/// Every text the whole list shows, scrolled top to bottom.
Future<Set<String>> _wholeList(
  WidgetTester tester,
  ProfileKind kind, [
  DisabilityType type = DisabilityType.none,
]) async {
  tester.view.physicalSize = const Size(800, 1280) * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(overrides: [
    profileProvider.overrideWith(() => _StubProfileNotifier(kind, type)),
    fslQualityChoiceProvider.overrideWith(_MemoryChoice.new),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final seen = <String>{};
  void collect() {
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      final text = widget.data ?? widget.textSpan?.toPlainText();
      if (text != null) seen.add(text);
    }
  }

  // jumpTo, not drag: a drag starts mid-list and an inner scrollable there
  // would take it.
  final position =
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  collect();
  for (var i = 0; i < 200 && position.extentAfter > 0; i++) {
    position.jumpTo(position.pixels + 300);
    await tester.pump(const Duration(milliseconds: 300));
    collect();
  }
  await tester.pumpAndSettle();
  collect();
  expect(position.extentAfter, 0, reason: 'reached the end');
  await tester.pumpWidget(const SizedBox.shrink());
  return seen;
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/settings_rows_by_profile');
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
    // The Settings screen's Cloud Sync tile reads the sync-queue box.
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  // Row title → which kinds see it, in ProfileKind order:
  //                                     guest  player student child  teacher parent
  const rows = <String, List<bool>>{
    // Everyone's display accessibility.
    'High Contrast Mode': [true, true, true, true, true, true],
    'Font Size': [true, true, true, true, true, true],
    'Reduced Motion': [true, true, true, true, true, true],
    'Voice-Guided Navigation': [true, true, true, true, true, true],
    // A learner's own hands-free input…
    'Gaze Control (Preview)': [true, true, true, true, false, false],
    'Game Controller': [true, true, true, true, false, false],
    // A guest or a Player sets themselves up; a Student's or a Child's
    // needs are set by their Teacher or Parent, and the row says who.
    'Re-run Accessibility Setup': [true, true, false, false, false, false],
    'Accessibility needs: No Accessibility Needs': [
      false, false, true, true, false, false, //
    ],
    'Your teacher sets these for you': [false, false, true, false, false, false],
    'Your parent sets these for you': [false, false, false, true, false, false],
    // …which an educator sets up for each learner instead.
    'Learners’ Gaze Control & controller': [
      false, false, false, false, true, true, //
    ],
    'Adaptive Difficulty': [true, true, true, true, false, false],
    'Slow-Motion Mode': [true, true, true, true, false, false],
    'Text-to-Speech': [true, true, true, true, false, false],
    'AI Companion': [true, true, true, true, false, false],
    'Daily Reminder': [true, true, true, true, false, false],
    'Replay Tutorials': [true, true, true, true, false, false],
    'Routine': [false, true, false, false, false, false],
    'Fullscreen': [false, false, false, false, true, true],
    'Classroom Mode': [false, false, false, false, true, false],
    'Parental Controls': [false, false, false, false, true, true],
    'Manage Profiles': [false, false, false, false, true, true],
    'Backup & Link Account': [false, false, false, false, true, true],
    'Backup & Restore': [false, true, false, false, true, true],
    'Cloud Recovery Code': [false, true, true, true, true, true],
    'Delete this profile': [false, true, true, true, true, true],
    'Reset All Data': [false, false, false, false, true, true],
    // Everyone.
    'Sign videos': [true, true, true, true, true, true],
    'Privacy & data': [true, true, true, true, true, true],
  };

  for (final kind in ProfileKind.values) {
    testWidgets('${kind.name} sees exactly its own rows', (tester) async {
      final seen = await _wholeList(tester, kind);
      for (final row in rows.entries) {
        expect(seen.contains(row.key), row.value[kind.index],
            reason: '${kind.name}: "${row.key}" should '
                '${row.value[kind.index] ? '' : 'not '}be shown');
      }
      // The educator's own tools sit together under one heading.
      final educator =
          kind == ProfileKind.teacher || kind == ProfileKind.parent;
      expect(seen.contains('MANAGE'), educator, reason: kind.name);
    });
  }

  // Sign videos are shown to whoever is shown signs. A learner whose needs
  // leave them out never watches one, so the download choice is noise there.
  for (final entry in {
    DisabilityType.visual: false,
    DisabilityType.cognitive: false,
    DisabilityType.hearing: true,
    DisabilityType.motor: true,
    DisabilityType.multiple: true,
  }.entries) {
    testWidgets(
        'a ${entry.key.name} Student '
        '${entry.value ? 'chooses' : 'is not asked about'} sign videos',
        (tester) async {
      final seen = await _wholeList(tester, ProfileKind.student, entry.key);
      expect(seen.contains('Sign videos'), entry.value);
      // Hands-free input stays a learner's, whatever their needs.
      expect(seen.contains('Gaze Control (Preview)'), isTrue);
      expect(seen.contains('Game Controller'), isTrue);
      // Their needs are named — and set by their teacher, not re-run here.
      expect(seen.contains('Accessibility needs: ${entry.key.label}'), isTrue);
      expect(seen.contains('Re-run Accessibility Setup'), isFalse);
    });
  }
}
