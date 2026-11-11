import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/home/screens/educator_home_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/student_list_provider.dart';

import 'support/all_screens.dart';

class _Teacher extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'teacher-1',
        name: 'Teacher',
        role: UserRole.teacher,
        createdAt: DateTime(2026),
      );
}

/// On the tablet (4 Nov) "Recent Students" was the first five of the roster in
/// the roster's own order: 4 weeks ago, 3 weeks ago, 4 weeks ago, then the two
/// active within the hour, and anyone active today who was sixth was not there.
void main() {
  setUpAll(() => openMemoryBoxes('recent_students'));

  testWidgets('Recent Students: the five most recently active, latest first',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    (UserProfile, LearningProgress) student(int i, Duration ago) => (
          UserProfile(
            id: 's$i',
            name: 'Student $i',
            role: UserRole.student,
            createdAt: DateTime(2026),
          ),
          LearningProgress(profileId: 's$i', lastActivityDate: now.subtract(ago)),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Teacher.new),
          educatorLearnerRosterProvider.overrideWithValue([
            student(0, const Duration(days: 30)),
            student(1, const Duration(days: 20)),
            student(2, const Duration(days: 28)),
            student(3, const Duration(minutes: 50)),
            student(4, const Duration(days: 40)),
            student(5, const Duration(minutes: 5)),
            student(6, const Duration(days: 2)),
          ]),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EducatorHomeScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final latest = find.textContaining('Student 5');
    await tester.dragUntilVisible(
      latest,
      find.byType(CustomScrollView),
      const Offset(0, -320),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Far enough for all five.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 300));

    double y(int i) => tester.getTopLeft(find.textContaining('Student $i')).dy;
    expect(y(5), lessThan(y(3)));
    expect(y(3), lessThan(y(6)));
    expect(y(6), lessThan(y(1)));
    expect(y(1), lessThan(y(2)));
    expect(find.textContaining('Student 0'), findsNothing);
    expect(find.textContaining('Student 4'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
