import '../../../data/models/enums.dart';
import '../../../data/models/models.dart';

/// The six kinds of profile, as Settings sees them: the five roles, with the
/// guest Player split from the progress-keeping one — they share a role but
/// not a home, a cloud copy or a single setting worth keeping.
enum ProfileKind { guestPlayer, player, student, child, teacher, parent }

extension UserProfileKind on UserProfile {
  ProfileKind get kind => switch (role) {
        UserRole.player =>
          isGuestPlayer ? ProfileKind.guestPlayer : ProfileKind.player,
        UserRole.student => ProfileKind.student,
        UserRole.child => ProfileKind.child,
        UserRole.teacher => ProfileKind.teacher,
        UserRole.parent => ProfileKind.parent,
      };
}

/// Which settings — and which of the things those settings switch on —
/// belong to a profile, decided in one place.
///
/// The Settings screen used to decide row by row with an `isMonitor` flag, and
/// the rows drifted from what the profile was for: a Teacher's own Settings
/// offered Gaze Control and the game controller, and a Student's offered
/// "Classroom Mode — Monitor all students", which the router then refused.
/// Every surface that shows or runs one of these now asks here, and
/// `settings_presentation_test.dart` pins the answer for all six kinds.
///
/// The rule underneath: a **learner** (guest Player, Player, Student, Child)
/// is the person the accessibility and input features are for; a **Teacher**
/// or **Parent** manages and supports learners. An educator keeps what any
/// adult reading a screen may need (contrast, text size, motion, language,
/// spoken navigation) and sets a learner's hands-free input up *for* them,
/// from that learner's card — never as their own.
class SettingsPresentation {
  const SettingsPresentation._(this.kind);

  /// Null before anyone has signed in (splash, the profile picker).
  final ProfileKind? kind;

  factory SettingsPresentation.of(UserProfile? profile) =>
      SettingsPresentation._(profile?.kind);

  bool get isEducator =>
      kind == ProfileKind.teacher || kind == ProfileKind.parent;

  /// Anyone who learns with the app, the guest included.
  bool get isLearner => kind != null && !isEducator;

  /// A Student or a Child: enrolled by a Teacher or a Parent, on a device
  /// that grown-up looks after.
  bool get isSupervisedLearner =>
      kind == ProfileKind.student || kind == ProfileKind.child;

  // ─── Accessibility ─────────────────────────────────────────────────────

  /// Gaze Control and the Bluetooth game controller as the profile's **own**
  /// way of using the app. Learners only: the face in front of the camera,
  /// or the hands on the controller, are the learner's. A Teacher or Parent
  /// sets a learner's up from that learner's card instead
  /// ([setsUpLearnerInput]), and their own profile runs neither — see
  /// [ownsHandsFreeInput].
  bool get handsFreeInput => !isEducator;

  /// Gaze Control and the game controller set up *for a learner*, from the
  /// learner's card on an educator's dashboard.
  bool get setsUpLearnerInput => isEducator;

  /// The spoken tour of the learner tabs (Cards, Games, Stories, the Shop)
  /// that sits behind Voice-Guided Navigation. The switch itself is for
  /// everyone; the tour describes screens an educator does not have.
  bool get voiceTour => !isEducator;

  /// Whether a profile looks after its own accessibility needs: a guest or a
  /// Player, who learn on their own, with no Teacher or Parent behind them.
  bool get _ownsAccessibilityNeeds =>
      kind == ProfileKind.guestPlayer || kind == ProfileKind.player;

  /// "Re-run Accessibility Setup", the learner wizard, from Settings. A
  /// guest's and a Player's: they set themselves up. A Student's or a
  /// Child's accessibility needs are their Teacher's or Parent's to manage
  /// ([accessibilityManagedByEducator]); educators never self-classify a
  /// disability ([selfClassifiesDisability]).
  bool get accessibilitySetup => _ownsAccessibilityNeeds;

  /// Whether the profile picks its own accessibility category — the
  /// "Accessibility profile" on Edit Profile and the presets behind it. A
  /// guest's and a Player's. A Student or a Child has a category too (it
  /// shapes their content — signs, audio games — and their themes), but it
  /// is their educator's to set. An educator has none: theirs would only
  /// hide content from the person who has to support every learner.
  bool get selfClassifiesDisability => _ownsAccessibilityNeeds;

  /// A Student's or a Child's accessibility needs are managed by their
  /// Teacher or Parent: the class's or home group's category when they
  /// join, and each learner's needs from the roster in Manage Classes /
  /// Home Groups after that (see `AssignedAccessibility`). Their Settings
  /// say so where "Re-run Accessibility Setup" used to be, and Edit Profile
  /// shows the needs without letting the learner change them.
  bool get accessibilityManagedByEducator => isSupervisedLearner;

  // ─── Learning ──────────────────────────────────────────────────────────

  /// Adaptive difficulty, slow motion, learning assist, the daily mission.
  bool get learningModes => !isEducator;

  /// Speech, sound effects, voice input and the AI Companion — what a learner
  /// hears and says while studying.
  bool get learnerAudio => !isEducator;

  /// Study reminders: a reminder to study is for whoever studies.
  bool get reminders => !isEducator;

  /// The My Day switch. A Player plans their own day; a Student's or Child's
  /// is set by their Teacher or Parent (and can hold the device at a step, so
  /// a switch here would unlock their own lock); a guest keeps nothing.
  bool get myDay => kind == ProfileKind.player;

  /// Replaying the screen tutorials — the learner screens' guides.
  bool get tutorialReplay => !isEducator;

  // ─── Educator tools ────────────────────────────────────────────────────

  /// Fullscreen for a class or a TV — how the person running the session
  /// uses the device.
  bool get presentation => isEducator;

  /// Live monitoring of a whole class. The Teacher's: a Parent follows their
  /// children on the Parent Dashboard (the educator home leaves this tile out
  /// for them too), and the route turns every learner away.
  bool get classroomMode => kind == ProfileKind.teacher;

  /// Time limits, a schedule window and feature blocks. They apply to every
  /// Student and Child on the device, so they are the device's grown-up's:
  /// the Parent at home, the Teacher on a classroom tablet.
  bool get parentalControls => isEducator;

  /// Deleting other profiles on this device.
  bool get manageProfiles => isEducator;

  /// Anonymous usage statistics for the study.
  bool get telemetry => isEducator;

  /// Email sign-in, so an educator's whole setup can be restored anywhere.
  bool get linkAccount => isEducator;

  // ─── Data ──────────────────────────────────────────────────────────────

  /// Backup & Restore. A restore REPLACES every profile on the device, and a
  /// backup file carries every profile's data, so on a shared tablet it is
  /// the job of whoever looks after the device: an educator, or a Player on
  /// their own phone (whose progress has no cloud copy — this file is it).
  /// A Student's and a Child's progress is kept with their class or home
  /// group, and their recovery code brings the profile back.
  bool get deviceBackup => isEducator || kind == ProfileKind.player;

  /// The Cloud Recovery Code. A guest never had an online copy to recover.
  bool get recoveryCode => kind != null && kind != ProfileKind.guestPlayer;

  /// Reset All Data erases EVERY profile on the device — never a learner's
  /// call, and never one mis-tap or gaze dwell away from them.
  bool get resetAllData => isEducator;
}

/// Whether [profile] — the person at the tablet — runs Gaze Control and the
/// game controller as their own input.
///
/// False for a Teacher or a Parent, whatever their saved settings say: their
/// Settings no longer offer either, so a camera or controller switched on
/// by an older version (or a learner setup run on the wrong profile) must not
/// keep running with no switch left to turn it off. Null — nobody signed in
/// yet — is allowed: the profile picker must stay drivable for a hands-free
/// learner.
bool ownsHandsFreeInput(UserProfile? profile) =>
    profile == null || SettingsPresentation.of(profile).handsFreeInput;
