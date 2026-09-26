import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/firestore_stream_helpers.dart'
    show homeGroupsByOwnerStreamProvider;
import '../../parent/services/parental_controls_service.dart';
import '../models/friend_models.dart';
import '../models/messaging_models.dart';
import '../services/cloud_message_repository.dart';
import '../services/friend_service.dart';

/// Shared messaging state.
///
/// Both the Messages screen and the Home hubs need the active profile's
/// messages — the screen to render them, the hubs to badge the Messages tile
/// with an unread count. Routing both through one provider means Riverpod
/// keeps a **single** pair of Firestore listeners alive no matter how many
/// widgets are watching, which is what keeps this inside the Spark-tier read
/// budget the repository's docs work through.

/// Live messages where the active profile is sender or recipient.
///
/// Emits an empty list when there is no active profile (splash / profile
/// picker) so watchers never have to special-case a null profile.
final activeProfileMessagesProvider = StreamProvider<List<LocalMessage>>((ref) {
  final profileId = ref.watch(profileProvider.select((p) => p?.id));
  if (profileId == null) return Stream.value(const <LocalMessage>[]);
  return CloudMessageRepository.instance.watchMessagesFor(profileId);
});

/// Profiles the active learner has blocked, shared by the unread badge and
/// the Messages screen. Emits the Hive cache first, so a blocked peer never
/// flashes back on cold start. Empty for educators and guests, who have no
/// block list.
final blockedProfileIdsProvider = StreamProvider<Set<String>>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null || !profileUsesFriends(profile)) {
    return Stream.value(const <String>{});
  }
  try {
    return FriendService.instance.watchBlocked(profile.id);
  } catch (_) {
    // A closed cache box (tests, early startup) must not take a Home hub down.
    return Stream.value(const <String>{});
  }
});

/// Pending friend requests sent *to* the active learner — shared by the
/// Messages screen and the Home tile, so one listener serves both.
final incomingFriendRequestsProvider = StreamProvider<List<FriendRequest>>((
  ref,
) {
  final profile = ref.watch(profileProvider);
  if (profile == null || !profileUsesFriends(profile)) {
    return Stream.value(const <FriendRequest>[]);
  }
  try {
    return FriendService.instance.watchIncomingRequests(profile.id);
  } catch (_) {
    return Stream.value(const <FriendRequest>[]);
  }
});

/// Friend requests waiting for the active **parent** to say yes or no: their
/// child asked someone, or said yes to someone. Empty for everyone else.
final parentApprovalsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null || profile.role != UserRole.parent) {
    return Stream.value(const <FriendRequest>[]);
  }
  final groups =
      ref.watch(homeGroupsByOwnerStreamProvider(profile.id)).valueOrNull ??
      const [];
  final ids = {for (final g in groups) g.id};
  if (ids.isEmpty) return Stream.value(const <FriendRequest>[]);
  return FriendService.instance.watchApprovals(ids);
});

/// How many messages the active profile has received and not yet opened.
///
/// Messages from a blocked peer never count: the peer is gone from the
/// inbox, so their unread message would be a badge nothing can clear.
///
/// Returns 0 while messaging is blocked by parental controls — a badge that
/// invites a tap the router will bounce to Home is worse than no badge.
final unreadMessageCountProvider = Provider<int>((ref) {
  final profile = ref.watch(profileProvider);
  if (profile == null) return 0;
  if (_messagingBlocked()) return 0;
  final blocked =
      ref.watch(blockedProfileIdsProvider).valueOrNull ?? const <String>{};

  return ref
      .watch(activeProfileMessagesProvider)
      .maybeWhen(
        data: (messages) => messages
            .where(
              (m) =>
                  m.recipientId == profile.id &&
                  !m.isRead &&
                  !blocked.contains(m.senderId),
            )
            .length,
        orElse: () => 0,
      );
});

/// The number on the Home hubs' Messages tile: unread messages plus friend
/// requests waiting for an answer — the learner's own to answer, or (for a
/// parent) their child's waiting for their yes. A request used to be
/// invisible until the learner happened to open Messages — and a child who
/// cannot read the app-bar badge had no way to know a classmate was asking.
final messagesTileBadgeProvider = Provider<int>((ref) {
  if (_messagingBlocked()) return 0;
  final requests =
      ref
          .watch(incomingFriendRequestsProvider)
          .valueOrNull
          ?.where((r) => r.isActionable)
          .length ??
      0;
  final approvals = ref.watch(parentApprovalsProvider).valueOrNull?.length ?? 0;
  return ref.watch(unreadMessageCountProvider) + requests + approvals;
});

/// Parental "messaging blocked" switch, read defensively.
///
/// [unreadMessageCountProvider] runs on every Home hub, so it must not be the
/// thing that takes a hub down. [ParentalControlsService] reads the `settings`
/// Hive box directly and throws if it isn't open — which is never true on a
/// real device but is entirely possible in a test or during early startup.
/// Failing open (not blocked) matches the router, which also treats an
/// unreadable control set as "no restriction".
bool _messagingBlocked() {
  try {
    return ParentalControlsService.getControls().messagingBlocked;
  } catch (_) {
    return false;
  }
}

/// Whether [profile] gets the friends toolkit (Add Friend, the requests badge,
/// the username card) rather than a fixed roster.
///
/// Students, Children, and "Player (With Progress)" have a cloud identity to
/// be found by. Guest players are local-only with no username, and educators
/// message through their classroom / home-group roster instead. Shared so the
/// screen's chrome and its empty-state copy can never disagree about which
/// kind of inbox this is.
bool profileUsesFriends(UserProfile profile) =>
    profile.role == UserRole.student ||
    profile.role == UserRole.child ||
    (profile.role == UserRole.player && !profile.isGuestPlayer);

/// Which inbox a profile sees. Distinguishes the *three* cases the old
/// `isEducator = !usesFriends` boolean collapsed into two — a guest player is
/// neither an educator nor friend-capable, and used to be shown an educator's
/// "no students in your classes yet" empty state.
enum InboxKind { learnerWithFriends, educatorRoster, guestPlayer }

InboxKind inboxKindFor(UserProfile profile) {
  if (profileUsesFriends(profile)) return InboxKind.learnerWithFriends;
  if (profile.role == UserRole.player) return InboxKind.guestPlayer;
  return InboxKind.educatorRoster;
}
