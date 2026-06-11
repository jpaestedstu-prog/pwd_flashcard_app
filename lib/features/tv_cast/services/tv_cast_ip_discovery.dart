import 'dart:io';

/// Finds the device's local Wi-Fi IPv4 address using only `dart:io`,
/// so we don't need a federated `network_info_plus` plugin (which would
/// bring Kotlin/Swift code and risk the Flutter 3.44 / KGP 2.2.0 conflict).
class TvCastIpDiscovery {
  TvCastIpDiscovery._();

  /// Returns the first non-loopback, non-link-local IPv4 address found
  /// on any active network interface. Prefers names that look like
  /// Wi-Fi (`wlan*`, `en*`, `Wi-Fi`) but falls back to any usable IPv4.
  static Future<String?> findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      String? firstAny;
      String? firstWifi;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        final isWifiLike =
            name.startsWith('wlan') ||
            name.startsWith('en') ||
            name.contains('wi-fi') ||
            name.contains('wifi') ||
            name.contains('wlp');
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final s = addr.address;
          // Skip 169.254/16 link-local APIPA fallbacks
          if (s.startsWith('169.254.')) continue;
          firstAny ??= s;
          if (isWifiLike) {
            firstWifi ??= s;
          }
        }
      }
      return firstWifi ?? firstAny;
    } catch (_) {
      return null;
    }
  }
}
