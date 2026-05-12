import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../core/services/home_group_code_service.dart';
import '../core/services/join_code_service.dart';
import '../core/utils/error_handler.dart';
import '../data/local/hive_service.dart';
import '../data/models/home_group.dart';
import '../data/models/home_group_member.dart';
import '../data/models/models.dart';
import 'app_providers.dart';

/// State machine for the child-side "join a home group" flow. Mirrors
/// [JoinCodeNotifier] but for the family / home-group code space.
///
/// Flow is split into [validateCode] (resolve the group from the typed
/// code) and [completeJoin] (write the fully-assembled profile +
/// membership). The post-join setup screen sits between the two so the
/// child can pick avatar / birth date / PIN before any Firestore write.
sealed class HomeGroupJoinState {
  const HomeGroupJoinState();
}

class HomeGroupJoinIdle extends HomeGroupJoinState {
  const HomeGroupJoinIdle();
}

class HomeGroupJoinLoading extends HomeGroupJoinState {
  const HomeGroupJoinLoading();
}

/// Emitted when the code resolves to a real home group — but before
/// the profile has been created.
class HomeGroupJoinValidated extends HomeGroupJoinState {
  final HomeGroup group;
  const HomeGroupJoinValidated({required this.group});
}

class HomeGroupJoinSuccess extends HomeGroupJoinState {
  final HomeGroup group;
  final UserProfile profile;
  const HomeGroupJoinSuccess({required this.group, required this.profile});
}

class HomeGroupJoinFailure extends HomeGroupJoinState {
  final String message;
  final JoinCodeError error;
  const HomeGroupJoinFailure({required this.message, required this.error});
}

class HomeGroupJoinNotifier extends Notifier<HomeGroupJoinState> {
  @override
  HomeGroupJoinState build() => const HomeGroupJoinIdle();

  void reset() {
    state = const HomeGroupJoinIdle();
  }

  /// Look up the home group for [code] without creating any profile yet.
  /// Returns the [HomeGroup] on success; emits failure state otherwise.
  Future<HomeGroup?> validateCode(String code) async {
    state = const HomeGroupJoinLoading();

    if (!FirebaseService.isConfigured) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.network,
        message:
            'Cloud sync isn\'t connected. Restart the app or check Firebase setup.\n${FirebaseService.lastInitError ?? ""}',
      );
      return null;
    }

    final HomeGroup? group;
    try {
      group = await HomeGroupCodeService.findByCode(code);
    } on JoinCodeException catch (e) {
      state = HomeGroupJoinFailure(error: e.error, message: e.message);
      return null;
    } catch (e) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.unknown,
        message: e.toString(),
      );
      return null;
    }

    if (group == null) {
      state = const HomeGroupJoinFailure(
        error: JoinCodeError.notFound,
        message: 'No home group found with that code.',
      );
      return null;
    }

    state = HomeGroupJoinValidated(group: group);
    return group;
  }

  /// Persist [profile] (enriched by the post-join setup screen) and link
  /// it to [group]. Mirrors [JoinCodeNotifier.completeJoin] for the
  /// home-group / child code space.
  Future<bool> completeJoin({
    required UserProfile profile,
    required HomeGroup group,
  }) async {
    state = const HomeGroupJoinLoading();

    final ownerUid = FirebaseService.currentUid;
    final stampedProfile = profile.ownerUid == null
        ? profile.copyWith(ownerUid: () => ownerUid)
        : profile;

    try {
      await FirebaseService.db
          .collection('profiles')
          .doc(stampedProfile.id)
          .set({
        'id': stampedProfile.id,
        'name': stampedProfile.name,
        'role': stampedProfile.role.index,
        'avatar_index': stampedProfile.avatarIndex,
        'created_at': stampedProfile.createdAt.toIso8601String(),
        'disability_type': stampedProfile.disabilityType.index,
        'home_group_id': stampedProfile.homeGroupId,
        'birth_date': stampedProfile.birthDate?.toIso8601String(),
        'grade_level': stampedProfile.gradeLevel?.index,
        'learning_level': stampedProfile.learningLevel?.index,
        'pin_hash': stampedProfile.pinHash,
        'pin_salt': stampedProfile.pinSalt,
        'pin_hash_algorithm': stampedProfile.pinHashAlgorithm,
        'is_guest_player': stampedProfile.isGuestPlayer,
        'owner_uid': stampedProfile.ownerUid,
      });

      final member = HomeGroupMember(
        homeGroupId: group.id,
        profileId: stampedProfile.id,
        displayName: stampedProfile.name,
        joinedAt: DateTime.now(),
      );
      await FirebaseService.db
          .collection('home_group_members')
          .doc('${group.id}_${stampedProfile.id}')
          .set(member.toJson());

      await HiveService.saveProfile(stampedProfile);
      await HiveService.addHomeGroupMemberLocal(member);
    } catch (e) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.unknown,
        message: 'Could not save: $e',
      );
      return false;
    }

    // setProfile flips the active profile, which triggers downstream
    // listeners (LockEnforcerGate, AlarmScheduler.init, etc). All the
    // important writes already succeeded above, so a hiccup here must
    // not turn the join into a failure or surface as the global
    // "Something went wrong" snackbar — log silently and continue.
    try {
      await ref.read(profileProvider.notifier).setProfile(stampedProfile);
    } catch (e, s) {
      ErrorHandler.report(e, s, 'completeJoin:setProfileSilent');
    }

    state = HomeGroupJoinSuccess(group: group, profile: stampedProfile);
    return true;
  }
}

final homeGroupJoinProvider =
    NotifierProvider<HomeGroupJoinNotifier, HomeGroupJoinState>(
        HomeGroupJoinNotifier.new);
