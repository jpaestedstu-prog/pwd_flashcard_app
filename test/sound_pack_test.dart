import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_pack.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';

/// The contract that lets Sound Packs be sold at all.
///
/// They shipped withdrawn (`available: false`) because `assets/sounds/` held
/// one set of effects and no per-pack variants: equipping a pack changed
/// nothing an ear could detect, so 20–30 stars bought silence and
/// `refundWithdrawnPurchases` had to hand them back. Putting them back on the
/// shelf is only safe while three things stay true, so all three are checked
/// here — a pack on sale whose folder is missing, undeclared, or a copy of
/// another pack recreates the original bug in a form no widget test would
/// notice.

/// Where the app looks for a pack's audio, from the repo root.
String _assetDir(SoundPack pack) => 'assets/sounds/${pack.folder}';

void main() {
  final sellablePacks = ShopData.sellableByType(ShopItemType.soundPack);

  group('the catalogue and the packs agree', () {
    test('every sound pack on sale resolves to a pack with its own folder', () {
      expect(sellablePacks, isNotEmpty,
          reason: 'the shelf is back on sale; if it is withdrawn again, '
              'this suite and shop_refund_test both need saying so');

      for (final item in sellablePacks) {
        final pack = SoundPack.forItemId(item.id);
        expect(pack, isNot(SoundPack.classic),
            reason: '${item.id} is on sale but SoundPack does not know it, so '
                'equipping it would silently play the standard effects');
        expect(pack.folder, isNotNull);
      }
    });

    test('every pack points back at a catalogue item that is on sale', () {
      for (final pack in SoundPack.values) {
        if (pack == SoundPack.classic) continue;
        final item = pack.shopItem;
        expect(item, isNotNull, reason: '${pack.name} has no catalogue entry');
        expect(item!.available, isTrue,
            reason: '${pack.name} is playable but cannot be bought');
      }
    });

    test('classic is the fallback, and is not for sale', () {
      expect(SoundPack.classic.folder, isNull);
      expect(SoundPack.classic.itemId, isNull);
      expect(SoundPack.classic.shopItem, isNull);
    });

    test('an id from a newer build falls back to classic, never to silence',
        () {
      // Equipped rows sync between a learner's devices, so an older build can
      // be handed the id of a pack it has never heard of.
      expect(SoundPack.forItemId('sound_from_the_future'), SoundPack.classic);
      expect(SoundPack.forItemId(null), SoundPack.classic);
      expect(SoundPack.forItemId('avatar_unicorn'), SoundPack.classic);
    });
  });

  group('the audio is really there', () {
    test('every pack has a file for every effect', () {
      for (final pack in SoundPack.values) {
        if (pack == SoundPack.classic) continue;
        for (final effect in SoundEffect.values) {
          final path = '${_assetDir(pack)}/${SoundService.fileNameFor(effect)}';
          final file = File(path);
          expect(file.existsSync(), isTrue,
              reason: '$path is missing — ${pack.name} is on sale, so a '
                  'learner who equipped it would hear nothing for '
                  '${effect.name}. Run: dart run tool/generate_sounds.dart');
          expect(file.lengthSync(), greaterThan(1000),
              reason: '$path is too small to be audio');
        }
      }
    });

    test('classic still has its own full set', () {
      for (final effect in SoundEffect.values) {
        final path = 'assets/sounds/${SoundService.fileNameFor(effect)}';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
      }
    });

    test('pubspec declares every pack folder', () {
      // Flutter's asset directory entries are NOT recursive: `assets/sounds/`
      // does not carry `assets/sounds/nature/`. Miss the line and the files
      // exist in the repo, pass the test above, and are absent from the
      // bundle — the one failure mode that only shows up on a device.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final pack in SoundPack.values) {
        if (pack == SoundPack.classic) continue;
        expect(pubspec, contains('${_assetDir(pack)}/'),
            reason: '${_assetDir(pack)}/ is not declared in pubspec.yaml, so '
                'it will not be bundled into the app');
      }
    });

    test('the packs actually sound different from each other', () {
      // The whole reason the shelf was withdrawn. Byte-comparing one shared
      // effect across every pack is the cheapest honest check that equipping
      // one changes what the learner hears.
      final heard = <String, String>{};
      for (final pack in SoundPack.values) {
        final dir = pack.folder == null
            ? 'assets/sounds'
            : 'assets/sounds/${pack.folder}';
        final bytes = File(
          '$dir/${SoundService.fileNameFor(SoundEffect.correct)}',
        ).readAsBytesSync();
        final fingerprint = '${bytes.length}:'
            '${bytes.take(2000).fold<int>(0, (a, b) => (a * 31 + b) & 0xffffff)}';
        expect(heard.containsKey(fingerprint), isFalse,
            reason: '${pack.name} has the same "correct" sound as '
                '${heard[fingerprint]} — equipping it would change nothing an '
                'ear could detect, which is why these were withdrawn before');
        heard[fingerprint] = pack.name;
      }
    });
  });

  group('asset paths', () {
    test('classic plays the files at the root of assets/sounds', () {
      expect(
        SoundService.assetPathFor(SoundEffect.correct, SoundPack.classic),
        'sounds/correct.wav',
      );
    });

    test('a pack plays the same file names from its own folder', () {
      expect(
        SoundService.assetPathFor(SoundEffect.starEarned, SoundPack.nature),
        'sounds/nature/star.wav',
      );
      expect(
        SoundService.assetPathFor(SoundEffect.gameComplete, SoundPack.space),
        'sounds/space/complete.wav',
      );
    });

    test('every effect has a distinct file name', () {
      final names =
          SoundEffect.values.map(SoundService.fileNameFor).toSet();
      expect(names.length, SoundEffect.values.length);
    });
  });

  group('the service resolves the equipped pack', () {
    test('no resolver means classic', () {
      expect(SoundService().pack, SoundPack.classic);
    });

    test('the resolver decides which folder plays', () {
      var equipped = SoundPack.chiptune;
      final service = SoundService(packResolver: () => equipped);
      expect(service.pack, SoundPack.chiptune);

      // Equipping in the shop must take effect without rebuilding the service
      // — it holds the app's only AudioPlayer.
      equipped = SoundPack.space;
      expect(service.pack, SoundPack.space);
    });

    test('a resolver that throws falls back to classic, never to silence', () {
      final service = SoundService(
        packResolver: () => throw StateError('no profile'),
      );
      expect(service.pack, SoundPack.classic);
    });
  });
}
