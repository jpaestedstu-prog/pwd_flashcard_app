import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/learning_paths/widgets/winding_trail.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the shared [WindingTrail] geometry that
/// powers both the single-path lesson trail and the world-of-regions
/// "Adventure Map" (Track C follow-on).
///
/// [WindingTrail] is public and provider-free, so it's rendered here directly
/// with synthetic nodes covering every [TrailNodeState], deliberately long
/// region labels, and long pill text. It lives in a vertical scroll view, so a
/// scrollable host is used: we verify no horizontal `RenderFlex` overflow or
/// layout exception at any tablet size or font scale.

List<TrailNode> _regions(int count) {
  const states = TrailNodeState.values;
  return [
    for (var i = 0; i < count; i++)
      TrailNode(
        state: states[i % states.length],
        emoji: '🏝️',
        label: 'Region Number ${i + 1} — A Very Long Region Name That Wraps',
        accent: Colors.primaries[i % Colors.primaries.length],
        pillText: switch (states[i % states.length]) {
          TrailNodeState.done => 'DONE',
          TrailNodeState.current => '12/12',
          TrailNodeState.available => 'ENTER',
          TrailNodeState.locked => null,
        },
        onTap: states[i % states.length] == TrailNodeState.locked ? null : () {},
      ),
  ];
}

void main() {
  testWidgets('WindingTrail world map survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: WindingTrail(nodes: _regions(12)),
      ),
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('WindingTrail with a single node survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: WindingTrail(nodes: _regions(1)),
      ),
      host: LayoutHost.scrollable,
    );
  });
}
