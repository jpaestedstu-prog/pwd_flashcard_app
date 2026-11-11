import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/localized_date.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';

/// Times in words for a voice: screens showed "4m 30s", "5m ago" and "3d
/// left", which a speech engine reads as "4 meters 30 s" (29 Oct).
void main() {
  final en = AppLocalizationsEn();
  final fil = AppLocalizationsFil();

  group('LocalizedDuration.long', () {
    test('says each unit as a word', () {
      expect(
        LocalizedDuration.long(const Duration(minutes: 4, seconds: 30), en),
        '4 minutes 30 seconds',
      );
      expect(LocalizedDuration.long(const Duration(minutes: 1), en), '1 minute');
      expect(LocalizedDuration.long(const Duration(seconds: 30), en),
          '30 seconds');
      expect(LocalizedDuration.long(Duration.zero, en), '0 seconds');
    });

    test('leaves out the seconds once there are hours', () {
      expect(
        LocalizedDuration.long(
          const Duration(hours: 1, minutes: 5, seconds: 9),
          en,
        ),
        '1 hour 5 minutes',
      );
      expect(LocalizedDuration.long(const Duration(hours: 2), en), '2 hours');
    });

    test('in Filipino', () {
      expect(
        LocalizedDuration.long(const Duration(minutes: 4, seconds: 30), fil),
        '4 minuto 30 segundo',
      );
      expect(
        LocalizedDuration.long(const Duration(hours: 1, minutes: 5), fil),
        '1 oras 5 minuto',
      );
    });
  });

  group('LocalizedDuration.ago', () {
    test('counts up to a week', () {
      String? ago(Duration d) => LocalizedDuration.ago(d, filipino: false);
      expect(ago(const Duration(seconds: 20)), 'just now');
      expect(ago(const Duration(minutes: 1)), '1 minute ago');
      expect(ago(const Duration(minutes: 5)), '5 minutes ago');
      expect(ago(const Duration(hours: 3)), '3 hours ago');
      expect(ago(const Duration(days: 6)), '6 days ago');
      expect(ago(const Duration(days: 7)), isNull,
          reason: 'from a week on, a date says it better');
    });

    test('in Filipino', () {
      expect(
        LocalizedDuration.ago(const Duration(minutes: 5), filipino: true),
        '5 minuto ang nakaraan',
      );
      expect(
        LocalizedDuration.ago(const Duration(days: 3), filipino: true),
        '3 araw ang nakaraan',
      );
    });
  });

  test('an inbox row says how long ago in words', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(
      MessageTime.relativeSpoken(
        now.subtract(const Duration(minutes: 5)),
        isFilipino: false,
        now: now,
      ),
      '5 minutes ago',
    );
    expect(
      MessageTime.relative(
        now.subtract(const Duration(minutes: 5)),
        isFilipino: false,
        now: now,
      ),
      '5m',
      reason: 'the row still shows the short form',
    );
    expect(
      MessageTime.relativeSpoken(
        DateTime(2026, 10, 3, 9),
        isFilipino: false,
        now: now,
      ),
      'Oct 3',
    );
  });
}
