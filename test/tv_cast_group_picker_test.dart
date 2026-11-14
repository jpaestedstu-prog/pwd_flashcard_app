import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/cast_group_selection.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/cast_group_provider.dart';
import 'package:pwdpwdpwd/features/tv_cast/widgets/tv_cast_group_picker.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

class _StubProfile extends ProfileNotifier {
  _StubProfile(this.role);

  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: 'picker-educator',
    name: 'Test Educator',
    role: role,
    createdAt: DateTime(2026),
  );
}

/// The real notifier with the Hive write taken out: a widget test must never
/// write to Hive from its fake-async zone (see the Star Shop note in
/// test/support). Records what would have been saved instead.
class _MemorySelection extends CastGroupSelectionNotifier {
  static final saved = <CastGroupSelection>[];

  @override
  CastGroupSelection build(String educatorProfileId) =>
      const CastGroupSelection.all();

  @override
  Future<void> persist(CastGroupSelection selection) async =>
      saved.add(selection);
}

const _classes = [
  CastGroupOption(
    id: 'c-cognitive',
    name: 'Cognitive / Learning Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.cognitive,
  ),
  CastGroupOption(
    id: 'c-hearing',
    name: 'Hearing Impairment Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.hearing,
  ),
  CastGroupOption(
    id: 'c-multiple',
    name: 'Multiple Disabilities Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.multiple,
  ),
  CastGroupOption(
    id: 'c-visual',
    name: 'Visual Impairment Class',
    kind: LiveSessionOwnerKind.classroom,
    accessibility: DisabilityType.visual,
  ),
];

/// The "Class / group" picker on the TV Cast screen, with a Teacher's four
/// classes: what it says, what a tap does, and that it fits from a 320 dp
/// phone at 2× text to a tablet.
void main() {
  Future<ProviderContainer> pumpPicker(
    WidgetTester tester, {
    Size size = const Size(686, 1097),
    double dpr = 1.75,
    double textScale = 1.0,
    String locale = 'en',
    UserRole role = UserRole.teacher,
    List<CastGroupOption> options = _classes,
  }) async {
    tester.view.physicalSize = size * dpr;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(() => _StubProfile(role)),
      castGroupOptionsProvider.overrideWith((ref, id) => options),
      castGroupMemberCountProvider.overrideWith(
        (ref, option) => option.id == 'c-hearing' ? 1 : 3,
      ),
      castGroupSelectionProvider.overrideWith(_MemorySelection.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: TvCastGroupPicker(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  CastGroupSelection selection(ProviderContainer c) =>
      c.read(castGroupSelectionProvider('picker-educator'));

  setUp(_MemorySelection.saved.clear);

  testWidgets('starts on "All classes" and opens to every class with its '
      'audience and learner count', (tester) async {
    await pumpPicker(tester);
    expect(find.text('All classes'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);

    await tester.tap(find.text('Change'));
    await tester.pump();
    for (final o in _classes) {
      expect(find.text(o.name), findsOneWidget);
    }
    expect(find.text('Hearing Impairment · 1 learner'), findsOneWidget);
    expect(find.text('Multiple Disabilities · 3 learners'), findsOneWidget);
    expect(find.text('Cognitive/Learning · 3 learners'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('one tap narrows to a class, more taps add, and picking all '
      'of them folds back into "All"', (tester) async {
    final c = await pumpPicker(tester);
    await tester.tap(find.text('Change'));
    await tester.pump();

    await tester.tap(find.text('Hearing Impairment Class'));
    await tester.pump();
    expect(selection(c).resolve(_classes).map((o) => o.id), ['c-hearing']);
    // The summary now names the class; the open list stays open.
    expect(find.text('Hearing Impairment Class'), findsNWidgets(2));

    await tester.tap(find.text('Multiple Disabilities Class').last);
    await tester.pump();
    expect(
      selection(c).resolve(_classes).map((o) => o.id),
      ['c-hearing', 'c-multiple'],
    );
    expect(
      find.text('Hearing Impairment Class · Multiple Disabilities Class'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cognitive / Learning Class').last);
    await tester.pump();
    await tester.tap(find.text('Visual Impairment Class').last);
    await tester.pump();
    expect(selection(c), const CastGroupSelection.all());

    // And each change was saved for next time.
    expect(_MemorySelection.saved.last, const CastGroupSelection.all());
    expect(_MemorySelection.saved, hasLength(4));
  });

  testWidgets('"All classes" undoes a narrowed choice in one tap',
      (tester) async {
    final c = await pumpPicker(tester);
    await tester.tap(find.text('Change'));
    await tester.pump();
    await tester.tap(find.text('Visual Impairment Class'));
    await tester.pump();
    expect(selection(c).all, isFalse);
    await tester.tap(find.text('All classes').last);
    await tester.pump();
    expect(selection(c), const CastGroupSelection.all());
  });

  testWidgets('a screen reader hears each class as a checked / unchecked '
      'choice', (tester) async {
    final handle = tester.ensureSemantics();
    final c = await pumpPicker(tester);
    await tester.tap(find.text('Change'));
    await tester.pump();
    await tester.tap(find.text('Hearing Impairment Class'));
    await tester.pump();
    expect(selection(c).includes('c-hearing'), isTrue);

    final hearing = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Hearing Impairment Class, ')),
    );
    expect(hearing.flagsCollection.isChecked, CheckedState.isTrue);
    final visual = tester.getSemantics(
      find.bySemanticsLabel(RegExp(r'^Visual Impairment Class, ')),
    );
    expect(visual.flagsCollection.isChecked, CheckedState.isFalse);
    handle.dispose();
  });

  testWidgets('one class has nothing to choose: it is simply named',
      (tester) async {
    await pumpPicker(tester, options: [_classes[1]]);
    expect(find.text('Hearing Impairment Class'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('a Parent with no home group is told where to make one',
      (tester) async {
    await pumpPicker(tester, role: UserRole.parent, options: const []);
    expect(find.textContaining('Manage Family'), findsOneWidget);
  });

  testWidgets('Filipino: the combined choice and the counts read naturally',
      (tester) async {
    await pumpPicker(tester, locale: 'fil');
    expect(find.text('Lahat ng klase'), findsOneWidget);
    await tester.tap(find.text('Palitan'));
    await tester.pump();
    // Filipino's plural rules count 2, 3, 5, 7… as "one": a fixed "1" text
    // there showed "1 mag-aaral" under a class of three.
    expect(find.textContaining('· 1 mag-aaral'), findsOneWidget);
    expect(find.textContaining('· 3 mag-aaral'), findsNWidgets(3));
  });

  testWidgets('the open list fits a 320 dp phone at 2× text, a phone, and the '
      'tablet', (tester) async {
    for (final (size, dpr, scale) in const [
      (Size(320, 568), 2.0, 2.0),
      (Size(360, 640), 3.0, 1.5),
      (Size(686, 1097), 1.75, 2.0),
      (Size(960, 600), 2.0, 1.0),
    ]) {
      // A fresh picker each time (a closed list), not the last one reused.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpPicker(tester, size: size, dpr: dpr, textScale: scale);
      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'layout failed at $size × $scale',
      );
      expect(find.text('Visual Impairment Class'), findsOneWidget);
    }
  });
}
