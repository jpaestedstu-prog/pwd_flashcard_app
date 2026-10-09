import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/distribution.dart';
import 'package:pwdpwdpwd/core/services/update_check_service.dart';

/// Store copies must never point people at the website for a newer version:
/// Google Play and the App Store both forbid an app that updates itself from
/// anywhere but the store. Website APKs keep their update check.

class _MemoryStore implements UpdateCheckStore {
  @override
  String? payload;
  @override
  DateTime? checkedAt;
  @override
  Future<void> save(String payload, DateTime at) async {
    this.payload = payload;
    checkedAt = at;
  }
}

const _newerRelease = '{"latest": {"version": "9.9.9", "build": 999, '
    '"page": "https://example.org/download.html"}}';

ProviderContainer _container(void Function() onFetch) {
  final container = ProviderContainer(overrides: [
    updateCheckServiceProvider.overrideWithValue(
      UpdateCheckService(
        installed: () async => (version: '1.0.0', build: 1),
        fetch: (_) async {
          onFetch();
          return _newerRelease;
        },
        store: _MemoryStore(),
      ),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('every iOS build is an App Store copy, whatever the define says', () {
    for (final define in ['website', 'play', '']) {
      expect(
        Distribution.resolve(platform: TargetPlatform.iOS, define: define),
        Distribution.appStore,
      );
    }
  });

  test('Android is a website APK unless built for Play', () {
    expect(
      Distribution.resolve(platform: TargetPlatform.android, define: 'website'),
      Distribution.website,
    );
    expect(
      Distribution.resolve(platform: TargetPlatform.android, define: ''),
      Distribution.website,
    );
    expect(
      Distribution.resolve(platform: TargetPlatform.android, define: 'play'),
      Distribution.play,
    );
  });

  test('only a website APK checks the website for updates', () {
    expect(Distribution.website.checksWebsiteForUpdates, isTrue);
    expect(Distribution.play.checksWebsiteForUpdates, isFalse);
    expect(Distribution.appStore.checksWebsiteForUpdates, isFalse);
  });

  test('an iOS copy never asks the website and never offers an update',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var fetches = 0;
    final container = _container(() => fetches++);
    final status = await container.read(updateStatusProvider.future);
    expect(status, isA<UpdateUnknown>());
    expect(fetches, 0);
  });

  test('a website APK still finds a newer version', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    var fetches = 0;
    final container = _container(() => fetches++);
    final status = await container.read(updateStatusProvider.future);
    expect(status, isA<UpdateAvailable>());
    expect(fetches, 1);
  });
}
