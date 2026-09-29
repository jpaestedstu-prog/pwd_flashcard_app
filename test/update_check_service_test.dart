import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/update_check_service.dart';

/// The update check: the website's `version.json` against the installed
/// build, at most once a day, and never an error on a learner's tablet.

String _json({String version = '1.3.0', int build = 5, String? page}) =>
    jsonEncode({
      'latest': {
        'version': version,
        'build': build,
        'date': '2026-10-15',
        'page': page ??
            'https://jpaestedstu-prog.github.io/pwd_flashcard_app/#download',
        'notes_en': 'New things',
        'notes_fil': 'Mga bago',
      },
    });

class _MemoryStore implements UpdateCheckStore {
  _MemoryStore({this.payload, this.checkedAt});
  @override
  String? payload;
  @override
  DateTime? checkedAt;
  int saves = 0;
  @override
  Future<void> save(String payload, DateTime at) async {
    this.payload = payload;
    checkedAt = at;
    saves++;
  }
}

void main() {
  final now = DateTime(2026, 10, 16, 9);
  Future<({String version, int build})> installed12() async =>
      (version: '1.2.0', build: 4);

  UpdateCheckService service({
    required _MemoryStore store,
    String? Function()? fetch,
    List<Uri>? fetched,
  }) =>
      UpdateCheckService(
        installed: installed12,
        store: store,
        now: () => now,
        fetch: (url) async {
          fetched?.add(url);
          return fetch?.call();
        },
      );

  group('AppRelease.tryParse', () {
    test('reads the fields the website writes', () {
      final r = AppRelease.tryParse(_json())!;
      expect(r.version, '1.3.0');
      expect(r.build, 5);
      expect(r.pageUrl, endsWith('#download'));
      expect(r.notesFil, 'Mga bago');
    });

    test('a broken or foreign file is null, never a throw', () {
      expect(AppRelease.tryParse('<html>404</html>'), isNull);
      expect(AppRelease.tryParse('{"latest": {"version": 3}}'), isNull);
      expect(AppRelease.tryParse('[]'), isNull);
    });

    test('only an https page is ever opened', () {
      expect(AppRelease.tryParse(_json(page: 'http://example.com')), isNull);
      expect(AppRelease.tryParse(_json(page: 'intent://x')), isNull);
    });
  });

  test('a newer build on the website is an update', () async {
    final status = await service(store: _MemoryStore(), fetch: _json).check();
    expect(status, isA<UpdateAvailable>());
    expect((status as UpdateAvailable).release.version, '1.3.0');
    expect(status.installedVersion, '1.2.0');
  });

  test('the same or an older build is up to date', () async {
    final same = await service(
      store: _MemoryStore(),
      fetch: () => _json(version: '1.2.0', build: 4),
    ).check();
    expect(same, isA<UpToDate>());
  });

  test('asks the website at most once a day', () async {
    final fetched = <Uri>[];
    final store = _MemoryStore(
      payload: _json(),
      checkedAt: now.subtract(const Duration(hours: 3)),
    );
    final status =
        await service(store: store, fetch: _json, fetched: fetched).check();
    expect(fetched, isEmpty, reason: 'three hours old is still fresh');
    expect(status, isA<UpdateAvailable>());
  });

  test('a day-old answer is refreshed, and the new one kept', () async {
    final fetched = <Uri>[];
    final store = _MemoryStore(
      payload: _json(version: '1.2.0', build: 4),
      checkedAt: now.subtract(const Duration(hours: 25)),
    );
    final status =
        await service(store: store, fetch: _json, fetched: fetched).check();
    expect(fetched, [UpdateCheckService.versionUrl]);
    expect(status, isA<UpdateAvailable>());
    expect(store.checkedAt, now);
  });

  test('"Check for updates" asks even when the answer is fresh', () async {
    final fetched = <Uri>[];
    final store = _MemoryStore(payload: _json(), checkedAt: now);
    await service(store: store, fetch: _json, fetched: fetched)
        .check(force: true);
    expect(fetched, hasLength(1));
  });

  test('offline falls back to the last good answer', () async {
    final store = _MemoryStore(
      payload: _json(),
      checkedAt: now.subtract(const Duration(days: 3)),
    );
    final status = await service(store: store, fetch: () => null).check();
    expect(status, isA<UpdateAvailable>());
    expect(store.saves, 0, reason: 'nothing new to keep');
  });

  test('offline with nothing kept is unknown, not an error', () async {
    final status =
        await service(store: _MemoryStore(), fetch: () => null).check();
    expect(status, isA<UpdateUnknown>());
  });

  test('a bad file is not stored over a good one', () async {
    final store = _MemoryStore(
      payload: _json(),
      checkedAt: now.subtract(const Duration(days: 2)),
    );
    final status =
        await service(store: store, fetch: () => 'not json').check();
    expect(status, isA<UpdateAvailable>());
    expect(store.saves, 0);
  });

  test('split-per-ABI version codes compare by their build number', () {
    // The 64-bit APK of build 5 reports 2005; raw, it always looked newer
    // than the website's 5 and never heard of an update.
    expect(UpdateCheckService.baseBuild(2005), 5);
    expect(UpdateCheckService.baseBuild(1005), 5);
    expect(UpdateCheckService.baseBuild(4005), 5);
    expect(UpdateCheckService.baseBuild(5), 5);
  });

  test('an unreadable installed version is unknown', () async {
    final status = await UpdateCheckService(
      installed: () async => throw StateError('no platform'),
      store: _MemoryStore(),
      fetch: (_) async => _json(),
    ).check();
    expect(status, isA<UpdateUnknown>());
  });
}
