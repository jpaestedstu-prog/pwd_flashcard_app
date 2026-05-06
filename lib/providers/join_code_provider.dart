import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/services/firebase_service.dart';
import '../core/services/join_code_service.dart';
import '../data/local/hive_service.dart';
import '../data/models/classroom.dart';
import '../data/models/classroom_member.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import 'app_providers.dart';

/// State machine for the student-side "join a class" flow.
sealed class JoinCodeState {
  const JoinCodeState();
}

class JoinCodeIdle extends JoinCodeState {
  const JoinCodeIdle();
}

class JoinCodeLoading extends JoinCodeState {
  const JoinCodeLoading();
}

class JoinCodeSuccess extends JoinCodeState {
  final Classroom classroom;
  final UserProfile profile;
  const JoinCodeSuccess({required this.classroom, required this.profile});
}

class JoinCodeFailure extends JoinCodeState {
  final String message;
  final JoinCodeError error;
  const JoinCodeFailure({required this.message, required this.error});
}

/// Drives the join-by-code flow. All writes go **directly** to Firestore
/// (no sync queue, no replay delay) so the teacher sees the new student
/// in the Firebase Console as soon as the join completes.
class JoinCodeNotifier extends Notifier<JoinCodeState> {
  static const _uuid = Uuid();

  @override
  JoinCodeState build() => const JoinCodeIdle();

  void reset() {
    state = const JoinCodeIdle();
  }

  /// Join (or upgrade an existing player profile into) the class with [code].
  Future<void> joinByCode({
    required String code,
    required String name,
    UserProfile? existingProfile,
  }) async {
    state = const JoinCodeLoading();

    if (!FirebaseService.isConfigured) {
      state = JoinCodeFailure(
        error: JoinCodeError.network,
        message:
            'Cloud sync isn\'t connected. Restart the app or check Firebase setup.\n${FirebaseService.lastInitError ?? ""}',
      );
      return;
    }

    final Classroom? classroom;
    try {
      classroom = await JoinCodeService.findByCode(code);
    } on JoinCodeException catch (e) {
      state = JoinCodeFailure(error: e.error, message: e.message);
      return;
    } catch (e) {
      state = JoinCodeFailure(
        error: JoinCodeError.unknown,
        message: e.toString(),
      );
      return;
    }

    if (classroom == null) {
      state = const JoinCodeFailure(
        error: JoinCodeError.notFound,
        message: 'No class found with that code.',
      );
      return;
    }

    final displayName = name.trim().isEmpty ? 'Student' : name.trim();
    // Stamp the device's anonymous-auth uid so the new strict
    // profiles/{id} create rule (`owner_uid == request.auth.uid`)
    // accepts the write. Without this, the join silently fails.
    final ownerUid = FirebaseService.currentUid;

    final profile = existingProfile != null
        ? existingProfile.copyWith(
            name: displayName,
            classroomId: () => classroom!.id,
            isGuestPlayer: false,
            ownerUid: () => existingProfile.ownerUid ?? ownerUid,
          )
        : UserProfile(
            id: _uuid.v4(),
            name: displayName,
            role: UserRole.student,
            createdAt: DateTime.now(),
            classroomId: classroom.id,
            ownerUid: ownerUid,
          );

    try {
      // Write profile to Firestore.
      await FirebaseService.db.collection('profiles').doc(profile.id).set({
        'id': profile.id,
        'name': profile.name,
        'role': profile.role.index,
        'avatar_index': profile.avatarIndex,
        'created_at': profile.createdAt.toIso8601String(),
        'disability_type': profile.disabilityType.index,
        'classroom_id': profile.classroomId,
        'is_guest_player': profile.isGuestPlayer,
        'owner_uid': profile.ownerUid,
      });

      // Write classroom membership to Firestore. The rule allows this
      // because `ownsProfile(profile_id)` now resolves true (the profile
      // doc above has owner_uid matching this device's uid).
      final member = ClassroomMember(
        classroomId: classroom.id,
        profileId: profile.id,
        displayName: displayName,
        joinedAt: DateTime.now(),
      );
      await FirebaseService.db
          .collection('classroom_members')
          .doc('${classroom.id}_${profile.id}')
          .set(member.toJson());

      // Mirror to local Hive so the student can use the app offline.
      await HiveService.saveProfile(profile);
      await HiveService.addMemberLocal(member);
      await ref.read(profileProvider.notifier).setProfile(profile);
    } catch (e) {
      state = JoinCodeFailure(
        error: JoinCodeError.unknown,
        message: 'Could not save: $e',
      );
      return;
    }

    state = JoinCodeSuccess(classroom: classroom, profile: profile);
  }
}

final joinCodeProvider =
    NotifierProvider<JoinCodeNotifier, JoinCodeState>(JoinCodeNotifier.new);
