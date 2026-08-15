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

  /// Learner-chosen favourite vocabulary categories. Used to personalise
  /// content surfacing (e.g. prioritising these categories in suggestions).
  /// Empty by default and on non-learner profiles.
  final List<FlashcardCategory> interests;

  /// Equipped Star Shop cosmetics, carried here so they travel with the
  /// profile to other devices.
  ///
  /// [avatarIndex] is the avatar chosen at sign-up; these override it. The
  /// authoritative copy is still the per-profile Hive row that
  /// `ProgressNotifier.equipItem` writes — these are a mirror, synced so that
  /// a classmate on another tablet appears on the leaderboard wearing what
  /// they bought instead of their starting animal. Null means "not known
  /// here", which reads identically to "nothing equipped": fall back to
  /// [avatarIndex].
  final String? equippedAvatarId;
  final String? equippedBorderId;
  final String? equippedTitleId;

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
    this.interests = const [],
    this.classroomId,
    this.homeGroupId,
    this.isGuestPlayer = false,
    this.learningLevel,
    this.learningLevelOverriddenBy,
    this.learningLevelOverriddenAt,
    this.ownerUid,
    this.username,
    this.equippedAvatarId,
    this.equippedBorderId,
    this.equippedTitleId,
  });

  /// Human-readable "profile type" shown in the profile switcher.
  ///
  /// Student and Child are learner roles that self-classify an accessibility
  /// category, so their type combines the role with that category —
  /// e.g. "Student - Hearing Impairment" or "Child - No Accessibility Needs".
  /// Every other role (Teacher / Parent / Player) just shows its role label.
  String get profileTypeLabel =>
      (role == UserRole.student || role == UserRole.child)
      ? '${role.label} - ${disabilityType.profileTypeLabel}'
      : role.label;

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
    List<FlashcardCategory>? interests,
    String? Function()? classroomId,
    String? Function()? homeGroupId,
    bool? isGuestPlayer,
    LearningLevel? Function()? learningLevel,
    String? Function()? learningLevelOverriddenBy,
    DateTime? Function()? learningLevelOverriddenAt,
    String? Function()? ownerUid,
    String? Function()? username,
    String? equippedAvatarId,
    String? equippedBorderId,
    String? equippedTitleId,
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
      interests: interests ?? this.interests,
      equippedAvatarId: equippedAvatarId ?? this.equippedAvatarId,
      equippedBorderId: equippedBorderId ?? this.equippedBorderId,
      equippedTitleId: equippedTitleId ?? this.equippedTitleId,
      classroomId: classroomId != null ? classroomId() : this.classroomId,
      homeGroupId: homeGroupId != null ? homeGroupId() : this.homeGroupId,
      isGuestPlayer: isGuestPlayer ?? this.isGuestPlayer,
      learningLevel: learningLevel != null
          ? learningLevel()
          : this.learningLevel,
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

  /// Longest streak the learner has ever reached. Never decreases.
  ///
  /// [streakDays] is the *current* run and resets to 1 the moment a day is
  /// missed. XP is scored off this high-water mark instead, so being ill for a
  /// weekend costs the learner their streak flame but never the level they
  /// already earned. See [XpService.calculateXp].
  final int bestStreakDays;

  /// Lifetime count of finished games. Never decreases.
  ///
  /// [recentScores] is trimmed to the last 20 entries for the charts, so it
  /// cannot answer "how many games have I played?" — it silently freezes at 20
  /// and, before this field existed, capped game XP at 100.
  final int gamesPlayed;

  /// Every game type the learner has ever finished at least once. Never
  /// shrinks.
  ///
  /// The third lifetime record on this model, for the same reason as
  /// [bestStreakDays] and [gamesPlayed]: [recentScores] is trimmed to the last
  /// 20 entries, so "which games has this learner tried?" cannot be answered
  /// from it. Twenty games of one favourite used to erase every other type
  /// from the record — and with it the "Game Explorer" badge, which is scored
  /// off this set.
  final Set<GameType> playedGameTypes;

  /// Set of unique flashcard IDs the student has answered correctly.
  final Set<String> learnedWordIds;

  /// IDs of stories the learner has finished reading (reached the last
  /// sentence in the reader). Drives the "Read ✓" badge on story cards.
  final Set<String> completedStoryIds;

  /// Best star score (0–3) earned per story quiz, keyed by story ID.
  /// Drives the ★ badge on story cards.
  final Map<String, int> storyBestStars;

  /// Words whose Filipino Sign Language clip the learner has watched, as
  /// `HiveService.fslWordKey`s. Never shrinks.
  ///
  /// **Derived, not persisted here.** The write path is
  /// `HiveService.recordFslVideoView`, called from six different surfaces
  /// (dictionary, card viewer, both FSL games, Sign It, the AI tutor), so the
  /// set lives in its own Hive key and `getProgress` hydrates this field from
  /// it. `saveProgress` deliberately does not write it back — that would let a
  /// stale in-memory copy clobber a view recorded elsewhere.
  ///
  /// Exists on the model so sign-language engagement reaches everything that
  /// already reasons about a learner: XP, achievements, the progress screen and
  /// the research export. Before this it was written by six callers and read by
  /// exactly one label in the dictionary.
  final Set<String> signedWordKeys;

  /// Words the learner currently claims they can *produce* the sign for.
  ///
  /// Derived like [signedWordKeys] and, like it, not persisted on this row.
  /// Distinct from it in the way that matters: watching is exposure and only
  /// grows, this is capability and can be withdrawn. Earns no XP on its own —
  /// it is unverified self-report; [everConfirmedSignKeys] is what scores.
  final Set<String> canSignKeys;

  /// Words an educator has ever confirmed the learner can produce.
  ///
  /// Monotonic high-water mark, like [bestStreakDays]: an educator may later
  /// downgrade a word, which changes what everyone *sees*, but the level the
  /// learner already earned is never taken back.
  final Set<String> everConfirmedSignKeys;

  const LearningProgress({
    required this.profileId,
    this.wordsLearned = 0,
    this.streakDays = 0,
    required this.lastActivityDate,
    this.categoryProgress = const {},
    this.recentScores = const [],
    this.totalStars = 0,
    this.spentStars = 0,
    this.bestStreakDays = 0,
    this.gamesPlayed = 0,
    this.playedGameTypes = const {},
    this.learnedWordIds = const {},
    this.completedStoryIds = const {},
    this.storyBestStars = const {},
    this.signedWordKeys = const {},
    this.canSignKeys = const {},
    this.everConfirmedSignKeys = const {},
  });

  /// How many distinct signs the learner has watched.
  int get signsLearned => signedWordKeys.length;

  /// How many signs the learner says they can produce (unverified).
  int get signsClaimed => canSignKeys.length;

  /// How many signs an educator has ever confirmed. The scored figure.
  int get signsConfirmed => everConfirmedSignKeys.length;

  /// Available star balance (earned minus spent)
  int get starBalance => totalStars - spentStars;

  /// [bestStreakDays] healed for records written before the field existed, and
  /// against any writer that lets the current streak run past the recorded
  /// best. Always at least [streakDays].
  int get effectiveBestStreak =>
      bestStreakDays > streakDays ? bestStreakDays : streakDays;

  /// [gamesPlayed] healed for records written before the field existed. Legacy
  /// rows undercount by however many games fell out of the 20-entry
  /// [recentScores] window, but they can never report fewer than what is still
  /// on hand.
  int get effectiveGamesPlayed =>
      gamesPlayed > recentScores.length ? gamesPlayed : recentScores.length;

  /// [playedGameTypes] healed for records written before the field existed, by
  /// folding in whatever types are still on hand in [recentScores]. Legacy
  /// rows undercount by the types that already aged out of the window, but
  /// they can never report fewer than what is still visible.
  Set<GameType> get effectivePlayedGameTypes => {
    ...playedGameTypes,
    ...recentScores.map((s) => s.gameType),
  };

  LearningProgress copyWith({
    int? wordsLearned,
    int? streakDays,
    DateTime? lastActivityDate,
    Map<String, double>? categoryProgress,
    List<GameScore>? recentScores,
    int? totalStars,
    int? spentStars,
    int? bestStreakDays,
    int? gamesPlayed,
    Set<GameType>? playedGameTypes,
    Set<String>? learnedWordIds,
    Set<String>? completedStoryIds,
    Map<String, int>? storyBestStars,
    Set<String>? signedWordKeys,
    Set<String>? canSignKeys,
    Set<String>? everConfirmedSignKeys,
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
      bestStreakDays: bestStreakDays ?? this.bestStreakDays,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      playedGameTypes: playedGameTypes ?? this.playedGameTypes,
      learnedWordIds: learnedWordIds ?? this.learnedWordIds,
      completedStoryIds: completedStoryIds ?? this.completedStoryIds,
      storyBestStars: storyBestStars ?? this.storyBestStars,
      signedWordKeys: signedWordKeys ?? this.signedWordKeys,
      canSignKeys: canSignKeys ?? this.canSignKeys,
      everConfirmedSignKeys:
          everConfirmedSignKeys ?? this.everConfirmedSignKeys,
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

  /// Floating AI Companion ("Buddy") — a live, always-reachable assistant that
  /// wraps the on-device [TutorEngine]. Its *presentation* (motion, sound,
  /// voice, captions, haptics) adapts to the learner's accessibility profile
  /// via `CompanionPresentation`; this flag just turns the whole surface on or
  /// off. Default on so it's discoverable; hidden entirely for non-learners.
  ///
  /// Note: when a Gemini key is compiled in, the companion automatically
  /// answers free-form questions online and falls back to the offline
  /// [TutorEngine] whenever the device is offline or the request fails —
  /// there is deliberately no separate setting for that (it "just works").
  final bool aiCompanionEnabled;

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
    this.aiCompanionEnabled = true,
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
    bool? aiCompanionEnabled,
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
      aiCompanionEnabled: aiCompanionEnabled ?? this.aiCompanionEnabled,
    );
  }
}
