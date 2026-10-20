import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import 'accessibility_presets.dart';
import 'learner_support.dart';

/// The accessibility a Teacher or a Parent set for one of their learners,
/// from Manage Classes or Home Groups.
///
/// A Student's or a Child's accessibility needs are their educator's to
/// manage. The learner inherits the class's or home group's category when
/// they join; from then on a change comes from the educator — the learner's
/// own Settings no longer re-run the setup wizard, and Edit Profile shows the
/// category without letting them change it (see
/// `SettingsPresentation.accessibilityManagedByEducator`).
///
/// It travels on the learner's **membership row**
/// (`classroom_members/{class}_{learner}`,
/// `home_group_members/{group}_{learner}`). The security rules already let
/// the class's teacher or the group's parent update that row and the
/// learner's own device read it, so the change reaches a learner on another
/// tablet without the educator writing to the learner's profile, which only
/// the learner's device may. That device applies it once per version — see
/// `applyAssignedAccessibility`.
class AssignedAccessibility {
  const AssignedAccessibility({
    required this.type,
    required this.supports,
    required this.setAt,
    this.setBy,
  });

  /// [type] with the supports chosen for it (re-scoped to what that category
  /// offers), stamped now.
  factory AssignedAccessibility.chosen(
    DisabilityType type,
    Iterable<LearnerSupportOption> supports, {
    String? setBy,
    DateTime? now,
  }) => AssignedAccessibility(
    type: type,
    supports: LearnerSupportCatalog.normalize(type, supports),
    setAt: (now ?? DateTime.now()).toUtc().toIso8601String(),
    setBy: setBy,
  );

  final DisabilityType type;
  final Set<LearnerSupportOption> supports;

  /// When the educator saved it, which is also its version: a learner's
  /// device applies each version once, so saving the same choice again
  /// re-applies it (the way re-running setup did) and a stale copy never
  /// overrides a newer one.
  final String setAt;

  /// The educator's profile id.
  final String? setBy;

  // The same names the class document and the profile use for the same data.
  static const typeField = 'accessibility';
  static const supportsField = 'support_options';
  static const setAtField = 'accessibility_set_at';
  static const setByField = 'accessibility_set_by';

  /// The fields written onto the membership row.
  Map<String, dynamic> toFields() => {
    typeField: type.index,
    supportsField: LearnerSupportCatalog.encode(supports),
    setAtField: setAt,
    if (setBy != null) setByField: setBy,
  };

  /// What a membership row carries, or null when no educator has set
  /// anything for this learner since they joined (they keep what they joined
  /// with) or the row cannot be read.
  static AssignedAccessibility? fromRow(Map<String, dynamic>? row) {
    if (row == null) return null;
    final at = row[setAtField];
    final index = row[typeField];
    if (at is! String || at.isEmpty || index is! int) return null;
    if (index < 0 || index >= DisabilityType.values.length) return null;
    final type = DisabilityType.values[index];
    final raw = row[supportsField];
    return AssignedAccessibility(
      type: type,
      supports: LearnerSupportCatalog.normalize(
        type,
        LearnerSupportCatalog.decode(raw is Iterable ? raw : null),
      ),
      setAt: at,
      setBy: row[setByField] is String ? row[setByField] as String : null,
    );
  }

  /// [profile] with this category and these supports.
  UserProfile appliedTo(UserProfile profile) => profile.copyWith(
    disabilityType: type,
    supportOptions: LearnerSupportCatalog.normalize(type, supports),
  );

  /// The learner's settings under this assignment: the display and learning
  /// settings the presets touch go back to the app defaults, then take this
  /// category's preset and the chosen supports — what setting the learner up
  /// afresh would give them. Layering a new preset over an old one left
  /// leftovers that contradict it (a Cognitive learner moved to Hearing kept
  /// the dyslexia palette under Hearing's high contrast). Language,
  /// reminders, orientation and the rest are the learner's and stay.
  AppSettings settingsFrom(AppSettings current) {
    const d = AppSettings();
    final base = current.copyWith(
      fontScale: d.fontScale,
      highContrastMode: d.highContrastMode,
      darkMode: d.darkMode,
      dyslexiaMode: d.dyslexiaMode,
      ttsEnabled: d.ttsEnabled,
      ttsSpeed: d.ttsSpeed,
      voiceNavigation: d.voiceNavigation,
      soundEffects: d.soundEffects,
      reducedMotion: d.reducedMotion,
      adaptiveDifficulty: d.adaptiveDifficulty,
      slowMotionEnabled: d.slowMotionEnabled,
      learningAssistEnabled: d.learningAssistEnabled,
      dailyMissionSize: d.dailyMissionSize,
    );
    return AccessibilityPresets.applySupports(
      AccessibilityPresets.presetFor(type, current: base),
      supports,
    );
  }

  /// The hands-free input these supports switch on, if any. Only ever *on*,
  /// as in setup and Edit Profile: the educator turns a learner's gaze or
  /// controller off from the learner's own Gaze Control / Game Controller
  /// page.
  LearnerSupportOption? get inputMode =>
      LearnerSupportCatalog.inputModeIn(supports);
}
