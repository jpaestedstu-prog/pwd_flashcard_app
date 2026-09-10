import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/routine/models/routine_models.dart';
import 'package:pwdpwdpwd/features/routine/services/routine_media_store.dart';

/// Media picked from the device.
///
/// The picker hands back a path in the OS cache, which Android may reclaim —
/// so the file is copied into app storage and the slot points at the copy.
/// These tests pin the parts that decide whether a learner still has a
/// picture next week: that the copy happens, that re-picking replaces rather
/// than accumulates, and that clearing a slot never deletes someone else's
/// hosted URL.

late Directory _root;

void main() {
  setUp(() async {
    _root = await Directory.systemTemp.createTemp('routine_media_test');
    RoutineMediaStore.debugDirectory = () async => _root;
  });

  tearDown(() async {
    RoutineMediaStore.debugDirectory = null;
    RoutineMediaStore.debugPick = null;
    if (await _root.exists()) await _root.delete(recursive: true);
  });

  Future<String> makeSource(String name, [String body = 'x']) async {
    final f = File('${_root.path}${Platform.pathSeparator}$name');
    await f.writeAsString(body);
    return f.path;
  }

  Directory storeDir() =>
      Directory('${_root.path}${Platform.pathSeparator}routine_media');

  group('slot values', () {
    test('a device file is recognised and its path recoverable', () {
      expect(RoutineMediaStore.isDeviceFile('file:///a/b.jpg'), isTrue);
      expect(RoutineMediaStore.pathOf('file:///a/b.jpg'), '/a/b.jpg');
    });

    test('a URL and an asset are not device files', () {
      expect(RoutineMediaStore.isDeviceFile('https://x/y.jpg'), isFalse);
      expect(RoutineMediaStore.isDeviceFile('assets/images/a.png'), isFalse);
      // pathOf leaves a non-file value alone rather than mangling it.
      expect(RoutineMediaStore.pathOf('https://x/y.jpg'), 'https://x/y.jpg');
    });
  });

  group('adopting a picked file', () {
    test('copies it into app storage and returns a file slot', () async {
      final src = await makeSource('picked.jpg', 'photo-bytes');
      final slot = await const RoutineMediaStore().adopt(
        sourcePath: src,
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      expect(slot, isNotNull);
      expect(RoutineMediaStore.isDeviceFile(slot!), isTrue);

      final copied = File(RoutineMediaStore.pathOf(slot));
      expect(await copied.exists(), isTrue);
      expect(await copied.readAsString(), 'photo-bytes');
      // The original is untouched — we copy, never move.
      expect(await File(src).exists(), isTrue);
    });

    test('names the copy after the step and slot', () async {
      final slot = await const RoutineMediaStore().adopt(
        sourcePath: await makeSource('a.png'),
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      expect(RoutineMediaStore.pathOf(slot!), contains('step1_photo.png'));
    });

    test('re-picking replaces the old copy instead of accumulating', () async {
      const store = RoutineMediaStore();
      final first = await store.adopt(
        sourcePath: await makeSource('one.jpg', 'first'),
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      // A different extension, so a naive "overwrite same name" would leave
      // the jpg behind forever.
      final second = await store.adopt(
        sourcePath: await makeSource('two.png', 'second'),
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      expect(first, isNot(second));
      expect(await File(RoutineMediaStore.pathOf(first!)).exists(), isFalse);
      expect(await File(RoutineMediaStore.pathOf(second!)).readAsString(),
          'second');

      final left = await storeDir().list().toList();
      expect(left, hasLength(1), reason: 'one slot should keep one file');
    });

    test('different slots on one step coexist', () async {
      const store = RoutineMediaStore();
      await store.adopt(
        sourcePath: await makeSource('p.jpg'),
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      await store.adopt(
        sourcePath: await makeSource('g.gif'),
        stepId: 'step1',
        kind: RoutineMediaKind.gif,
      );
      expect(await storeDir().list().toList(), hasLength(2));
    });

    test('a source that has gone away yields null, not a crash', () async {
      final slot = await const RoutineMediaStore().adopt(
        sourcePath: '${_root.path}${Platform.pathSeparator}missing.jpg',
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      expect(slot, isNull);
    });

    test('a path with no extension still lands on a playable one', () async {
      final slot = await const RoutineMediaStore().adopt(
        sourcePath: await makeSource('noext'),
        stepId: 'step1',
        kind: RoutineMediaKind.video,
      );
      expect(RoutineMediaStore.pathOf(slot!), endsWith('step1_video.mp4'));
    });
  });

  group('discarding', () {
    test('deletes our own copy', () async {
      final slot = await const RoutineMediaStore().adopt(
        sourcePath: await makeSource('a.jpg'),
        stepId: 'step1',
        kind: RoutineMediaKind.photo,
      );
      await const RoutineMediaStore().discard(slot!);
      expect(await File(RoutineMediaStore.pathOf(slot)).exists(), isFalse);
    });

    test('never touches a URL or an asset', () async {
      // Clearing a slot must not try to delete something the app does not own.
      await const RoutineMediaStore().discard('https://example.test/a.jpg');
      await const RoutineMediaStore().discard('assets/images/a.png');
      // Nothing thrown, nothing created.
      expect(await storeDir().exists(), isFalse);
    });

    test('a file already gone is not an error', () async {
      await const RoutineMediaStore()
          .discard('${RoutineMediaStore.filePrefix}/nope/gone.jpg');
    });
  });

  group('pick and adopt', () {
    test('returns null when the educator cancels', () async {
      RoutineMediaStore.debugPick = (_) async => null;
      final slot = await const RoutineMediaStore()
          .pickAndAdopt(stepId: 's', kind: RoutineMediaKind.photo);
      expect(slot, isNull);
    });

    test('copies what the picker returned', () async {
      final src = await makeSource('from_picker.jpg', 'bytes');
      RoutineMediaStore.debugPick = (_) async => src;
      final slot = await const RoutineMediaStore()
          .pickAndAdopt(stepId: 's', kind: RoutineMediaKind.photo);
      expect(slot, isNotNull);
      expect(await File(RoutineMediaStore.pathOf(slot!)).readAsString(),
          'bytes');
    });
  });

  group('offered file types', () {
    test('each slot offers types it can actually play', () {
      expect(RoutineMediaStore.extensionsFor(RoutineMediaKind.photo),
          contains('jpg'));
      expect(RoutineMediaStore.extensionsFor(RoutineMediaKind.gif),
          contains('gif'));
      expect(RoutineMediaStore.extensionsFor(RoutineMediaKind.video),
          contains('mp4'));
      expect(RoutineMediaStore.extensionsFor(RoutineMediaKind.audio),
          contains('mp3'));
      // A video in the photo slot would render as a broken image.
      expect(RoutineMediaStore.extensionsFor(RoutineMediaKind.photo),
          isNot(contains('mp4')));
      for (final k in RoutineMediaKind.values) {
        expect(RoutineMediaStore.extensionsFor(k), isNotEmpty);
      }
    });
  });
}
