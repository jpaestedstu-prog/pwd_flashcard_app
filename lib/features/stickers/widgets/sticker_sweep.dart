import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/sticker_provider.dart';

/// Awards any stickers the learner has earned but not yet been given.
///
/// Renders nothing. It exists because sticker unlocks used to be evaluated
/// *only* inside the Sticker Album's `initState` — so a sticker did not
/// really come into existence until the learner happened to open the album,
/// and there was nothing anywhere else in the app that could know one was
/// waiting. That made the badge on the home tile impossible and the
/// celebration always retrospective.
///
/// Deliberately built the same way as `LearnerAssignmentSync`: a leaf widget
/// the home screens mount, doing its work from a real [ConsumerState] rather
/// than from a post-frame callback holding a build-scoped `WidgetRef`.
///
/// The sweep itself is a pure pass over ~24 threshold checks and only writes
/// when something actually crossed one, so it is safe to run on every
/// progress change.
class StickerSweep extends ConsumerStatefulWidget {
  const StickerSweep({super.key});

  @override
  ConsumerState<StickerSweep> createState() => _StickerSweepState();
}

class _StickerSweepState extends ConsumerState<StickerSweep> {
  @override
  void initState() {
    super.initState();
    // After the first frame: reading a provider during initState is not
    // allowed, and the learner may have earned something on their last run.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sweep(ref.read(progressProvider));
    });
  }

  void _sweep(LearningProgress progress) {
    ref.read(stickerProvider.notifier).checkNewStickers(progress);
  }

  @override
  Widget build(BuildContext context) {
    // Catches a sticker earned mid-session — finishing a game and coming back
    // to the home screen updates progress, and the badge appears without a
    // relaunch.
    ref.listen<LearningProgress>(progressProvider, (_, next) => _sweep(next));
    return const SizedBox.shrink();
  }
}
