import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/distribution.dart';
import '../../data/local/hive_service.dart';

/// The newest APK the project website offers, read from its `version.json`.
///
/// The app is installed from an APK, never from a store, so nothing tells a
/// tablet that a newer build exists. The website publishes this small file
/// with every release (`tools/release_page_build.py` writes it from the same
/// data as the download section), and the app compares its own build number.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    required this.date,
    required this.pageUrl,
    this.notesEn = '',
    this.notesFil = '',
  });

  final String version;
  final int build;
  final String date;
  final String pageUrl;
  final String notesEn;
  final String notesFil;

  /// Null when the file is not the shape this build understands — a broken
  /// or future file must never throw on a learner's tablet.
  static AppRelease? tryParse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final latest = json['latest'];
      if (latest is! Map<String, dynamic>) return null;
      final version = latest['version'];
      final build = latest['build'];
      final page = latest['page'];
      if (version is! String || build is! int || page is! String) return null;
      if (!page.startsWith('https://')) return null;
      return AppRelease(
        version: version,
        build: build,
        date: latest['date'] is String ? latest['date'] as String : '',
        pageUrl: page,
        notesEn: latest['notes_en'] is String ? latest['notes_en'] as String : '',
        notesFil:
            latest['notes_fil'] is String ? latest['notes_fil'] as String : '',
      );
    } catch (_) {
      return null;
    }
  }
}

/// What the update check found.
sealed class UpdateStatus {
  const UpdateStatus();
}

/// This tablet already runs the newest build (or a newer one).
class UpToDate extends UpdateStatus {
  const UpToDate(this.installedVersion);
  final String installedVersion;
}

/// The website offers a newer build than the one installed.
class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable(this.release, this.installedVersion);
  final AppRelease release;
  final String installedVersion;
}

/// Offline, the website unreachable, or the file unreadable. Never an error
/// on screen: an update check is a courtesy, not something to fail loudly.
class UpdateUnknown extends UpdateStatus {
  const UpdateUnknown();
}

/// Where the installed version comes from — injectable for tests.
typedef InstalledVersionLoader = Future<({String version, int build})> Function();

/// Fetches the raw `version.json` — injectable for tests.
typedef VersionFetcher = Future<String?> Function(Uri url);

/// Stores the last successful fetch — injectable for tests, because a widget
/// test that writes to Hive hangs at teardown.
abstract class UpdateCheckStore {
  String? get payload;
  DateTime? get checkedAt;
  Future<void> save(String payload, DateTime at);
}

class HiveUpdateCheckStore implements UpdateCheckStore {
  const HiveUpdateCheckStore();
  @override
  String? get payload => HiveService.getUpdateCheckPayload();
  @override
  DateTime? get checkedAt => HiveService.getUpdateCheckedAt();
  @override
  Future<void> save(String payload, DateTime at) =>
      HiveService.saveUpdateCheck(payload, at);
}

/// Asks the project website whether a newer APK exists.
///
/// * At most **once a day**; otherwise the last answer is reused, so a
///   classroom of tablets opening the app all morning asks once each.
/// * Sends **nothing about the learner**: a plain GET of a static file on
///   GitHub Pages, which (like any website) sees the tablet's IP address.
/// * Free: GitHub Pages hosting, no Firebase quota.
class UpdateCheckService {
  UpdateCheckService({
    InstalledVersionLoader? installed,
    VersionFetcher? fetch,
    UpdateCheckStore? store,
    DateTime Function()? now,
  })  : _installed = installed ?? _platformVersion,
        _fetch = fetch ?? _httpGet,
        _store = store ?? const HiveUpdateCheckStore(),
        _now = now ?? DateTime.now;

  static final Uri versionUrl = Uri.parse(
    const String.fromEnvironment(
      // Test seam for trying the "update available" path on a device before
      // a newer release exists: `--dart-define=UPDATE_CHECK_URL=http://...`.
      // Release builds never set it.
      'UPDATE_CHECK_URL',
      defaultValue:
          'https://jpaestedstu-prog.github.io/pwd_flashcard_app/version.json',
    ),
  );

  /// How long a fetched answer is trusted before asking again.
  static const Duration maxAge = Duration(hours: 24);

  final InstalledVersionLoader _installed;
  final VersionFetcher _fetch;
  final UpdateCheckStore _store;
  final DateTime Function() _now;

  /// [force] skips the once-a-day limit — the "Check for updates" button.
  Future<UpdateStatus> check({bool force = false}) async {
    final ({String version, int build}) installed;
    try {
      installed = await _installed();
    } catch (_) {
      return const UpdateUnknown();
    }

    String? body;
    final last = _store.checkedAt;
    final fresh = last != null && _now().difference(last) < maxAge;
    if (!force && fresh) {
      body = _store.payload;
    } else {
      body = await _fetch(versionUrl);
      if (body != null && AppRelease.tryParse(body) != null) {
        await _store.save(body, _now());
      } else {
        // Offline or a bad file: fall back to the last good answer, if any.
        body = _store.payload;
      }
    }

    final release = body == null ? null : AppRelease.tryParse(body);
    if (release == null) return const UpdateUnknown();
    return release.build > installed.build
        ? UpdateAvailable(release, installed.version)
        : UpToDate(installed.version);
  }

  static Future<({String version, int build})> _platformVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (
      version: info.version,
      build: baseBuild(int.tryParse(info.buildNumber) ?? 0),
    );
  }

  /// The pubspec build number behind an Android versionCode.
  ///
  /// `flutter build apk --split-per-abi` prefixes each ABI: the 64-bit APK of
  /// build 5 reports 2005, the 32-bit one 1005, x86_64 4005, while the
  /// universal APK reports 5. Compared raw, a split install always looked
  /// newer than the website's build and never heard of an update. Build
  /// numbers stay below 1000, so the prefix is everything above that.
  static int baseBuild(int versionCode) => versionCode % 1000;

  static Future<String?> _httpGet(Uri url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(url);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      if (kDebugMode) debugPrint('UpdateCheckService: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

final updateCheckServiceProvider = Provider<UpdateCheckService>(
  (ref) => UpdateCheckService(),
);

/// The installed version name ("1.3.0"), for Settings → About. Read from the
/// app itself, so it can never drift from the build — the About row was a
/// fixed string and said 1.2.3 for four releases.
final installedVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// The once-a-day answer, for the educator home card and Settings.
///
/// A store copy (Google Play, the App Store) never asks the website: the store
/// updates it, and both stores forbid pointing to another download.
final updateStatusProvider = FutureProvider<UpdateStatus>((ref) async {
  if (!Distribution.current.checksWebsiteForUpdates) {
    return const UpdateUnknown();
  }
  return ref.watch(updateCheckServiceProvider).check();
});
