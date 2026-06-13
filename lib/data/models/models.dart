import 'enums.dart';

/// A single flashcard with English/Filipino word pair
class Flashcard {
  final String id;
  final String wordEnglish;
  final String wordFilipino;
  final String? exampleSentence;
  /// Short, kid-friendly meaning of the word. Shown in the Word Hunt camera
  /// sheet and any other learning surface. English-only, mirroring
  /// [exampleSentence]; null when no definition is available.
  final String? definition;
  final String? imageAsset; // asset path or null for placeholder
  final FlashcardCategory category;
  final bool isCustom;

  const Flashcard({
    required this.id,
    required this.wordEnglish,
    required this.wordFilipino,
    this.exampleSentence,
    this.definition,
    this.imageAsset,
    required this.category,
    this.isCustom = false,
  });

  Flashcard copyWith({
    String? id,
    String? wordEnglish,
    String? wordFilipino,
    String? exampleSentence,
    String? definition,
    String? imageAsset,
    FlashcardCategory? category,
    bool? isCustom,
  }) {
    return Flashcard(
      id: id ?? this.id,
      wordEnglish: wordEnglish ?? this.wordEnglish,
      wordFilipino: wordFilipino ?? this.wordFilipino,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      definition: definition ?? this.definition,
      imageAsset: imageAsset ?? this.imageAsset,
      category: category ?? this.category,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  /// Serializes to a JSON-compatible map for export/import.
  Map<String, dynamic> toJson() => {
    'id': id,
    'wordEnglish': wordEnglish,
    'wordFilipino': wordFilipino,
    'exampleSentence': exampleSentence,
    'definition': definition,
    'imageAsset': imageAsset,
    'category': category.index,
    'isCustom': isCustom,
  };

  /// Deserializes from a JSON-compatible map.
  factory Flashcard.fromJson(Map<String, dynamic> json) {
    final catIndex = json['category'] as int;
    return Flashcard(
      id: json['id'] as String,
      wordEnglish: json['wordEnglish'] as String,
      wordFilipino: json['wordFilipino'] as String,
      exampleSentence: json['exampleSentence'] as String?,
      definition: json['definition'] as String?,
      imageAsset: json['imageAsset'] as String?,
      category: (catIndex >= 0 && catIndex < FlashcardCategory.values.length)
          ? FlashcardCategory.values[catIndex]
          : FlashcardCategory.animals, // fallback for corrupted data
      isCustom: json['isCustom'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flashcard && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// A deck of flashcards grouped by category or custom collection
class FlashcardDeck {
  final String id;
  final String name;
  final FlashcardCategory category;
  final List<String> flashcardIds;
  final bool isCustom;

  const FlashcardDeck({
    required this.id,
    required this.name,
    required this.category,
    required this.flashcardIds,
    this.isCustom = false,
  });
}

/// User profile with optional PIN protection
class UserProfile {
  final String id;
  final String name;
  final UserRole role;
  final int avatarIndex;
  final DateTime createdAt;
  final DisabilityType disabilityType;
  /// Legacy plaintext PIN. Set to null after PinMigration runs. Kept for
  /// backwards compatibility with un-migrated installs only.
  final String? pin;
  final String? pinHash;
  final String? pinSalt;
  final String? pinHashAlgorithm;
  final int failedAttempts;
  final DateTime? lockedUntil;
  /// Hash of the one-time recovery code for teacher/parent profiles. Null
  /// for student profiles (which use educator override instead).
  final String? recoveryCodeHash;
  final String? recoveryCodeSalt;
  final GradeLevel? gradeLevel;
  final String? section;
  final DateTime? birthDate;
  final List<String> tags;
  /// Classroom this profile is enrolled in. Null for unlinked profiles
  /// (player mode, teachers, parents).
  final String? classroomId;
  /// Home group this profile is enrolled in. Null for non-child profiles
  /// and for children who haven't joined a group yet.
  final String? homeGroupId;
  /// True for casual "Player Mode" profiles. Skips classroom linkage and
  /// remote progress sync; everything stays local for the session.
  ///
  /// Mirrors `role == UserRole.player` — kept as a stored field so existing
  /// call sites and serialized profiles continue to work without a data
  /// migration. New profiles set both consistently.
  final bool isGuestPlayer;
  /// Adaptive learning level. Null only on legacy profiles created before
  /// the field existed; treat null as [LearningLevel.beginner] in the UI.
  final LearningLevel? learningLevel;
  /// UID of the teacher / parent who last overrode this learner's level.
  /// While non-null, the adaptive auto-promote logic is suppressed.
  final String? learningLevelOverriddenBy;
  /// When the override was applied. Used for audit display and to bound
  /// override staleness.
  final DateTime? learningLevelOverriddenAt;
  /// Firebase Anonymous-Auth UID of the device that owns this profile.
  /// Stamped on save so security rules can verify the writer. Null on
  /// pre-auth profiles until [OwnerUidMigration] claims them.
  final String? ownerUid;
  /// Public-facing handle used for the messaging "add friend by username"
  /// flow. Auto-generated on first save (e.g. `maria-1947`) and unique
  /// across the project — backed by the `profile_directory/{username}`
  /// Firestore doc whose id IS the username. Null on legacy profiles
  /// until `UsernameMigration` mints one on the next launch.
  final String? username;

  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    this.avatarIndex = 0,
    required this.createdAt,
    this.disabilityType = DisabilityType.none,
    this.pin,
    this.pinHash,
    this.pinSalt,
    this.pinHashAlgorithm,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.recoveryCodeHash,
    this.recoveryCodeSalt,
    this.gradeLevel,
    this.section,
    this.birthDate,
    this.tags = const [],
    this.classroomId,
    this.homeGroupId,
    this.isGuestPlayer = false,
    this.learningLevel,
    this.learningLevelOverriddenBy,
    this.learningLevelOverriddenAt,
    this.ownerUid,
    this.username,
  });

  /// Whether this profile requires a PIN to switch to. Covers both migrated
  /// (pinHash) and pre-migration (legacy plaintext pin) profiles so unlock
  /// gating still works during the brief startup window before migration.
  bool get hasPinProtection =>
      pinHash != null || (pin != null && pin!.length == 4);

  /// True when this profile is in Player (guest) mode. Treats either the
  /// stored flag or the role enum as authoritative so legacy profiles
  /// keep working.
  bool get isPlayerMode => isGuestPlayer || role == UserRole.player;

  /// Effective learning level for UI display. Defaults to beginner when
  /// the field is null on legacy profiles.
  LearningLevel get effectiveLearningLevel =>
      learningLevel ?? LearningLevel.beginner;

  /// Whether the level is currently held by an educator override (so the
  /// adaptive promote logic should skip).
  bool get hasLearningLevelOverride => learningLevelOverriddenBy != null;

  /// Computed age from birthDate, or null if not set.
  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    int years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years--;
    }
    return years;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    UserRole? role,
    int? avatarIndex,
    DateTime? createdAt,
    DisabilityType? disabilityType,
    String? Function()? pin,
    String? Function()? pinHash,
    String? Function()? pinSalt,
    String? Function()? pinHashAlgorithm,
    int? failedAttempts,
    DateTime? Function()? lockedUntil,
    String? Function()? recoveryCodeHash,
    String? Function()? recoveryCodeSalt,
    GradeLevel? Function()? gradeLevel,
    String? Function()? section,
    DateTime? Function()? birthDate,
    List<String>? tags,
    String? Function()? classroomId,
    String? Function()? homeGroupId,
    bool? isGuestPlayer,
    LearningLevel? Function()? learningLevel,
    String? Function()? learningLevelOverriddenBy,
    DateTime? Function()? learningLevelOverriddenAt,
    String? Function()? ownerUid,
    String? Function()? username,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt ?? this.createdAt,
      disabilityType: disabilityType ?? this.disabilityType,
      pin: pin != null ? pin() : this.pin,
      pinHash: pinHash != null ? pinHash() : this.pinHash,
      pinSalt: pinSalt != null ? pinSalt() : this.pinSalt,
      pinHashAlgorithm: pinHashAlgorithm != null
          ? pinHashAlgorithm()
          : this.pinHashAlgorithm,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil != null ? lockedUntil() : this.lockedUntil,
      recoveryCodeHash: recoveryCodeHash != null
          ? recoveryCodeHash()
          : this.recoveryCodeHash,
      recoveryCodeSalt: recoveryCodeSalt != null
          ? recoveryCodeSalt()
          : this.recoveryCodeSalt,
      gradeLevel: gradeLevel != null ? gradeLevel() : this.gradeLevel,
      section: section != null ? section() : this.section,
      birthDate: birthDate != null ? birthDate() : this.birthDate,
      tags: tags ?? this.tags,
      classroomId: classroomId != null ? classroomId() : this.classroomId,
      homeGroupId: homeGroupId != null ? homeGroupId() : this.homeGroupId,
      isGuestPlayer: isGuestPlayer ?? this.isGuestPlayer,
      learningLevel:
          learningLevel != null ? learningLevel() : this.learningLevel,
      learningLevelOverriddenBy: learningLevelOverriddenBy != null
          ? learningLevelOverriddenBy()
          : this.learningLevelOverriddenBy,
      learningLevelOverriddenAt: learningLevelOverriddenAt != null
          ? learningLevelOverriddenAt()
          : this.learningLevelOverriddenAt,
      ownerUid: ownerUid != null ? ownerUid() : this.ownerUid,
      username: username != null ? username() : this.username,
    );
  }
}

/// Tracks learning progress
class LearningProgress {
  final String profileId;
  final int wordsLearned;
  final int streakDays;
  final DateTime lastActivityDate;
  final Map<String, double> categoryProgress; // category name -> 0.0 to 1.0
  final List<GameScore> recentScores;
  final int totalStars;
  final int spentStars;
  /// Set of unique flashcard IDs the student has answered correctly.
  final Set<String> learnedWordIds;
  /// IDs of stories the learner has finished reading (reached the last
  /// sentence in the reader). Drives the "Read ✓" badge on story cards.
  final Set<String> completedStoryIds;
  /// Best star score (0–3) earned per story quiz, keyed by story ID.
  /// Drives the ★ badge on story cards.
  final Map<String, int> storyBestStars;

  const LearningProgress({
    required this.profileId,
    this.wordsLearned = 0,
    this.streakDays = 0,
    required this.lastActivityDate,
    this.categoryProgress = const {},
    this.recentScores = const [],
    this.totalStars = 0,
    this.spentStars = 0,
    this.learnedWordIds = const {},
    this.completedStoryIds = const {},
    this.storyBestStars = const {},
  });

  /// Available star balance (earned minus spent)
  int get starBalance => totalStars - spentStars;

  LearningProgress copyWith({
    int? wordsLearned,
    int? streakDays,
    DateTime? lastActivityDate,
    Map<String, double>? categoryProgress,
    List<GameScore>? recentScores,
    int? totalStars,
    int? spentStars,
    Set<String>? learnedWordIds,
    Set<String>? completedStoryIds,
    Map<String, int>? storyBestStars,
  }) {
    return LearningProgress(
      profileId: profileId,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      streakDays: streakDays ?? this.streakDays,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      categoryProgress: categoryProgress ?? this.categoryProgress,
      recentScores: recentScores ?? this.recentScores,
      totalStars: totalStars ?? this.totalStars,
      spentStars: spentStars ?? this.spentStars,
      learnedWordIds: learnedWordIds ?? this.learnedWordIds,
      completedStoryIds: completedStoryIds ?? this.completedStoryIds,
      storyBestStars: storyBestStars ?? this.storyBestStars,
    );
  }
}

/// Score from a single game session
class GameScore {
  final GameType gameType;
  final int score;
  final int total;
  final int starsEarned;
  final DateTime date;
  final int? durationSeconds;

  const GameScore({
    required this.gameType,
    required this.score,
    required this.total,
    required this.starsEarned,
    required this.date,
    this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'gameType': gameType.index,
    'score': score,
    'total': total,
    'starsEarned': starsEarned,
    'date': date.toIso8601String(),
    'durationSeconds': durationSeconds,
  };

  factory GameScore.fromJson(Map<String, dynamic> json) {
    final gameTypeIndex = json['gameType'] as int;
    return GameScore(
      gameType: (gameTypeIndex >= 0 && gameTypeIndex < GameType.values.length)
          ? GameType.values[gameTypeIndex]
          : GameType.wordMatch, // fallback for corrupted data
      score: json['score'] as int,
      total: json['total'] as int,
      starsEarned: json['starsEarned'] as int,
      date: DateTime.parse(json['date'] as String),
      durationSeconds: json['durationSeconds'] as int?,
    );
  }
}

/// Accessibility / app settings
class AppSettings {
  final double fontScale;
  final bool highContrastMode;
  final bool darkMode;
  final bool ttsEnabled;
  final double ttsSpeed;
  final bool reducedMotion;
  final bool soundEffects;
  final bool speechToText;
  final String locale; // 'en' or 'fil'
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final bool voiceNavigation;
  final bool adaptiveDifficulty;
  final bool vocabReviewEnabled;
  final bool dyslexiaMode;

  /// Slow-Motion learning mode. When on, gameplay / flashcard / quiz
  /// animations play at roughly half speed (~2× duration) so learners with
  /// cognitive or processing differences can follow them. Does NOT affect
  /// TTS speed or non-learning UI animations. Default off. See
  /// [Motion] and `SlowMotionScope`.
  final bool slowMotionEnabled;

  /// Number of items in the bite-sized Daily Mission (was a single word).
  /// Clamped to 3–5 to keep cognitive load low. Default 4.
  final int dailyMissionSize;

  /// Gentler wrong-answer support in MCQ learning surfaces: shows a short
  /// "why" explanation after answering and offers a limited 50/50 hint that
  /// removes two wrong options. Default on; turn off for a plain quiz.
  final bool learningAssistEnabled;

  const AppSettings({
    this.fontScale = 1.0,
    this.highContrastMode = false,
    this.darkMode = false,
    this.ttsEnabled = true,
    this.ttsSpeed = 0.5,
    this.reducedMotion = false,
    this.soundEffects = true,
    this.speechToText = false,
    this.locale = 'en',
    this.notificationsEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.voiceNavigation = false,
    this.adaptiveDifficulty = true,
    this.vocabReviewEnabled = false,
    this.dyslexiaMode = false,
    this.slowMotionEnabled = false,
    this.dailyMissionSize = 4,
    this.learningAssistEnabled = true,
  });

  AppSettings copyWith({
    double? fontScale,
    bool? highContrastMode,
    bool? darkMode,
    bool? ttsEnabled,
    double? ttsSpeed,
    bool? reducedMotion,
    bool? soundEffects,
    bool? speechToText,
    String? locale,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    bool? voiceNavigation,
    bool? adaptiveDifficulty,
    bool? vocabReviewEnabled,
    bool? dyslexiaMode,
    bool? slowMotionEnabled,
    int? dailyMissionSize,
    bool? learningAssistEnabled,
  }) {
    return AppSettings(
      fontScale: fontScale ?? this.fontScale,
      highContrastMode: highContrastMode ?? this.highContrastMode,
      darkMode: darkMode ?? this.darkMode,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      reducedMotion: reducedMotion ?? this.reducedMotion,
      soundEffects: soundEffects ?? this.soundEffects,
      speechToText: speechToText ?? this.speechToText,
      locale: locale ?? this.locale,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      voiceNavigation: voiceNavigation ?? this.voiceNavigation,
      adaptiveDifficulty: adaptiveDifficulty ?? this.adaptiveDifficulty,
      vocabReviewEnabled: vocabReviewEnabled ?? this.vocabReviewEnabled,
      dyslexiaMode: dyslexiaMode ?? this.dyslexiaMode,
      slowMotionEnabled: slowMotionEnabled ?? this.slowMotionEnabled,
      dailyMissionSize: dailyMissionSize ?? this.dailyMissionSize,
      learningAssistEnabled:
          learningAssistEnabled ?? this.learningAssistEnabled,
    );
  }
}
