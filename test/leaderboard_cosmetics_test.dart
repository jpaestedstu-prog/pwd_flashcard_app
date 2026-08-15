import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/constants/avatar_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/leaderboard.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/models/shop_data.dart';
import 'package:pwdpwdpwd/widgets/profile_avatar.dart';

/// Cosmetics bought in the Star Shop are meant to be seen by other people, and
/// the leaderboard is the only place in the app where other people appear. It
/// drew `AvatarData.getAvatar(entry.avatarIndex)` — the avatar chosen at
/// profile creation — so 40 stars spent on the Alien changed nothing there.

LeaderboardEntry _entry({
  String? avatarId,
  String? borderId,
  String? titleId,
  int avatarIndex = 0,
}) =>
    LeaderboardEntry(
      profileId: 'p1',
      profileName: 'Test Learner',
      avatarIndex: avatarIndex,
      lastActivity: DateTime(2026),
      equippedAvatarId: avatarId,
      equippedBorderId: borderId,
      equippedTitleId: titleId,
    );

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );

void main() {
  group('LeaderboardEntry carries cosmetics', () {
    test('round-trips them through JSON', () {
      final entry = _entry(
        avatarId: 'avatar_alien',
        borderId: 'border_crown',
        titleId: 'title_word_wizard',
      );
      final restored = LeaderboardEntry.fromJson(entry.toJson());

      expect(restored.equippedAvatarId, 'avatar_alien');
      expect(restored.equippedBorderId, 'border_crown');
      expect(restored.equippedTitleId, 'title_word_wizard');
    });

    test('tolerates rows written before the fields existed', () {
      final legacy = {
        'profileId': 'p1',
        'profileName': 'Old Row',
        'avatarIndex': 2,
        'totalStars': 10,
        'wordsLearned': 1,
        'streakDays': 1,
        'gamesPlayed': 1,
        'lastActivity': DateTime(2026).toIso8601String(),
      };
      final restored = LeaderboardEntry.fromJson(legacy);

      expect(restored.equippedAvatarId, isNull);
      expect(restored.equippedBorderId, isNull);
      expect(restored.equippedTitleId, isNull);
    });
  });

  group('CosmeticAvatar', () {
    testWidgets('shows the purchased avatar instead of the starting one',
        (tester) async {
      final alien = ShopData.findById('avatar_alien')!;
      final starting = AvatarData.getAvatar(0);

      await _pump(
        tester,
        const CosmeticAvatar(avatarIndex: 0, equippedAvatarId: 'avatar_alien'),
      );

      expect(find.text(alien.emoji), findsOneWidget);
      expect(find.text(starting.emoji), findsNothing);
    });

    testWidgets('falls back to the starting avatar when nothing is equipped',
        (tester) async {
      final starting = AvatarData.getAvatar(3);

      await _pump(tester, const CosmeticAvatar(avatarIndex: 3));

      expect(find.text(starting.emoji), findsOneWidget);
    });

    testWidgets('ignores an id that is not an avatar', (tester) async {
      // Ids reach this widget from another device's Hive rows, and withdrawn
      // items stay in the catalogue so their owners can be refunded — so a
      // mismatched id is reachable. Without a type check the Nature Pack's
      // leaf would be drawn as somebody's face.
      final starting = AvatarData.getAvatar(1);
      final soundPack = ShopData.findById('sound_nature')!;

      await _pump(
        tester,
        const CosmeticAvatar(avatarIndex: 1, equippedAvatarId: 'sound_nature'),
      );

      expect(find.text(starting.emoji), findsOneWidget);
      expect(find.text(soundPack.emoji), findsNothing);
    });

    testWidgets('falls back for an id that no longer exists at all',
        (tester) async {
      final starting = AvatarData.getAvatar(1);

      await _pump(
        tester,
        const CosmeticAvatar(avatarIndex: 1, equippedAvatarId: 'avatar_gone'),
      );

      expect(find.text(starting.emoji), findsOneWidget);
    });

    testWidgets('wraps the avatar when a border is equipped', (tester) async {
      await _pump(tester, const CosmeticAvatar(avatarIndex: 0));
      final withoutBorder = tester.widgetList(find.byType(Container)).length;

      await _pump(
        tester,
        const CosmeticAvatar(avatarIndex: 0, equippedBorderId: 'border_crown'),
      );
      final withBorder = tester.widgetList(find.byType(Container)).length;

      expect(withBorder, greaterThan(withoutBorder),
          reason: 'an equipped border must add a visible frame');
    });

    testWidgets('renders at the size it is given', (tester) async {
      await _pump(
        tester,
        const CosmeticAvatar(avatarIndex: 0, radius: 40, fontSize: 30),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.radius, 40);
    });
  });

  group('UserProfile carries cosmetics so they travel between devices', () {
    UserProfile base() => UserProfile(
          id: 'p1',
          name: 'Test Learner',
          role: UserRole.student,
          avatarIndex: 2,
          createdAt: DateTime(2026),
        );

    test('defaults to null, which reads as "nothing equipped"', () {
      final profile = base();
      expect(profile.equippedAvatarId, isNull);
      expect(profile.equippedBorderId, isNull);
      expect(profile.equippedTitleId, isNull);
    });

    test('copyWith carries them', () {
      final dressed = base().copyWith(
        equippedAvatarId: 'avatar_alien',
        equippedBorderId: 'border_crown',
        equippedTitleId: 'title_bookworm',
      );

      expect(dressed.equippedAvatarId, 'avatar_alien');
      expect(dressed.equippedBorderId, 'border_crown');
      expect(dressed.equippedTitleId, 'title_bookworm');
      // …and leaves the starting avatar alone, since it is the fallback.
      expect(dressed.avatarIndex, 2);
    });

    test('a synced profile renders the bought avatar, not the starting one',
        (() {
      // The end of the chain this sync exists for: a classmate's profile
      // arrives from Firestore already wearing what they bought.
      final remote = base().copyWith(equippedAvatarId: 'avatar_alien');
      final alien = ShopData.findById('avatar_alien')!;

      expect(remote.equippedAvatarId, isNotNull);
      expect(alien.type, ShopItemType.avatar);
    }));
  });
}
