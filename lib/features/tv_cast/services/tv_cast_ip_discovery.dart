import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Finds the device's local Wi-Fi IPv4 address using only `dart:io`,
/// so we don't need a federated `network_info_plus` plugin (which would
/// bring Kotlin/Swift code and risk the Flutter 3.44 / KGP 2.2.0 conflict).
class TvCastIpDiscovery {
  TvCastIpDiscovery._();

  /// The address a TV on the same Wi-Fi can open, or null when there is
  /// none (see [pickCastAddress] for how it is chosen).
  static Future<String?> findLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      return pickCastAddress([
        for (final iface in interfaces)
          for (final addr in iface.addresses)
            if (!addr.isLoopback) (name: iface.name, address: addr.address),
      ]);
    } catch (_) {
      return null;
    }
  }
}

/// Chooses the address to put in the cast link from the device's IPv4
/// interfaces. Pure, so the choice is unit-tested.
///
/// A tablet usually has one interface (its Wi-Fi). A phone also has its
/// mobile-data interfaces (`rmnet*`, `ccmni*`), whose addresses belong to the
/// carrier and can never be reached from a TV, and, while it shares its
/// connection, a hotspot interface (`swlan0`, `ap0`, `wlan1`) that the TV
/// joins. The old picker took "the first address of anything" when no name
/// started with `wlan`, so a phone sharing its hotspot could show a carrier
/// address and the TV never connected. Now:
///
///  * mobile data, VPN and tethering-translation interfaces are never used;
///  * Wi-Fi comes first, then a hotspot, then wired Ethernet, then anything
///    else left; within each, a private (192.168/16, 10/8, 172.16/12) address
///    before any other;
///  * link-local (169.254/16) and carrier-grade (100.64/10) addresses are
///    never used: no TV on the same Wi-Fi can reach them.
///
/// Null when nothing usable is left: the cast screen then says to join Wi-Fi.
@visibleForTesting
String? pickCastAddress(List<({String name, String address})> candidates) {
  int? rank(({String name, String address}) c) {
    final name = c.name.toLowerCase();
    if (_neverForCast.any(name.startsWith)) return null;
    final address = c.address;
    if (address.startsWith('169.254.') || _isCarrierGrade(address)) return null;
    final int kind;
    if (_hotspot.any(name.startsWith)) {
      kind = 1;
    } else if (name.startsWith('wlan') ||
        name.contains('wi-fi') ||
        name.contains('wifi') ||
        name.startsWith('wlp')) {
      kind = 0;
    } else if (name.startsWith('eth') || name.startsWith('en')) {
      kind = 2;
    } else {
      kind = 3;
    }
    return kind * 2 + (_isPrivate(address) ? 0 : 1);
  }

  String? best;
  int? bestRank;
  for (final c in candidates) {
    final r = rank(c);
    if (r == null) continue;
    if (bestRank == null || r < bestRank) {
      best = c.address;
      bestRank = r;
    }
  }
  return best;
}

/// Mobile data (Qualcomm `rmnet`, MediaTek `ccmni`, older `pdp`/`ppp`),
/// IPv6-only carriers' 464XLAT (`clat`, `v4-`), VPNs (`tun`, `ipsec`) and
/// the modem's own (`ims`, `dummy`, `wwan`, `radio`).
const _neverForCast = [
  'rmnet', 'ccmni', 'pdp', 'ppp', 'wwan', 'radio', 'ims', 'clat', 'v4-',
  'tun', 'ipsec', 'dummy',
];

/// Interfaces a phone or tablet shares its connection on.
const _hotspot = ['swlan', 'ap', 'softap', 'wlan1', 'rndis', 'bt-pan'];

bool _isPrivate(String address) {
  final p = address.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((x) => x == null)) return false;
  final a = p[0]!, b = p[1]!;
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}

bool _isCarrierGrade(String address) {
  final p = address.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((x) => x == null)) return false;
  return p[0] == 100 && p[1]! >= 64 && p[1]! <= 127;
}
