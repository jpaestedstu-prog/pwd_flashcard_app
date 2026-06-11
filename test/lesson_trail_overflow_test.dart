import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/learning_path_data.dart';
import 'package:pwdpwdpwd/data/models/learning_path.dart';
import 'package:pwdpwdpwd/features/learning_paths/screens/lesson_trail_screen.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the kid "adventure trail" (Track C).
///
/// [LessonTrail] is the provider-free body of the trail screen, so it can be
/// rendered directly with real seed paths here — no Riverpod/Hive/router. The
/// trail is fixed-geometry inside a scroll view, so it's tested in a scrollable
/// host: we verify it never overflows *horizontally* and throws no layout
/// exception at any tablet size or font scale, with the path in several
/// progress states (fresh, mid-way, fully complete).

LearningPathProgress _progress(LearningPath path, {required int completed}) {
  return LearningPathProgress(
    pathId: path.id,
    startedAt: DateTime(2026),
    completedStepIndices: {for (var i = 0; i < completed; i++) i},
    currentStepIndex: completed,
    completedAt: completed >= path.totalSteps ? DateTime(2026) : null,
  );
}

void main() {
  final path = LearningPathData.allPaths.first;

  Widget trail(LearningPathProgress? progress) => Padding(
        padding: const EdgeInsets.all(16),
        child: LessonTrail(
          path: path,
          progress: progress,
          categoryColor: Colors.teal,
          onStep: (_) {},
        ),
      );

  testWidgets('fresh trail (nothing started) survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => trail(null),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('mid-progress trail survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => trail(_progress(path, completed: 2)),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('fully completed trail survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => trail(_progress(path, completed: path.totalSteps)),
      host: LayoutHost.scrollable,
    );
  });
}
