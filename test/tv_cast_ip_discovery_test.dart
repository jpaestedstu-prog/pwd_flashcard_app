import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_ip_discovery.dart';

/// The address in the TV Cast link. A phone has mobile-data interfaces a TV
/// can never reach, and a hotspot interface the TV joins; the old picker could
/// hand the TV the carrier's address when the phone shared its hotspot.
void main() {
  ({String name, String address}) i(String name, String address) =>
      (name: name, address: address);

  test('a tablet on Wi-Fi: its Wi-Fi address', () {
    expect(pickCastAddress([i('wlan0', '192.168.1.23')]), '192.168.1.23');
  });

  test('a phone on Wi-Fi with mobile data up: the Wi-Fi address', () {
    expect(
      pickCastAddress([
        i('rmnet_data0', '10.120.4.9'),
        i('wlan0', '192.168.1.40'),
      ]),
      '192.168.1.40',
    );
  });

  test('a phone sharing its hotspot: the hotspot, never the carrier', () {
    for (final hotspot in ['swlan0', 'ap0', 'wlan1', 'softap0']) {
      expect(
        pickCastAddress([
          i('rmnet_data2', '10.33.120.7'),
          i(hotspot, '192.168.43.1'),
        ]),
        '192.168.43.1',
        reason: hotspot,
      );
    }
  });

  test('a phone on mobile data only: none (the screen says join Wi-Fi)', () {
    expect(
      pickCastAddress([
        i('rmnet_data0', '10.120.4.9'),
        i('ccmni1', '100.72.10.3'),
        i('v4-rmnet_data0', '192.0.0.4'),
      ]),
      isNull,
    );
  });

  test('a VPN does not take the place of the Wi-Fi', () {
    expect(
      pickCastAddress([i('tun0', '10.8.0.2'), i('wlan0', '192.168.0.5')]),
      '192.168.0.5',
    );
  });

  test('link-local and carrier-grade addresses are never used', () {
    expect(pickCastAddress([i('wlan0', '169.254.10.3')]), isNull);
    expect(pickCastAddress([i('eth0', '100.64.0.9')]), isNull);
  });

  test('Wi-Fi before a hotspot before Ethernet', () {
    expect(
      pickCastAddress([
        i('eth0', '192.168.5.2'),
        i('ap0', '192.168.43.1'),
        i('wlan0', '192.168.1.9'),
      ]),
      '192.168.1.9',
    );
    expect(
      pickCastAddress([i('eth0', '192.168.5.2'), i('ap0', '192.168.43.1')]),
      '192.168.43.1',
    );
  });

  test('desktop names: "Wi-Fi" before "Ethernet"', () {
    expect(
      pickCastAddress([
        i('Ethernet', '192.168.5.2'),
        i('Wi-Fi', '192.168.1.9'),
      ]),
      '192.168.1.9',
    );
  });

  test('a private address before a public one on the same kind', () {
    expect(
      pickCastAddress([i('wlan0', '203.0.113.5'), i('wlan0', '192.168.1.9')]),
      '192.168.1.9',
    );
  });
}
