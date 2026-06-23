/// Pure index-wrapping helper for gaze-driven navigation.
///
/// Shared by [GazeGridCursor] (which drives both the bottom-nav D-pad and the
/// Home feature-tile grid) for horizontal/vertical wrapping, and mirrors the AAC
/// board cursor's `wrapBoardIndex`. Kept tiny and Flutter-free so the wrap logic
/// is fully unit-testable.
///
/// Wraps [index] into `0 … count-1`, handling negatives so a left move from the
/// first item lands on the last. Returns 0 for an empty set.
int wrapNavIndex(int index, int count) {
  if (count <= 0) return 0;
  return ((index % count) + count) % count;
}
