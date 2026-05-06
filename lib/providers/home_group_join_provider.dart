import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/firebase_service.dart';
import '../core/services/home_group_code_service.dart';
import '../core/services/join_code_service.dart';
import '../core/services/learning_level_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/enums.dart';
import '../data/models/home_group.dart';
import '../data/models/home_group_member.dart';
import '../data/models/models.dart';
import 'app_providers.dart';

/// State machine for the child-side "join a home group" flow. Mirrors
/// [JoinCodeNotifier] but for the family / home-group code space.
sealed class HomeGroupJoinState {
  const HomeGroupJoinState();
}

class HomeGroupJoinIdle extends HomeGroupJoinState {
  const HomeGroupJoinIdle();
}

class HomeGroupJoinLoading extends HomeGroupJoinState {
  const HomeGroupJoinLoading();
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
  static const _uuid = Uuid();

  @override
  HomeGroupJoinState build() => const HomeGroupJoinIdle();

  void reset() {
    state = const HomeGroupJoinIdle();
  }

  /// Join (or upgrade an existing player profile into) the home group with
  /// [code]. Optional [birthDate] lets us suggest a learning level on the
  /// new profile.
  Future<void> joinByCode({
    required String code,
    required String name,
    DateTime? birthDate,
    UserProfile? existingProfile,
  }) async {
    state = const HomeGroupJoinLoading();

    if (!FirebaseService.isConfigured) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.network,
        message:
            'Cloud sync isn\'t connected. Restart the app or check Firebase setup.\n${FirebaseService.lastInitError ?? ""}',
      );
      return;
    }

    final HomeGroup? group;
    try {
      group = await HomeGroupCodeService.findByCode(code);
    } on JoinCodeException catch (e) {
      state = HomeGroupJoinFailure(error: e.error, message: e.message);
      return;
    } catch (e) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.unknown,
        message: e.toString(),
      );
      return;
    }

    if (group == null) {
      state = const HomeGroupJoinFailure(
        error: JoinCodeError.notFound,
        message: 'No home group found with that code.',
      );
      return;
    }

    final displayName = name.trim().isEmpty ? 'Child' : name.trim();
    final ownerUid = FirebaseService.currentUid;
    final initialLevel = LearningLevelService.suggestLevelFromBirthDate(
      birthDate ?? existingProfile?.birthDate,
    );

    final profile = existingProfile != null
        ? existingProfile.copyWith(
            name: displayName,
            role: UserRole.child,
            homeGroupId: () => group!.id,
            isGuestPlayer: false,
            birthDate: birthDate != null ? () => birthDate : null,
            learningLevel: existingProfile.learningLevel == null
                ? () => initialLevel
                : null,
            ownerUid: () => existingProfile.ownerUid ?? ownerUid,
          )
        : UserProfile(
            id: _uuid.v4(),
            name: displayName,
            role: UserRole.child,
            createdAt: DateTime.now(),
            homeGroupId: group.id,
            birthDate: birthDate,
            learningLevel: initialLevel,
            ownerUid: ownerUid,
          );

    try {
      await FirebaseService.db.collection('profiles').doc(profile.id).set({
        'id': profile.id,
        'name': profile.name,
        'role': profile.role.index,
        'avatar_index': profile.avatarIndex,
        'created_at': profile.createdAt.toIso8601String(),
        'disability_type': profile.disabilityType.index,
        'home_group_id': profile.homeGroupId,
        'birth_date': profile.birthDate?.toIso8601String(),
        'learning_level': profile.learningLevel?.index,
        'is_guest_player': profile.isGuestPlayer,
        'owner_uid': profile.ownerUid,
      });

      final member = HomeGroupMember(
        homeGroupId: group.id,
        profileId: profile.id,
        displayName: displayName,
        joinedAt: DateTime.now(),
      );
      await FirebaseService.db
          .collection('home_group_members')
          .doc('${group.id}_${profile.id}')
          .set(member.toJson());

      await HiveService.saveProfile(profile);
      await HiveService.addHomeGroupMemberLocal(member);
      await ref.read(profileProvider.notifier).setProfile(profile);
    } catch (e) {
      state = HomeGroupJoinFailure(
        error: JoinCodeError.unknown,
        message: 'Could not save: $e',
      );
      return;
    }

    state = HomeGroupJoinSuccess(group: group, profile: profile);
  }
}

final homeGroupJoinProvider =
    NotifierProvider<HomeGroupJoinNotifier, HomeGroupJoinState>(
        HomeGroupJoinNotifier.new);
