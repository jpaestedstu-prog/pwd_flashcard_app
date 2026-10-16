import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/hive_service.dart';

/// Which copy of a flashcard's FSL sign clip a device plays.
///
/// Every sign exists twice: the original recording, and a light copy of the
/// same recording that the website already serves. A friend's phone froze on
/// the originals or never started them: 1920x1080 at 60 frames a second is
/// beyond many budget phones' video decoders, and each clip is about 8 MB to
/// download before it can start (11 to 17 seconds per sign over Wi-Fi on a
/// Villaon V671N; far longer on mobile data).
enum FslClipQuality {
  /// 854x480, 30 frames a second, no sound track, about 0.3 MB. Starts at
  /// once and plays on any phone.
  light,

  /// The original: 1920x1080, 60 frames a second, about 8 MB.
  full,
}

/// The "Sign videos" choice in Settings. Kept for the device, not the
/// profile: what the video decoder and the data plan can take belongs to the
/// device, whoever is using it.
enum FslQualityChoice {
  /// [chooseFslClipQuality] decides.
  auto,

  /// Always the light copies.
  light,

  /// Always the originals.
  full;

  /// The stored name back to a choice; anything unknown is [auto].
  static FslQualityChoice parse(Object? stored) => FslQualityChoice.values
      .firstWhere((c) => c.name == stored, orElse: () => FslQualityChoice.auto);
}

/// What [FslQualityChoice.auto] plays: the light copies on a phone (a screen
/// whose shortest side is under 600 dp), on a low-memory device (Android Go),
/// on a device whose video decoder is not rated for 1080p at 60 frames a
/// second, and on a metered connection (mobile data, a phone's hotspot);
/// the originals otherwise, which keeps tablets on Wi-Fi as they were.
///
/// [decodesFullHd60] and [metered] are null when the device cannot say (no
/// native side); unknown never forces the light copies by itself. Pure, so
/// the rule is unit-tested.
FslClipQuality chooseFslClipQuality({
  required bool isPhone,
  bool? decodesFullHd60,
  bool lowRam = false,
  bool? metered,
}) {
  if (isPhone || lowRam) return FslClipQuality.light;
  if (decodesFullHd60 == false) return FslClipQuality.light;
  if (metered == true) return FslClipQuality.light;
  return FslClipQuality.full;
}

/// One place a sign clip can be fetched from, and which copy it holds.
@immutable
class FslClipSource {
  const FslClipSource(this.url, this.quality, {this.resolve = false});

  final String url;

  /// The copy the bytes are, which decides the cache key they are kept
  /// under (two copies of one sign must never share a key).
  final FslClipQuality quality;

  /// True for a CDN link that goes through `MediaUrlResolver` first.
  final bool resolve;

  @override
  bool operator ==(Object other) =>
      other is FslClipSource &&
      other.url == url &&
      other.quality == quality &&
      other.resolve == resolve;

  @override
  int get hashCode => Object.hash(url, quality, resolve);

  @override
  String toString() => 'FslClipSource(${quality.name}, $url)';
}

/// The order a card's sources are tried in when [quality] is wanted.
///
/// Light: the light copy, then the 720p `stream_url` (half the size of the
/// original), then the original `download_url`. Full: the original, its
/// 720p twin, and only then the light copy, so a tablet that cannot reach
/// either host still shows the sign. Pure, so the order is unit-tested.
List<FslClipSource> fslClipPlan({
  required FslClipQuality quality,
  String? light,
  String? download,
  String? stream,
}) {
  bool has(String? url) => url != null && url.isNotEmpty;
  final lightCopy = [
    if (has(light)) FslClipSource(light!, FslClipQuality.light),
  ];
  final original = [
    if (has(download)) FslClipSource(download!, FslClipQuality.full),
  ];
  final twin = [
    if (has(stream))
      FslClipSource(stream!, FslClipQuality.full, resolve: true),
  ];
  return quality == FslClipQuality.light
      ? [...lightCopy, ...twin, ...original]
      : [...original, ...twin, ...lightCopy];
}

/// What the device's own hardware says about video, over the
/// `flashlearn/media` channel (MainActivity). A field is null when the
/// device cannot say: no native side (the web, a desktop, a widget test).
class DeviceVideoSupport {
  const DeviceVideoSupport._();

  static const _channel = MethodChannel('flashlearn/media');

  static Future<({bool? decodesFullHd60, bool lowRam})>? _capabilities;

  /// Read once: the decoder and the memory class do not change.
  static Future<({bool? decodesFullHd60, bool lowRam})> capabilities() =>
      _capabilities ??= _readCapabilities();

  static Future<({bool? decodesFullHd60, bool lowRam})>
      _readCapabilities() async {
    try {
      final r = await _channel.invokeMapMethod<String, Object?>(
        'videoCapabilities',
      );
      return (
        decodesFullHd60: r?['fullHd60'] as bool?,
        lowRam: r?['lowRam'] == true,
      );
    } catch (_) {
      return (decodesFullHd60: null, lowRam: false);
    }
  }

  /// Whether the connection in use is metered (mobile data, or a Wi-Fi
  /// hotspot that says it is); null when it cannot be told. Read on every
  /// clip: a tablet moves between Wi-Fi and a phone's hotspot.
  static Future<bool?> isMetered() async {
    try {
      return await _channel.invokeMethod<bool>('networkMetered');
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void debugReset() => _capabilities = null;
}

/// The copy of the sign clips this device plays now: the Settings choice,
/// then for [FslQualityChoice.auto] the device and the connection
/// ([chooseFslClipQuality]). The web always takes the light copies: they
/// are served from the website itself.
class FslClipQualityService {
  const FslClipQualityService._();

  /// Device-level key in the settings box.
  static const settingKey = 'fslVideoQuality';

  static FslQualityChoice get choice {
    try {
      return FslQualityChoice.parse(HiveService.getSetting(settingKey));
    } catch (_) {
      // Settings box not open (a test, or before startup finished).
      return FslQualityChoice.auto;
    }
  }

  static Future<void> setChoice(FslQualityChoice choice) =>
      HiveService.saveSetting(settingKey, choice.name);

  static Future<FslClipQuality> current() async {
    final forced = debugQuality;
    if (forced != null) return forced;
    switch (choice) {
      case FslQualityChoice.light:
        return FslClipQuality.light;
      case FslQualityChoice.full:
        return FslClipQuality.full;
      case FslQualityChoice.auto:
        break;
    }
    if (kIsWeb) return FslClipQuality.light;
    final caps = await DeviceVideoSupport.capabilities();
    return chooseFslClipQuality(
      isPhone: _isPhone(),
      decodesFullHd60: caps.decodesFullHd60,
      lowRam: caps.lowRam,
      metered: await DeviceVideoSupport.isMetered(),
    );
  }

  /// A phone by Android's own rule: shortest side under 600 dp. Measured on
  /// the app's window, so a tablet in split screen counts as a phone too.
  static bool _isPhone() {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isEmpty) return false;
      final view = views.first;
      final size = view.physicalSize / view.devicePixelRatio;
      return size.shortestSide < 600;
    } catch (_) {
      return false;
    }
  }

  /// Test seam: the copy every clip resolves to, bypassing the choice and
  /// the device. A test that sets it clears it again.
  @visibleForTesting
  static FslClipQuality? debugQuality;
}

/// The Settings choice for the widgets that show and change it.
final fslQualityChoiceProvider =
    NotifierProvider<FslQualityChoiceNotifier, FslQualityChoice>(
  FslQualityChoiceNotifier.new,
);

class FslQualityChoiceNotifier extends Notifier<FslQualityChoice> {
  @override
  FslQualityChoice build() => FslClipQualityService.choice;

  /// Takes effect from the next sign opened; clips already downloaded stay
  /// on the device (either copy plays offline).
  Future<void> set(FslQualityChoice choice) async {
    state = choice;
    try {
      await FslClipQualityService.setChoice(choice);
    } catch (_) {
      // Settings box closed (a test): the choice still holds for the session.
    }
  }
}
