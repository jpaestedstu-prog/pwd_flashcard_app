import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/child_alarm.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/child_alarm_provider.dart';

/// An alarm saved without a label read "Alarm" in English on the Filipino
/// list, and swiping it away asked `Delete “”?` — found on the tablet.
class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'teacher-1',
        name: 'RoutineTeacher',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );
}

final _unnamed = ChildAlarm(
  id: 'al-1',
  childProfileId: 'child-1',
  setterProfileId: 'teacher-1',
  setterRole: UserRole.teacher,
  label: '',
  hour: 13,
  minute: 20,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<void> _pump(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(_StubProfile.new),
        childAlarmListProvider('child-1')
            .overrideWith((ref) => Stream.value([_unnamed])),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ChildAlarmsScreen(childProfileId: 'child-1'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/child_alarms_unnamed');
    for (final name in const ['child_alarms', 'profiles', 'settings', 'error_logs']) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    await Hive.close();
  });

  for (final (locale, name, ask) in const [
    (Locale('en'), 'Alarm', 'Delete “Alarm”?'),
    (Locale('fil'), 'Alarma', 'Burahin ang “Alarma”?'),
  ]) {
    testWidgets('an unnamed alarm is "$name", and deleting it asks "$ask"',
        (tester) async {
      await _pump(tester, locale);
      expect(find.text(name), findsOneWidget);

      await tester.drag(find.text(name), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(ask), findsOneWidget);
      expect(find.text('Delete “”?'), findsNothing);
    });
  }
}
