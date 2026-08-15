import '../../data/models/enums.dart';

/// The four adults a hand-off can name, as a value rather than a string.
///
/// The spoken/written message uses whatever the educator typed, but the
/// *picture* on the lock screen has to resolve to one of exactly four
/// artworks — so the figure is modelled separately from the wording. A
/// learner who cannot read still recognises the picture.
enum HandoffFigure { maam, sir, mommy, daddy }

/// How the "Time's up" hand-off message addresses the adult who set the
/// limit — "Ma'am", "Sir", "Mommy", "Daddy", or an educator-chosen name
/// like "Teacher Ana" or "Dad".
///
/// Two inputs, in priority order:
///   1. [ChildTimeLimit.guardianPreferredName] — a free-text name the
///      parent/teacher typed. Always wins when non-empty, because family
///      and school structures vary far more than any fixed list of
///      honorifics can capture (Lola, Ate, Tita, Kuya, Teacher Ana…).
///   2. The honorific derived from the setter's *avatar* + role. The
///      educator avatars are explicitly gendered (see [AvatarData]:
///      12 = Male Teacher, 13 = Female Teacher, 14 = Father,
///      15 = Mother), so the avatar the adult picked for themselves is
///      the signal — we never infer anything from their name.
///
/// Kept pure (no Flutter, no I/O) so the whole matrix is unit-testable
/// and so [ChildTimeLimitService] can stamp the derived honorific onto
/// the Firestore document at save time. Stamping matters: the child's
/// device often cannot read the educator's profile (offline, or the
/// educator signed in on a different device), so the message has to
/// survive in the policy document itself.
class GuardianAddress {
  const GuardianAddress._();

  // Avatar indices from [AvatarData.avatars]. Duplicated as named
  // constants rather than imported so this stays free of Flutter deps
  // (AvatarData pulls in material.dart for its Color field).
  static const int avatarMaleTeacher = 12;
  static const int avatarFemaleTeacher = 13;
  static const int avatarFather = 14;
  static const int avatarMother = 15;

  /// The honorific implied by the setter's role + chosen avatar.
  ///
  /// Falls back to a role-appropriate, gender-neutral term when the
  /// avatar isn't one of the four gendered educator avatars (e.g. an
  /// educator who kept an animal avatar from a legacy profile).
  static String honorificFor({
    required UserRole role,
    required int avatarIndex,
  }) {
    switch (role) {
      case UserRole.teacher:
        return switch (avatarIndex) {
          avatarFemaleTeacher => "Ma'am",
          avatarMaleTeacher => 'Sir',
          _ => 'your teacher',
        };
      case UserRole.parent:
        return switch (avatarIndex) {
          avatarMother => 'Mommy',
          avatarFather => 'Daddy',
          _ => 'your parent',
        };
      case UserRole.student:
      case UserRole.child:
      case UserRole.player:
        // A learner can't set a limit, but the model allows any role in
        // `setterRole`, so degrade to something that still reads well.
        return 'your grown-up';
    }
  }

  /// The Filipino counterpart of [honorificFor], used when the learner's
  /// app locale is `fil`.
  static String honorificForFilipino({
    required UserRole role,
    required int avatarIndex,
  }) {
    switch (role) {
      case UserRole.teacher:
        return switch (avatarIndex) {
          avatarFemaleTeacher => "Ma'am",
          avatarMaleTeacher => 'Sir',
          _ => 'sa iyong guro',
        };
      case UserRole.parent:
        return switch (avatarIndex) {
          avatarMother => 'Mommy',
          avatarFather => 'Daddy',
          _ => 'sa iyong magulang',
        };
      case UserRole.student:
      case UserRole.child:
      case UserRole.player:
        return 'sa nakatatanda';
    }
  }

  /// Which of the four figures [role] + [avatarIndex] identifies, or null
  /// for a non-gendered avatar (there is no artwork for "your teacher").
  static HandoffFigure? figureFor({
    required UserRole role,
    required int avatarIndex,
  }) {
    switch (role) {
      case UserRole.teacher:
        return switch (avatarIndex) {
          avatarFemaleTeacher => HandoffFigure.maam,
          avatarMaleTeacher => HandoffFigure.sir,
          _ => null,
        };
      case UserRole.parent:
        return switch (avatarIndex) {
          avatarMother => HandoffFigure.mommy,
          avatarFather => HandoffFigure.daddy,
          _ => null,
        };
      case UserRole.student:
      case UserRole.child:
      case UserRole.player:
        return null;
    }
  }

  /// Recovers the figure from a stamped honorific string.
  ///
  /// The child's device often has only the honorific that was written onto
  /// the time-limit document, not the educator's avatar, so the picture has
  /// to be recoverable from the text. Matching is punctuation- and
  /// case-insensitive ("Ma'am", "MAAM", "ma am" all resolve) because the
  /// value has been through Firestore, Hive and two app versions.
  static HandoffFigure? figureFromHonorific(String honorific) {
    final normalised = honorific.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );
    return switch (normalised) {
      'maam' => HandoffFigure.maam,
      'sir' => HandoffFigure.sir,
      'mommy' => HandoffFigure.mommy,
      'daddy' => HandoffFigure.daddy,
      _ => null,
    };
  }

  /// Resolves the term the message should use: the educator's preferred
  /// name when set, else the stamped honorific, else a derivation from
  /// [role] + [avatarIndex], else a safe generic.
  ///
  /// [stampedHonorific] is what [ChildTimeLimit.guardianHonorific] holds —
  /// a snapshot taken on the educator's device at save time.
  static String resolve({
    required String preferredName,
    required String stampedHonorific,
    UserRole? role,
    int? avatarIndex,
  }) {
    final name = preferredName.trim();
    if (name.isNotEmpty) return name;
    final stamped = stampedHonorific.trim();
    if (stamped.isNotEmpty) return stamped;
    if (role != null) {
      return honorificFor(role: role, avatarIndex: avatarIndex ?? 0);
    }
    return 'your grown-up';
  }

  /// The spoken / captioned hand-off line.
  ///
  /// Parents get "return your device", teachers "give your device" —
  /// matching how the two hand-offs actually read in the classroom vs.
  /// at home. [address] comes from [resolve].
  static String timesUpMessage({
    required String address,
    required UserRole setterRole,
  }) {
    final verb = setterRole == UserRole.parent ? 'return' : 'give';
    return "Time's up. Please $verb your device to $address.";
  }

  /// Filipino variant, used when the learner's app locale is `fil`.
  static String timesUpMessageFilipino({
    required String address,
    required UserRole setterRole,
  }) {
    final verb = setterRole == UserRole.parent ? 'ibalik' : 'ibigay';
    return 'Tapos na ang oras. Pakisuyong $verb ang device kay $address.';
  }

  /// A short, plain-language variant for cognitive / learning profiles:
  /// one idea per sentence, no subordinate clause.
  static String timesUpMessageSimple({required String address}) {
    return "Time's up. Give the tablet to $address.";
  }

  /// Filipino counterpart of [timesUpMessageSimple].
  static String timesUpMessageSimpleFilipino({required String address}) {
    return 'Tapos na. Ibigay ang tablet kay $address.';
  }
}
