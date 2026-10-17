import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/core/services/web_media.dart';
import 'package:pwdpwdpwd/core/utils/platform_caps.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/enhanced_create_flashcard_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_practice_screen.dart';
import 'package:pwdpwdpwd/features/gamepad/screens/gamepad_settings_screen.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/widgets/message_media_view.dart';
import 'package:pwdpwdpwd/features/settings/screens/backup_restore_screen.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/features/tv_cast/screens/tv_cast_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/widgets/android_app_notice.dart';

import 'support/all_screens.dart';

/// The browser version cannot do everything the Android app does: it has no
/// files, alarms, local server, camera takes or controller bridge. Each
/// feature built on those says so where it is offered, instead of a button
/// that fails or seems to work and does nothing.
///
/// Firestore's shared-media pieces, in memory.
class _MemoryBackend implements SharedMediaBackend {
  final Map<String, SharedMediaMeta> metas = {};
  final Map<String, Uint8List> chunks = {};
  int reads = 0;

  void put(String id, Uint8List bytes, String ext) {
    metas[id] = SharedMediaMeta(
      id: id,
      ownerProfileId: 'kid',
      ext: ext,
      size: bytes.length,
      chunkCount: 1,
      sha256: sha256.convert(bytes).toString(),
      ready: true,
    );
    chunks['$id/0'] = bytes;
  }

  @override
  Future<void> writeMeta(SharedMediaMeta meta) async => metas[meta.id] = meta;
  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async =>
      chunks['$id/$index'] = bytes;
  @override
  Future<SharedMediaMeta?> readMeta(String id) async {
    reads++;
    return metas[id];
  }

  @override
  Future<Uint8List?> readChunk(String id, int index) async {
    reads++;
    return chunks['$id/$index'];
  }

  @override
  Future<void> deleteChunk(String id, int index) async =>
      chunks.remove('$id/$index');
  @override
  Future<void> deleteMeta(String id) async => metas.remove(id);
  @override
  Future<List<String>> idsOwnedBy(String ownerProfileId) async => [
    for (final m in metas.values)
      if (m.ownerProfileId == ownerProfileId) m.id,
  ];
}

/// [PlatformCaps.debugWeb] shows the browser version's screens here.
void main() {
  final t = AppLocalizationsEn();

  setUpAll(() => openSweepBoxes('browser_limits'));
  tearDownAll(closeSweepBoxes);
  tearDown(() => PlatformCaps.debugWeb = null);

  Future<void> pump(WidgetTester tester, Widget child, UserRole role) async {
    tester.view.physicalSize = const Size(400, 900) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sweepProfileOverride(role)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls the page's main list until [finder] is built, or to its end.
  Future<bool> scrollTo(WidgetTester tester, Finder finder) async {
    final lists = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    if (finder.evaluate().isNotEmpty) return true;
    if (lists.evaluate().isEmpty) return false;
    final position = tester.state<ScrollableState>(lists.first).position;
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      if (position.extentAfter <= 0) break;
      position.jumpTo(
        (position.pixels + 300).clamp(0.0, position.maxScrollExtent),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return finder.evaluate().isNotEmpty;
  }

  Future<void> unmount(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final screens = <String, (Widget Function(), UserRole, String)>{
    'TV Cast': (() => const TvCastScreen(), UserRole.teacher,
        t.webTvCastNeedsApp),
    'Backup & Restore': (() => const BackupRestoreScreen(), UserRole.student,
        t.webBackupNeedsApp),
    'Settings > Reminders': (() => const SettingsScreen(), UserRole.student,
        t.webRemindersNeedApp),
    'Game Controller': (() => const GamepadSettingsScreen(),
        UserRole.student, t.webControllerNeedsApp),
    'Controller practice': (() => const GamepadPracticeScreen(),
        UserRole.student, t.webControllerNeedsApp),
    'Create a card (picture)': (() => const EnhancedCreateFlashcardScreen(),
        UserRole.student, t.webMediaNeedsApp),
  };

  for (final MapEntry(key: name, value: (build, role, message))
      in screens.entries) {
    testWidgets('$name: the browser version says it needs the Android app',
        (tester) async {
      PlatformCaps.debugWeb = true;
      await pump(tester, build(), role);
      expect(await scrollTo(tester, find.text(message)), isTrue,
          reason: 'the notice is on the screen');
      expect(find.text(t.webGetAndroidApp), findsWidgets,
          reason: 'with the way to get the app');
      await unmount(tester);
    });

    testWidgets('$name: the Android app shows no such notice', (tester) async {
      PlatformCaps.debugWeb = false;
      await pump(tester, build(), role);
      expect(await scrollTo(tester, find.byType(AndroidAppNotice)), isFalse);
      await unmount(tester);
    });
  }

  testWidgets('Backup & Restore in a browser offers the Recovery Code, not '
      'backup files', (tester) async {
    PlatformCaps.debugWeb = true;
    await pump(tester, const BackupRestoreScreen(), UserRole.student);
    expect(find.text(t.brBackUpNow), findsNothing);
    expect(find.text(t.brRestore), findsNothing);
    expect(await scrollTo(tester, find.text(t.settingRecoveryCodeTitle)),
        isTrue);
    await unmount(tester);
  });

  testWidgets('Settings in a browser has no screen-orientation choice (a '
      'browser turns the page itself) and no reminder switches',
      (tester) async {
    PlatformCaps.debugWeb = true;
    await pump(tester, const SettingsScreen(), UserRole.student);
    expect(await scrollTo(tester, find.text(t.webRemindersNeedApp)), isTrue);
    expect(find.text(t.screenOrientation), findsNothing);
    expect(find.text(t.dailyReminder), findsNothing);
    await unmount(tester);

    PlatformCaps.debugWeb = false;
    await pump(tester, const SettingsScreen(), UserRole.student);
    expect(await scrollTo(tester, find.text(t.screenOrientation)), isTrue,
        reason: 'the app keeps it');
    await unmount(tester);
  });

  testWidgets('a photo sent in a message is shown in a browser too (from '
      'its bytes, held in memory), not "try again" forever', (tester) async {
    PlatformCaps.debugWeb = true;
    final backend = _MemoryBackend()
      ..put('m1', Uint8List.fromList(List.filled(64, 7)), 'jpg');
    SharedMediaService.debugBackend = backend;
    WebMedia.debugObjectUrl = (bytes, mime) => 'blob:test/${bytes.length}/$mime';
    addTearDown(() {
      SharedMediaService.debugBackend = null;
      WebMedia.debugObjectUrl = null;
      WebMedia.debugReset();
      SharedMediaService.debugClearMemory();
    });
    await pump(
      tester,
      Scaffold(
        body: MessageMediaBody(
          message: LocalMessage(
            id: 'm1',
            senderId: 'kid',
            senderName: 'kid',
            recipientId: 'other',
            content: 'shared://m1',
            type: MessageType.photo,
            timestamp: DateTime.now(),
          ),
          isFilipino: false,
        ),
      ),
      UserRole.student,
    );
    expect(find.bySemanticsLabel('Look at the photo'), findsOneWidget);
    expect(find.text("Can't load it yet. Tap to try again."), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'blob:test/64/image/jpeg');
    await unmount(tester);
  });

  group('WebMedia (the browser version\'s media addresses)', () {
    setUp(() {
      WebMedia.debugObjectUrl = (bytes, mime) => 'blob:test/${bytes.length}/$mime';
    });
    tearDown(() {
      SharedMediaService.debugBackend = null;
      WebMedia.debugObjectUrl = null;
      WebMedia.debugReset();
      SharedMediaService.debugClearMemory();
    });

    test('a link plays from its own address; a Cloudinary GIF as its MP4 '
        'when a video player plays it', () async {
      expect(await WebMedia.urlFor('https://example.org/a.mp4'),
          'https://example.org/a.mp4');
      const gif = 'https://res.cloudinary.com/x/image/upload/v1/sign.gif';
      expect(await WebMedia.urlFor(gif), gif);
      expect(await WebMedia.urlFor(gif, video: true),
          'https://res.cloudinary.com/x/image/upload/v1/sign.mp4');
    });

    test('a shared file plays from its bytes, fetched once', () async {
      final backend = _MemoryBackend()
        ..put('v1', Uint8List.fromList(List.filled(100, 1)), 'mp4');
      SharedMediaService.debugBackend = backend;
      expect(await WebMedia.urlFor('shared://v1', video: true),
          'blob:test/100/video/mp4');
      final readsAfterFirst = backend.reads;
      expect(await WebMedia.urlFor('shared://v1'), 'blob:test/100/video/mp4');
      expect(backend.reads, readsAfterFirst,
          reason: 'shown twice, fetched once (Firestore reads)');
    });

    test('nothing for a file on another device, a missing or damaged one',
        () async {
      final backend = _MemoryBackend();
      SharedMediaService.debugBackend = backend;
      expect(await WebMedia.urlFor('file:///data/x.mp4'), isNull);
      expect(await WebMedia.urlFor('shared://missing'), isNull);
      backend.put('bad', Uint8List.fromList([1, 2, 3]), 'png');
      backend.chunks['bad/0'] = Uint8List.fromList([9, 9, 9]); // not its hash
      expect(await WebMedia.urlFor('shared://bad'), isNull);
    });

    test('memory keeps to its budget, dropping the least recently shown',
        () async {
      final backend = _MemoryBackend();
      SharedMediaService.debugBackend = backend;
      const big = SharedMediaService.memoryBudget ~/ 2 + 1;
      backend.put('a', Uint8List(big), 'mp4');
      backend.put('b', Uint8List(big), 'mp4');
      const service = SharedMediaService();
      expect(await service.resolveBytes('shared://a'), isNotNull);
      expect(await service.resolveBytes('shared://b'), isNotNull);
      final before = backend.reads;
      await service.resolveBytes('shared://a'); // dropped for b: fetched again
      expect(backend.reads, greaterThan(before));
    });

    test('the addresses keep to a budget too (each holds a copy), letting '
        'the least recently shown go; one asked for twice at once is made '
        'once', () async {
      final backend = _MemoryBackend();
      SharedMediaService.debugBackend = backend;
      final saved = WebMedia.byteBudget;
      WebMedia.byteBudget = 250;
      addTearDown(() => WebMedia.byteBudget = saved);
      var made = 0;
      WebMedia.debugObjectUrl = (bytes, mime) => 'blob:test/${made++}';
      for (final id in ['a', 'b', 'c']) {
        backend.put(id, Uint8List(100), 'jpg');
      }
      final both = await Future.wait(
          [WebMedia.urlFor('shared://a'), WebMedia.urlFor('shared://a')]);
      expect(both, ['blob:test/0', 'blob:test/0']);
      await WebMedia.urlFor('shared://b');
      await WebMedia.urlFor('shared://a'); // shown again: now the newest
      await WebMedia.urlFor('shared://c'); // 300 > 250: b goes
      expect(WebMedia.debugHeld, ['shared://a', 'shared://c']);
      expect(made, 3);
    });
  });
}
