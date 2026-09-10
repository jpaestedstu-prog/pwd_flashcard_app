import 'dart:math';

import 'package:flutter/foundation.dart';

/// Seed for the RNGs that choose **what a screen shows** — null in production.
///
/// Screens that pick or shuffle content (which flashcard, which distractors,
/// which order) did so from a bare `Random()`, so every render drew a different
/// set. That is right for a learner and wrong for a test: the screen-matrix
/// suites render each screen at every device size and font scale, and with an
/// unseeded shuffle they sample one random draw per run rather than testing the
/// screen. Coverage became luck — a card whose long word breaks the layout
/// could sit unnoticed for many runs and then fail one, which is exactly what
/// `FlashcardQuizScreen` did on "Wednesday is in the middle of the week."
///
/// Setting this makes those draws repeatable. `Random(null)` is identical to
/// `Random()`, so with the seed unset — always, outside tests — behaviour is
/// bit-for-bit what it was.
///
/// Only for RNGs whose output reaches the layout. Decorative randomness
/// (particle positions, a mascot's idle delay) paints into a `Stack` without
/// changing what has to fit, so it is deliberately left alone.
@visibleForTesting
int? debugContentRandomSeed;

/// The RNG for content selection. Honours [debugContentRandomSeed].
Random contentRandom() => Random(debugContentRandomSeed);
