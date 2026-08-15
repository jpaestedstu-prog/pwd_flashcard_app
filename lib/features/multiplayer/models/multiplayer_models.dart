// Models backing the "Play Together" multiplayer feature.
//
// Two mini-games (vocabulary quiz race, memory match race) are played either
// same-device (pass-and-play) or online with a friend over Firestore. The
// online layer mirrors the cross-device friend layer: all persistence lives in
// Firestore (free Spark tier) and the JSON keys match the document shape
// exactly. NOTHING here touches stars / XP / streak — scores are in-memory
// match points only ("solely gameplay and enjoyment").

import 'dart:math';

import '../../../data/models/models.dart';

/// Which mini-game a match plays. The lobby lets the host pick before
/// inviting a friend (online) or starting a local pass-and-play match.
///
/// `quizRace`, `pictureRace` and `trueFalseRace` all use [MpQuestion] content
/// (and the shared quiz player); `memoryRace` uses [MemoryCardSpec] layout;
/// `scrambleRace` uses [MpScrambleItem]. Wire values are name-based, so the
/// declaration order is purely cosmetic (drives the lobby list order).
enum MpGameMode {
  quizRace,
  pictureRace,
  trueFalseRace,
  memoryRace,
  scrambleRace,
}

extension MpGameModeX on MpGameMode {
  String get wire => switch (this) {
    MpGameMode.quizRace => 'quizRace',
    MpGameMode.pictureRace => 'pictureRace',
    MpGameMode.trueFalseRace => 'trueFalseRace',
    MpGameMode.memoryRace => 'memoryRace',
    MpGameMode.scrambleRace => 'scrambleRace',
  };

  static MpGameMode fromWire(String? s) => switch (s) {
    'pictureRace' => MpGameMode.pictureRace,
    'trueFalseRace' => MpGameMode.trueFalseRace,
    'memoryRace' => MpGameMode.memoryRace,
    'scrambleRace' => MpGameMode.scrambleRace,
    _ => MpGameMode.quizRace,
  };

  /// True for the modes that render with the shared multiple-choice player.
  bool get usesQuestions =>
      this == MpGameMode.quizRace ||
      this == MpGameMode.pictureRace ||
      this == MpGameMode.trueFalseRace;

  String get label => switch (this) {
    MpGameMode.quizRace => 'Word Quiz Race',
    MpGameMode.pictureRace => 'Picture Quiz',
    MpGameMode.trueFalseRace => 'True or False',
    MpGameMode.memoryRace => 'Memory Match Race',
    MpGameMode.scrambleRace => 'Word Scramble',
  };

  String get labelFilipino => switch (this) {
    MpGameMode.quizRace => 'Karera ng Salita',
    MpGameMode.pictureRace => 'Larong Larawan',
    MpGameMode.trueFalseRace => 'Tama o Mali',
    MpGameMode.memoryRace => 'Karera ng Memorya',
    MpGameMode.scrambleRace => 'Gulong Salita',
  };

  String get emoji => switch (this) {
    MpGameMode.quizRace => '⚡',
    MpGameMode.pictureRace => '🖼️',
    MpGameMode.trueFalseRace => '✅',
    MpGameMode.memoryRace => '🧠',
    MpGameMode.scrambleRace => '🔤',
  };

  String get description => switch (this) {
    MpGameMode.quizRace => 'Answer the same words — most correct wins!',
    MpGameMode.pictureRace => 'Name the picture — most correct wins!',
    MpGameMode.trueFalseRace => 'Is it right? Tap fast — most correct wins!',
    MpGameMode.memoryRace => 'Find all the matching pairs the fastest!',
    MpGameMode.scrambleRace => 'Unscramble the letters — most words wins!',
  };

  String get descriptionFilipino => switch (this) {
    MpGameMode.quizRace =>
      'Sagutin ang parehong salita — panalo ang pinakamarami!',
    MpGameMode.pictureRace =>
      'Pangalanan ang larawan — panalo ang pinakamarami!',
    MpGameMode.trueFalseRace =>
      'Tama ba? Pindutin agad — panalo ang pinakamarami!',
    MpGameMode.memoryRace =>
      'Hanapin ang lahat ng magkapares nang pinakamabilis!',
    MpGameMode.scrambleRace =>
      'Ayusin ang mga letra — panalo ang pinakamaraming salita!',
  };
}

/// Lifecycle of an online match. Stored as a short wire string (mirrors
/// [FriendRequestStatus] in friend_models.dart).
enum GameRoomStatus { waiting, active, finished, cancelled }

extension GameRoomStatusX on GameRoomStatus {
  String get wire => switch (this) {
    GameRoomStatus.waiting => 'waiting',
    GameRoomStatus.active => 'active',
    GameRoomStatus.finished => 'finished',
    GameRoomStatus.cancelled => 'cancelled',
  };

  static GameRoomStatus fromWire(String? s) => switch (s) {
    'active' => GameRoomStatus.active,
    'finished' => GameRoomStatus.finished,
    'cancelled' => GameRoomStatus.cancelled,
    _ => GameRoomStatus.waiting,
  };
}

/// A single multiple-choice question for the quiz race. The same list is
/// shared by both players so the match is fair regardless of who hosts.
class MpQuestion {
  final String prompt;
  final String promptLabel;
  final String? subtitle;
  final List<String> options;
  final int correctIndex;

  /// Flashcard behind a picture round, so the player can render the card's
  /// picture instead of [prompt]. Null for text-only rounds (true/false,
  /// translation) and for peers running an older build, where [prompt] is
  /// shown as-is.
  ///
  /// This field doubles as the "render pictorially" marker, which is why the
  /// FSL lookup uses [signCardId] instead: setting `card_id` on a word round
  /// would turn its text prompt into a picture on every peer.
  final String? cardId;

  /// Which flashcard this round is *about*, for the Filipino Sign Language
  /// lookup — set on every round type, unlike [cardId]. Null on peers running
  /// an older build, where the round simply offers no sign.
  final String? signCardId;

  const MpQuestion({
    required this.prompt,
    required this.promptLabel,
    this.subtitle,
    required this.options,
    required this.correctIndex,
    this.cardId,
    this.signCardId,
  });

  /// The card to look a sign up from: the explicit [signCardId], falling back
  /// to a picture round's [cardId] (which is the same card).
  String? get fslCardId => signCardId ?? cardId;

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'prompt_label': promptLabel,
    if (subtitle != null) 'subtitle': subtitle,
    'options': options,
    'correct_index': correctIndex,
    if (cardId != null) 'card_id': cardId,
    if (signCardId != null) 'sign_card_id': signCardId,
  };

  factory MpQuestion.fromJson(Map<String, dynamic> j) => MpQuestion(
    prompt: j['prompt'] as String? ?? '',
    promptLabel: j['prompt_label'] as String? ?? '',
    subtitle: j['subtitle'] as String?,
    options:
        (j['options'] as List?)?.map((e) => '$e').toList() ?? const <String>[],
    correctIndex: (j['correct_index'] as num?)?.toInt() ?? 0,
    cardId: j['card_id'] as String?,
    signCardId: j['sign_card_id'] as String?,
  );
}

/// One face in the memory race board. The board is a pre-shuffled list of
/// these (length == pairs * 2) so both players see the identical layout.
class MemoryCardSpec {
  final String cardId;
  final String emoji;
  final String label;

  const MemoryCardSpec({
    required this.cardId,
    required this.emoji,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
    'card_id': cardId,
    'emoji': emoji,
    'label': label,
  };

  factory MemoryCardSpec.fromJson(Map<String, dynamic> j) => MemoryCardSpec(
    cardId: j['card_id'] as String? ?? '',
    emoji: j['emoji'] as String? ?? '📖',
    label: j['label'] as String? ?? '',
  );
}

/// One word to unscramble in the word-scramble race. The host bakes the
/// shuffled [letters] so both players solve the identical puzzle.
class MpScrambleItem {
  /// English clue word shown to the player.
  final String prompt;
  final String promptEmoji;

  /// Flashcard behind the clue, so the player can render its picture instead
  /// of [promptEmoji]. Null on peers running an older build.
  final String? cardId;

  /// The Filipino word the player must spell.
  final String answer;

  /// [answer]'s letters, pre-shuffled (length == answer.length).
  final List<String> letters;

  const MpScrambleItem({
    required this.prompt,
    required this.promptEmoji,
    required this.answer,
    required this.letters,
    this.cardId,
  });

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'prompt_emoji': promptEmoji,
    'answer': answer,
    'letters': letters,
    if (cardId != null) 'card_id': cardId,
  };

  factory MpScrambleItem.fromJson(Map<String, dynamic> j) => MpScrambleItem(
    prompt: j['prompt'] as String? ?? '',
    promptEmoji: j['prompt_emoji'] as String? ?? '🔤',
    cardId: j['card_id'] as String?,
    answer: j['answer'] as String? ?? '',
    letters:
        (j['letters'] as List?)?.map((e) => '$e').toList() ?? const <String>[],
  );
}

/// An online match room. Doc id is a UUID. The host writes the full game
/// content (questions OR memory layout) so both clients render identical
/// boards without needing a shared RNG seed.
class GameRoom {
  final String id;
  final String hostProfileId;
  final String hostName;
  final String hostUid;
  final int hostAvatarIndex;
  final String? guestProfileId;
  final String? guestName;
  final int? guestAvatarIndex;

  /// The friend invited to this match. Drives the single-field
  /// `where('invited_profile_id', ==)` invite query (no composite index).
  final String invitedProfileId;
  final MpGameMode mode;
  final GameRoomStatus status;

  /// Number of quiz questions for [MpGameMode.quizRace]. For the memory race
  /// the authoritative length is `memoryLayout.length`.
  final int rounds;
  final List<MpQuestion> questions;
  final List<MemoryCardSpec> memoryLayout;
  final List<MpScrambleItem> scrambleItems;

  /// True when **either** racer's accessibility profile needs an untimed
  /// score, in which case neither side gets a speed bonus.
  ///
  /// A speed bonus is only fair when both players can go fast, so this is the
  /// one presentation decision that cannot be made per-device. The host seeds
  /// it from their own policy at [createRoom]; the guest ORs their own need in
  /// when they join, before either side can start playing (the match only goes
  /// `active` on join). Defaults false so a peer on an older build — which
  /// never writes the field — still races the classic timed match.
  final bool fairPlay;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Always equals [hostUid]; kept as a distinct field so the Firestore rule
  /// matches the owner-scoped shape used across the project.
  final String ownerUid;

  const GameRoom({
    required this.id,
    required this.hostProfileId,
    required this.hostName,
    required this.hostUid,
    required this.hostAvatarIndex,
    this.guestProfileId,
    this.guestName,
    this.guestAvatarIndex,
    required this.invitedProfileId,
    required this.mode,
    required this.status,
    required this.rounds,
    this.questions = const [],
    this.memoryLayout = const [],
    this.scrambleItems = const [],
    this.fairPlay = false,
    required this.createdAt,
    required this.updatedAt,
    required this.ownerUid,
  });

  bool get hasGuest => guestProfileId != null && guestProfileId!.isNotEmpty;

  /// Number of steps in this match — used for the live opponent progress bar.
  int get totalSteps => switch (mode) {
    MpGameMode.memoryRace => memoryLayout.length ~/ 2,
    MpGameMode.scrambleRace => scrambleItems.length,
    _ => questions.length,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'host_profile_id': hostProfileId,
    'host_name': hostName,
    'host_uid': hostUid,
    'host_avatar_index': hostAvatarIndex,
    if (guestProfileId != null) 'guest_profile_id': guestProfileId,
    if (guestName != null) 'guest_name': guestName,
    if (guestAvatarIndex != null) 'guest_avatar_index': guestAvatarIndex,
    'invited_profile_id': invitedProfileId,
    'mode': mode.wire,
    'status': status.wire,
    'rounds': rounds,
    'questions': questions.map((q) => q.toJson()).toList(),
    'memory_layout': memoryLayout.map((c) => c.toJson()).toList(),
    'scramble_items': scrambleItems.map((s) => s.toJson()).toList(),
    'fair_play': fairPlay,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'owner_uid': ownerUid,
  };

  factory GameRoom.fromJson(Map<String, dynamic> j) => GameRoom(
    id: j['id'] as String? ?? '',
    hostProfileId: j['host_profile_id'] as String? ?? '',
    hostName: j['host_name'] as String? ?? '',
    hostUid: j['host_uid'] as String? ?? '',
    hostAvatarIndex: (j['host_avatar_index'] as num?)?.toInt() ?? 0,
    guestProfileId: j['guest_profile_id'] as String?,
    guestName: j['guest_name'] as String?,
    guestAvatarIndex: (j['guest_avatar_index'] as num?)?.toInt(),
    invitedProfileId: j['invited_profile_id'] as String? ?? '',
    mode: MpGameModeX.fromWire(j['mode'] as String?),
    status: GameRoomStatusX.fromWire(j['status'] as String?),
    rounds: (j['rounds'] as num?)?.toInt() ?? 5,
    questions:
        (j['questions'] as List?)
            ?.map(
              (e) => MpQuestion.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    memoryLayout:
        (j['memory_layout'] as List?)
            ?.map(
              (e) =>
                  MemoryCardSpec.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    scrambleItems:
        (j['scramble_items'] as List?)
            ?.map(
              (e) =>
                  MpScrambleItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList() ??
        const [],
    fairPlay: j['fair_play'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(j['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        DateTime.tryParse(j['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    ownerUid: j['owner_uid'] as String? ?? '',
  );

  /// The other party's display name, given my profile id. Falls back to a
  /// generic label so the UI never shows an empty name.
  String opponentNameFor(String myProfileId) {
    if (myProfileId == hostProfileId) {
      return (guestName == null || guestName!.isEmpty) ? 'Friend' : guestName!;
    }
    return hostName.isEmpty ? 'Friend' : hostName;
  }
}

/// Live per-player state inside a room (`game_rooms/{id}/players/{profileId}`).
/// Each device writes only its own doc; both clients watch all of them to show
/// the opponent's live score/progress.
class MpPlayerState {
  final String profileId;
  final String name;
  final int avatarIndex;
  final int score;

  /// 0..total — how far through the match this player is (questions answered
  /// or pairs found). Drives the live progress bar.
  final int progress;
  final bool finished;
  final String ownerUid;
  final DateTime updatedAt;

  const MpPlayerState({
    required this.profileId,
    required this.name,
    required this.avatarIndex,
    required this.score,
    required this.progress,
    required this.finished,
    required this.ownerUid,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'profile_id': profileId,
    'name': name,
    'avatar_index': avatarIndex,
    'score': score,
    'progress': progress,
    'finished': finished,
    'owner_uid': ownerUid,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MpPlayerState.fromJson(Map<String, dynamic> j) => MpPlayerState(
    profileId: j['profile_id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    avatarIndex: (j['avatar_index'] as num?)?.toInt() ?? 0,
    score: (j['score'] as num?)?.toInt() ?? 0,
    progress: (j['progress'] as num?)?.toInt() ?? 0,
    finished: j['finished'] as bool? ?? false,
    ownerUid: j['owner_uid'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(j['updated_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

/// Head-to-head outcome from two scores. Pure + testable.
enum MpOutcome { player1, player2, draw }

MpOutcome computeOutcome(int score1, int score2) {
  if (score1 == score2) return MpOutcome.draw;
  return score1 > score2 ? MpOutcome.player1 : MpOutcome.player2;
}

// ─── Content builders (pure — shared by local + online flows) ───────────

/// Build [rounds] quiz questions from [pool]. Mirrors the question-generation
/// in the legacy same-device quiz, factored out for reuse + testing. Each
/// question asks English→Filipino or Filipino→English with three distractors.
///
/// Requires at least 4 distinct cards in [pool]; the caller guards this.
List<MpQuestion> buildQuizQuestions(
  List<Flashcard> pool,
  int rounds,
  Random rng,
) {
  if (pool.length < 4) return const [];
  final shuffled = [...pool]..shuffle(rng);
  final out = <MpQuestion>[];

  for (var i = 0; i < rounds; i++) {
    final card = shuffled[i % shuffled.length];
    final englishToFilipino = rng.nextBool();

    final wrong = shuffled.where((c) => c.id != card.id).toList()..shuffle(rng);
    final wrongOptions = wrong
        .take(3)
        .map((c) => englishToFilipino ? c.wordFilipino : c.wordEnglish)
        .toList();
    final correct = englishToFilipino ? card.wordFilipino : card.wordEnglish;

    final options = [...wrongOptions, correct]..shuffle(rng);

    out.add(
      MpQuestion(
        prompt: englishToFilipino ? card.wordEnglish : card.wordFilipino,
        promptLabel: englishToFilipino
            ? 'What is this in Filipino?'
            : 'What is this in English?',
        subtitle: card.exampleSentence,
        options: options,
        correctIndex: options.indexOf(correct),
        signCardId: card.id,
      ),
    );
  }
  return out;
}

/// Build a pre-shuffled memory board of [pairs] distinct cards (length
/// == pairs * 2). Both players receive this exact list.
///
/// Requires at least [pairs] distinct cards in [pool]; the caller guards this.
List<MemoryCardSpec> buildMemoryLayout(
  List<Flashcard> pool,
  int pairs,
  Random rng, {
  String Function(String cardId)? emojiFor,
}) {
  if (pool.length < pairs) return const [];
  final picked = ([...pool]..shuffle(rng)).take(pairs);
  final board = <MemoryCardSpec>[];
  for (final c in picked) {
    final spec = MemoryCardSpec(
      cardId: c.id,
      emoji: emojiFor?.call(c.id) ?? '📖',
      label: c.wordEnglish,
    );
    board.add(spec);
    board.add(spec);
  }
  board.shuffle(rng);
  return board;
}

/// Build [rounds] picture-quiz questions: an emoji prompt with four English
/// word options. Reuses the [MpQuestion] shape (and the quiz player UI).
List<MpQuestion> buildPictureQuestions(
  List<Flashcard> pool,
  int rounds,
  Random rng, {
  required String Function(String cardId) emojiFor,
}) {
  if (pool.length < 4) return const [];
  final shuffled = [...pool]..shuffle(rng);
  final out = <MpQuestion>[];

  for (var i = 0; i < rounds; i++) {
    final card = shuffled[i % shuffled.length];
    final wrong = shuffled.where((c) => c.id != card.id).toList()..shuffle(rng);
    final options = [
      ...wrong.take(3).map((c) => c.wordEnglish),
      card.wordEnglish,
    ]..shuffle(rng);

    out.add(
      MpQuestion(
        prompt: emojiFor(card.id),
        promptLabel: 'Which word is this?',
        options: options,
        correctIndex: options.indexOf(card.wordEnglish),
        cardId: card.id,
        signCardId: card.id,
      ),
    );
  }
  return out;
}

/// Build [rounds] true/false statements ("english = filipino?"). Roughly half
/// are true; false ones pair the English word with another card's Filipino
/// word. [yesLabel] / [noLabel] let the caller localise the two options.
List<MpQuestion> buildTrueFalseQuestions(
  List<Flashcard> pool,
  int rounds,
  Random rng, {
  String yesLabel = 'True',
  String noLabel = 'False',
}) {
  if (pool.length < 2) return const [];
  final shuffled = [...pool]..shuffle(rng);
  final out = <MpQuestion>[];

  for (var i = 0; i < rounds; i++) {
    final card = shuffled[i % shuffled.length];
    final makeTrue = rng.nextBool();
    String shownFilipino;
    if (makeTrue) {
      shownFilipino = card.wordFilipino;
    } else {
      final other = shuffled.firstWhere(
        (c) => c.wordFilipino != card.wordFilipino,
        orElse: () => card,
      );
      shownFilipino = other.wordFilipino;
    }
    // If we couldn't find a distinct word, fall back to a true statement so
    // the answer stays consistent with [makeTrue].
    final isTrue = shownFilipino == card.wordFilipino;

    out.add(
      MpQuestion(
        prompt: '${card.wordEnglish} = $shownFilipino?',
        promptLabel: 'True or False?',
        options: [yesLabel, noLabel],
        correctIndex: isTrue ? 0 : 1,
        signCardId: card.id,
      ),
    );
  }
  return out;
}

/// Build up to [count] word-scramble items from single-token Filipino words
/// of a manageable length. Returns fewer (possibly empty) if the pool lacks
/// enough qualifying words — the caller guards the empty case.
List<MpScrambleItem> buildScrambleItems(
  List<Flashcard> pool,
  int count,
  Random rng, {
  required String Function(String cardId) emojiFor,
}) {
  final eligible =
      pool
          .where(
            (c) =>
                !c.wordFilipino.contains(' ') &&
                c.wordFilipino.runes.length >= 3 &&
                c.wordFilipino.runes.length <= 8,
          )
          .toList()
        ..shuffle(rng);

  final out = <MpScrambleItem>[];
  for (final c in eligible.take(count)) {
    final answer = c.wordFilipino;
    final letters = answer.split('');
    // Shuffle until the order differs from the answer (so it isn't already
    // solved). Bounded attempts to avoid an infinite loop on 1-letter cases.
    var attempts = 0;
    do {
      letters.shuffle(rng);
      attempts++;
    } while (letters.join() == answer && attempts < 8);

    out.add(
      MpScrambleItem(
        prompt: c.wordEnglish,
        promptEmoji: emojiFor(c.id),
        answer: answer,
        letters: letters,
        cardId: c.id,
      ),
    );
  }
  return out;
}
