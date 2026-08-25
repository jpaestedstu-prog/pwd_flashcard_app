import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long one successful adult check lasts.
///
/// An adult setting up a board goes in and out of the builder several times —
/// add a word, look at it on the board, go back and fix the picture — and
/// re-asking for the PIN every time would train them to pick something short.
const Duration kAdultGateGrace = Duration(minutes: 5);

/// When the adult check for a given profile stops being valid.
///
/// **In memory only, and deliberately so.** Persisting it would mean a child
/// picking the tablet back up after a restart walks straight into the builder;
/// keeping it in the provider container means the grace dies with the app.
///
/// Also deliberately **not** `pinUnlockGraceProvider`: that one is read by
/// `lockStateProvider`, so writing to it here would quietly dismiss a
/// "Time's Up" screen as a side effect of editing a board.
class AdultGateGraceNotifier extends Notifier<Map<String, DateTime>> {
  @override
  Map<String, DateTime> build() => const {};

  /// Clock seam so tests can pin "now".
  DateTime Function() now = DateTime.now;

  bool isGranted(String profileId) {
    final until = state[profileId];
    return until != null && now().isBefore(until);
  }

  void grant(String profileId, {Duration duration = kAdultGateGrace}) {
    state = {...state, profileId: now().add(duration)};
  }

  void revoke(String profileId) {
    state = {
      for (final e in state.entries)
        if (e.key != profileId) e.key: e.value,
    };
  }
}

final adultGateGraceProvider =
    NotifierProvider<AdultGateGraceNotifier, Map<String, DateTime>>(
  AdultGateGraceNotifier.new,
);
