import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/firebase_service.dart';
import '../core/services/join_code_service.dart';
import '../core/utils/error_handler.dart';
import '../data/local/hive_service.dart';
import '../data/models/classroom.dart';
import '../data/models/classroom_member.dart';
import '../data/models/models.dart';
import 'app_providers.dart';

/// State machine for the student-side "join a class" flow.
///
/// The flow is split into two steps:
///   1. [JoinCodeNotifier.validateCode] looks up the classroom by code.
///      Emits [JoinCodeValidated] on success — the UI then navigates to
///      the post-join setup screen so the student can pick an avatar,
///      birth date, and PIN.
///   2. [JoinCodeNotifier.completeJoin] is called from the setup screen
///      with the fully-built [UserProfile]. It writes the profile +
///      membership to Firestore + Hive and emits [JoinCodeSuccess].
sealed class JoinCodeState {
  const JoinCodeState();
}

class JoinCodeIdle extends JoinCodeState {
  const JoinCodeIdle();
}

class JoinCodeLoading extends JoinCodeState {
  const JoinCodeLoading();
}

/// Emitted when the code resolves to a real classroom — but before the
/// profile has been created. The setup screen consumes this to know which
/// classroom to attach the new profile to.
class JoinCodeValidated extends JoinCodeState {
  final Classroom classroom;
  const JoinCodeValidated({required this.classroom});
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
  @override
  JoinCodeState build() => const JoinCodeIdle();

  void reset() {
    state = const JoinCodeIdle();
  }

  /// Look up the classroom for [code] without creating any profile yet.
  ///
  /// Returns the [Classroom] on success and emits [JoinCodeValidated];
  /// returns `null` and emits [JoinCodeFailure] otherwise. Splitting the
  /// flow this way lets the next screen collect avatar / birth-date / PIN
  /// before any Firestore write happens, so a back-button cancel never
  /// leaves a partial profile behind.
  Future<Classroom?> validateCode(String code) async {
    state = const JoinCodeLoading();

    if (!FirebaseService.isConfigured) {
      state = JoinCodeFailure(
        error: JoinCodeError.network,
        message:
            'Cloud sync isn\'t connected. Restart the app or check Firebase setup.\n${FirebaseService.lastInitError ?? ""}',
      );
      return null;
    }

    final Classroom? classroom;
    try {
      classroom = await JoinCodeService.findByCode(code);
    } on JoinCodeException catch (e) {
      state = JoinCodeFailure(error: e.error, message: e.message);
      return null;
    } catch (e) {
      state = JoinCodeFailure(
        error: JoinCodeError.unknown,
        message: e.toString(),
      );
      return null;
    }

    if (classroom == null) {
      state = const JoinCodeFailure(
        error: JoinCodeError.notFound,
        message: 'No class found with that code.',
      );
      return null;
    }

    state = JoinCodeValidated(classroom: classroom);
    return classroom;
  }

  /// Persist [profile] (already enriched with name / avatar / birth date /
  /// optional PIN by the post-join setup screen) and link it to [classroom].
  ///
  /// Stamps `owner_uid` with the device's anonymous-auth uid so the strict
  /// `profiles/{id}` create rule (`owner_uid == request.auth.uid`) accepts
  /// the write — without this, the join silently fails. If [profile]
  /// already carries an `ownerUid` (e.g. an upgrading Player), the existing
  /// value wins so we never reassign ownership.
  Future<bool> completeJoin({
    required UserProfile profile,
    required Classroom classroom,
  }) async {
    state = const JoinCodeLoading();

    final ownerUid = FirebaseService.currentUid;
    final stampedProfile = profile.ownerUid == null
        ? profile.copyWith(ownerUid: () => ownerUid)
        : profile;

    try {
      // Write profile to Firestore.
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
        'classroom_id': stampedProfile.classroomId,
        'birth_date': stampedProfile.birthDate?.toIso8601String(),
        'grade_level': stampedProfile.gradeLevel?.index,
        'learning_level': stampedProfile.learningLevel?.index,
        'pin_hash': stampedProfile.pinHash,
        'pin_salt': stampedProfile.pinSalt,
        'pin_hash_algorithm': stampedProfile.pinHashAlgorithm,
        'is_guest_player': stampedProfile.isGuestPlayer,
        'owner_uid': stampedProfile.ownerUid,
      });

      // Write classroom membership to Firestore. The rule allows this
      // because `ownsProfile(profile_id)` resolves true (the profile
      // doc above has owner_uid matching this device's uid).
      final member = ClassroomMember(
        classroomId: classroom.id,
        profileId: stampedProfile.id,
        displayName: stampedProfile.name,
        joinedAt: DateTime.now(),
      );
      await FirebaseService.db
          .collection('classroom_members')
          .doc('${classroom.id}_${stampedProfile.id}')
          .set(member.toJson());

      // Mirror to local Hive so the student can use the app offline.
      await HiveService.saveProfile(stampedProfile);
      await HiveService.addMemberLocal(member);
    } catch (e) {
      state = JoinCodeFailure(
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

    state = JoinCodeSuccess(classroom: classroom, profile: stampedProfile);
    return true;
  }
}

final joinCodeProvider =
    NotifierProvider<JoinCodeNotifier, JoinCodeState>(JoinCodeNotifier.new);
