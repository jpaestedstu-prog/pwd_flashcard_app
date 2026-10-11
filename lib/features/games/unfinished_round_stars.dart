/// Stars for a round that ended before it was done: "Quit to Games", or
/// Beat the Clock running out.
///
/// Scored against the whole round, as every accuracy game already is: 90 %
/// of it earns 3 stars, 70 % 2, 50 % 1. Memory Match, Jigsaw and Drag & Drop
/// rate a *finished* board by other measures (fewest moves, a completion
/// bonus), and the Flashcard Quiz gives a star just for finishing. On an
/// unfinished board those paid full stars for one move and a quit, and the
/// stars, the XP they carry and a 3-star personal best could be farmed by
/// starting and quitting (found on the tablet: Memory Match, one flip, quit,
/// +3 stars).
int unfinishedRoundStars(int done, int total) {
  if (total <= 0 || done <= 0) return 0;
  final share = done / total;
  if (share >= 0.9) return 3;
  if (share >= 0.7) return 2;
  if (share >= 0.5) return 1;
  return 0;
}
