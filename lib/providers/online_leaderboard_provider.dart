import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/leaderboard.dart';
import '../data/models/leaderboard_config.dart';
import '../data/models/models.dart';
import '../data/models/shop_data.dart';
import '../data/remote/firestore_repository.dart';
import 'classroom_management_provider.dart';
import 'home_group_provider.dart';

/// Online, membership-scoped leaderboard.
///
/// Unlike the old global `leaderboardProvider` (which leaked every profile
/// on the device), this only ever contains the members of one classroom or
/// one home group. Reads are cheap (~2 Firestore reads per member) and the
/// roster source is open-read per [firestore.rules], so it works on the
/// free Spark tier with no rules change.

/// Maps an enrolled `(profile, progress)` pair to a leaderboard row.
/// Same field mapping the legacy `LeaderboardNotifier._buildEntries` used.
LeaderboardEntry _toEntry((UserProfile, LearningProgress) record) {
  final (profile, progress) = record;
  return LeaderboardEntry(
    profileId: profile.id,
    profileName: profile.name,
    avatarIndex: profile.avatarIndex,
    totalStars: progress.totalStars,
    wordsLearned: progress.wordsLearned,
    streakDays: progress.streakDays,
    gamesPlayed: progress.effectiveGamesPlayed,
    lastActivity: progress.lastActivityDate,
    // Synced value first, local Hive row second. The profile document now
    // carries these, so a classmate on another tablet arrives already wearing
    // what they bought; the Hive fallback covers this device's own learners
    // and any profile whose remote document predates the change.
    equippedAvatarId: profile.equippedAvatarId ??
        HiveService.getEquippedItem(profile.id, ShopItemType.avatar.name),
    equippedBorderId: profile.equippedBorderId ??
        HiveService.getEquippedItem(profile.id, ShopItemType.border.name),
    equippedTitleId: profile.equippedTitleId ??
        HiveService.getEquippedItem(profile.id, ShopItemType.title.name),
  );
}

/// Offline / single-device fallback: build entries from the locally cached
/// roster joined with whatever member progress exists in Hive. Members from
/// other devices that this tablet has never synced simply won't appear —
/// acceptable for an unplugged demo; the online branch covers the real case.
List<LeaderboardEntry> _localEntries(LeaderboardScope scope) {
  final memberIds = scope.kind == LeaderboardScopeKind.classroom
      ? HiveService.getMembers(scope.id!).map((m) => m.profileId).toSet()
      : HiveService.getHomeGroupMembers(
          scope.id!,
        ).map((m) => m.profileId).toSet();
  final byId = {
    for (final rec in HiveService.getAllProfilesWithProgress()) rec.$1.id: rec,
  };
  final entries = <LeaderboardEntry>[];
  for (final pid in memberIds) {
    final rec = byId[pid];
    if (rec == null || rec.$1.isGuestPlayer) continue;
    entries.add(_toEntry(rec));
  }
  entries.sort((a, b) => b.rankScore.compareTo(a.rankScore));
  return entries;
}

/// The raw (unfiltered) leaderboard rows for a scope, ranked by overall
/// score. Sort/period/hidden filtering happens in the screen via
/// [applyLeaderboardFilters] so the educator's config can be layered on.
///
/// Re-runs whenever the live roster changes (a member joins or leaves),
/// because it `ref.watch`es the membership stream.
final onlineLeaderboardProvider = FutureProvider.family
    .autoDispose<List<LeaderboardEntry>, LeaderboardScope>((ref, scope) async {
      if (!scope.isReal) return const [];
      final id = scope.id!;

      // Dependency: re-fetch when the roster changes.
      if (scope.kind == LeaderboardScopeKind.classroom) {
        ref.watch(classroomMembersProvider(id));
      } else {
        ref.watch(homeGroupMembersProvider(id));
      }

      if (!FirebaseService.isConfigured) {
        return _localEntries(scope);
      }

      const remote = FirestoreRepository();
      final pairs = scope.kind == LeaderboardScopeKind.classroom
          ? await remote.getStudentsWithProgressByClassroom(id)
          : await remote.getChildrenWithProgressByHomeGroup(id);
      final entries = pairs.map(_toEntry).toList()
        ..sort((a, b) => b.rankScore.compareTo(a.rankScore));
      return entries;
    });

/// Live leaderboard config for a scope (educator-controlled). Hive-cache
/// first, then the Firestore doc stream — same offline-first shape as
/// `classroomMembersProvider`. Emits `null` when no config doc exists yet
/// (the screen then treats the board as "not enabled").
final leaderboardConfigProvider = StreamProvider.family
    .autoDispose<LeaderboardConfig?, LeaderboardScope>((ref, scope) async* {
      if (!scope.isReal) {
        yield null;
        return;
      }
      final id = scope.id!;
      yield HiveService.getLeaderboardConfig(scope.kind, id);
      if (!FirebaseService.isConfigured) return;

      final coll = scope.kind == LeaderboardScopeKind.classroom
          ? 'leaderboard_config_classroom'
          : 'leaderboard_config_homegroup';
      yield* FirebaseService.db.collection(coll).doc(id).snapshots().map((
        snap,
      ) {
        if (!snap.exists || snap.data() == null) return null;
        final cfg = LeaderboardConfig.fromJson(
          Map<String, dynamic>.from(snap.data()!),
        );
        // Fire-and-forget Hive write so offline launches stay fresh.
        // ignore: discarded_futures
        HiveService.cacheLeaderboardConfig(scope.kind, cfg);
        return cfg;
      });
    });

/// Writes leaderboard config. The stream provider above reflects the change;
/// this also writes through to Hive optimistically so an offline educator
/// sees their toggle take effect immediately.
class LeaderboardConfigWriter {
  LeaderboardConfigWriter(this.ref);
  final Ref ref;

  Future<void> save(LeaderboardScope scope, LeaderboardConfig next) async {
    if (!scope.isReal) return;
    final uid = FirebaseService.currentUid ?? '';
    final cfg = next.copyWith(ownerUid: uid, scopeId: scope.id);

    // Optimistic local cache first (offline guarantee).
    await HiveService.cacheLeaderboardConfig(scope.kind, cfg);

    if (FirebaseService.isConfigured) {
      final coll = scope.kind == LeaderboardScopeKind.classroom
          ? 'leaderboard_config_classroom'
          : 'leaderboard_config_homegroup';
      await FirebaseService.db
          .collection(coll)
          .doc(scope.id)
          .set(cfg.toJson(), SetOptions(merge: true));
    }
    ref.invalidate(leaderboardConfigProvider(scope));
  }
}

final leaderboardConfigWriterProvider = Provider<LeaderboardConfigWriter>(
  (ref) => LeaderboardConfigWriter(ref),
);
