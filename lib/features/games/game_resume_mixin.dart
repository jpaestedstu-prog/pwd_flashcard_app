import 'package:flutter/widgets.dart';

import '../../core/services/game_session_service.dart';
import '../../data/models/enums.dart';
import 'game_pause_mixin.dart';

/// Lets a game offer "Continue where you left off".
///
/// The rules about *when* a run is worth remembering live in
/// [GameSessionService]; this mixin is the wiring that every game repeats —
/// reading the snapshot, writing it at the two moments that matter, and
/// clearing it when the run ends. A game supplies only its own state through
/// the getters below, then calls [saveResumePoint] / [clearResumePoint] at its
/// own finish and quit points.
///
/// **Restoring is deliberately not here.** Rebuilding a round from a card is
/// the one part that differs per game — distractor draws, letter banks, puzzle
/// cuts — so each game keeps its own `_restoreSaved()`. What they share is the
/// contract: rebuild from [GameResumeSnapshot.cardIds] in order, and if
/// anything about the deck no longer lines up, fall back to the fresh deal
/// rather than resuming into a half-broken state.
///
/// Not every game can resume. Memory Match and Drag & Drop are single boards
/// rather than a sequence of rounds — there is no "round 3 of 10" to come back
/// to, and a half-revealed board is a worse experience than a fresh one. The
/// two FSL modes resolve their deck from video availability asynchronously, so
/// their deck is not knowable at the moment the snapshot would be read. Those
/// three simply never mix this in, so they never write a snapshot and the hub
/// never offers them one.
mixin GameResumeMixin<T extends StatefulWidget> on GamePauseMixin<T> {
  /// Which game the snapshot belongs to.
  GameType get resumeGameType;

  /// The setup to relaunch with, so resuming skips both pickers.
  GameDifficulty get resumeDifficulty;
  List<FlashcardCategory> get resumeCategories;
  bool get resumeTimedMode => false;

  /// Whose run this is. Null / empty (a guest) disables the whole feature.
  String? get resumeProfileId;

  /// Card ids for the whole run, in the order they were dealt.
  List<String> get resumeDeckIds;

  /// Rounds already answered — also the index of the round to come back to.
  int get resumeIndex;

  /// Correct answers so far.
  int get resumeScore;

  /// Per-card outcomes so far, so the review sheet survives the break.
  Map<String, bool> get resumeResults => const {};

  /// True once the result screen is up: the run is over, so there is nothing
  /// left to come back to.
  bool get resumeFinished;

  /// The unfinished run for this game, or null when there is none to offer.
  GameResumeSnapshot? readResumePoint() => GameSessionService.resumeFor(
    profileId: resumeProfileId,
    gameType: resumeGameType,
  );

  /// Remember where the learner is. Safe to call at any point — the service
  /// drops runs that are not worth offering (nothing answered yet, or already
  /// on the last round).
  void saveResumePoint() {
    final profileId = resumeProfileId;
    if (profileId == null || profileId.isEmpty) return;
    final deck = resumeDeckIds;
    if (deck.isEmpty) return;
    GameSessionService.saveResume(
      GameResumeSnapshot(
        profileId: profileId,
        gameType: resumeGameType,
        difficulty: resumeDifficulty,
        categories: resumeCategories,
        timedMode: resumeTimedMode,
        cardIds: deck,
        roundIndex: resumeIndex,
        score: resumeScore,
        cardResults: Map.of(resumeResults),
        savedAt: DateTime.now(),
      ),
    );
  }

  /// Forget the unfinished run — on finish, on time-up, and on Play Again.
  void clearResumePoint() => GameSessionService.clearResume(
    profileId: resumeProfileId,
    gameType: resumeGameType,
  );

  @override
  void onBackgrounded() {
    // Pressing Home is how a young learner actually leaves a game. Remember
    // the round, but never record a result — that is not finishing.
    if (resumeFinished) return;
    saveResumePoint();
  }
}
