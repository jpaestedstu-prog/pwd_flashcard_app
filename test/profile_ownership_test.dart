import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/profile_ownership.dart';
import 'package:pwdpwdpwd/features/routine/widgets/routine_ownership_banner.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/routine_test_doubles.dart';

/// Who owns a profile in the cloud, and whether this device is told.
///
/// The bug behind this: restoring a profile onto a second device moves
/// `profiles/{id}.owner_uid` there, and the device left behind keeps saving to
/// Hive while every cloud write is refused. On the project tablet that went
/// unnoticed for six weeks — the recovery record shows the transfer happened
/// on 2026-08-22 and nothing on screen ever mentioned it.

const _me = 'this-device-uid';

ProfileOwnershipService _service(String? remoteOwner, {String? uid = _me}) {
  return ProfileOwnershipService(
    remoteOwnerUid: (_) async => remoteOwner,
    currentUid: () => uid,
  );
}

void main() {
  group('ownership check', () {
    test('the same uid owns it', () async {
      expect(await _service(_me).check('p'), ProfileCloudOwnership.owned);
    });

    test('a different uid means writes are refused', () async {
      expect(
        await _service('someone-else').check('p'),
        ProfileCloudOwnership.elsewhere,
      );
    });

    test('an unclaimed profile is writable, not stolen', () async {
      // A null owner_uid is a legacy row the rules let this device claim, so
      // it must not be reported as belonging to someone else.
      expect(await _service(null).check('p'), ProfileCloudOwnership.owned);
      expect(await _service('').check('p'), ProfileCloudOwnership.owned);
    });

    test('no signed-in uid is unknown, never elsewhere', () async {
      expect(
        await _service('someone-else', uid: null).check('p'),
        ProfileCloudOwnership.unknown,
      );
    });

    test('an empty profile id is unknown', () async {
      expect(await _service(_me).check(''), ProfileCloudOwnership.unknown);
    });

    test('a failed read is unknown, never elsewhere', () async {
      // Guessing "elsewhere" from a network blip would tell an educator to go
      // and find another tablet that does not exist.
      final svc = ProfileOwnershipService(
        remoteOwnerUid: (_) async => throw Exception('offline'),
        currentUid: () => _me,
      );
      expect(await svc.check('p'), ProfileCloudOwnership.unknown);
    });

    test('only "elsewhere" blocks cloud writes', () {
      expect(ProfileCloudOwnership.owned.blocksCloudWrites, isFalse);
      expect(ProfileCloudOwnership.unknown.blocksCloudWrites, isFalse);
      expect(ProfileCloudOwnership.elsewhere.blocksCloudWrites, isTrue);
    });
  });

  group('the banner', () {
    Future<void> pump(
      WidgetTester tester,
      ProfileCloudOwnership ownership, {
      bool filipino = false,
    }) async {
      tester.view.physicalSize = const Size(900, 1200) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...routineOverrides(),
          profileCloudOwnershipProvider(kTestProfileId)
              .overrideWith((ref) async => ownership),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: Locale(filipino ? 'fil' : 'en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: RoutineOwnershipBanner(
                educatorProfileId: kTestProfileId,
                filipino: filipino,
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('says nothing when this device owns the profile',
        (tester) async {
      await pump(tester, ProfileCloudOwnership.owned);
      expect(find.textContaining("won't reach"), findsNothing);
    });

    testWidgets('says nothing when ownership is unknown', (tester) async {
      // Silence beats a false accusation when the read simply failed.
      await pump(tester, ProfileCloudOwnership.unknown);
      expect(find.textContaining("won't reach"), findsNothing);
    });

    testWidgets('warns, and gives the way back, when it is owned elsewhere',
        (tester) async {
      await pump(tester, ProfileCloudOwnership.elsewhere);
      expect(find.textContaining("Changes here won't reach"), findsOneWidget);
      expect(
        find.textContaining('restored onto another device'),
        findsOneWidget,
      );
      // The concrete route back has to be present — this is the difference
      // between a warning and a dead end.
      expect(find.textContaining('generate a new recovery code'),
          findsOneWidget);
      // It must not claim the work is lost: local editing still works.
      expect(find.textContaining('still edit here'), findsOneWidget);
    });

    testWidgets('names the profile so the educator knows which one',
        (tester) async {
      await pump(tester, ProfileCloudOwnership.elsewhere);
      expect(find.textContaining('Routine Tester'), findsOneWidget);
    });

    testWidgets('Filipino gets its own copy', (tester) async {
      await pump(tester, ProfileCloudOwnership.elsewhere, filipino: true);
      expect(
        find.textContaining('Hindi makakarating sa bata'),
        findsOneWidget,
      );
      expect(find.textContaining("Changes here won't"), findsNothing);
    });
  });
}
