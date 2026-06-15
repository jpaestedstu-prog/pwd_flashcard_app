import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/pro_surface.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the professional teacher/parent surface kit
/// (see lib/core/widgets/pro_surface.dart). Every component is rendered with
/// deliberately worst-case content (long labels, huge numbers) across
/// [kTabletMatrix] × [kTextScales] and must not overflow.

void _noop() {}

void main() {
  testWidgets('ProStatTile survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const SizedBox(
        width: 200,
        child: ProStatTile(
          icon: Icons.groups_rounded,
          label: 'Students Active This Week',
          value: '1,284,567',
          trend: ProTrend.up,
          delta: '+12.5%',
          caption: 'vs. previous week',
        ),
      ),
    );
  });

  testWidgets('ProStatGrid packs many tiles without horizontal overflow',
      (tester) async {
    final tiles = List.generate(
      6,
      (i) => ProStatTile(
        icon: Icons.insights_rounded,
        label: 'Long Metric Label Number ${i + 1}',
        value: '${(i + 1) * 98765}',
        trend: ProTrend.values[i % ProTrend.values.length],
        delta: '+${i + 1}%',
      ),
    );
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: ProStatGrid(tiles: tiles),
      ),
      // Vertically-growing dashboard content → lives in a scroll view.
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('ProActionTile survives the device matrix', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const SizedBox(
        width: 200,
        child: ProActionTile(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Assign Tasks To The Whole Class',
          caption: 'Pick decks, set a due date, and track completion',
          onTap: _noop,
        ),
      ),
    );
  });

  testWidgets('ProActionGrid (large + compact) packs tiles without overflow',
      (tester) async {
    ProActionTile tile(int i, {bool compact = false}) => ProActionTile(
          compact: compact,
          icon: Icons.dashboard_rounded,
          label: 'A Deliberately Long Action Label Number ${i + 1}',
          caption: compact ? null : 'Supporting caption for tile ${i + 1}',
          onTap: _noop,
        );
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ProActionGrid(tiles: [for (var i = 0; i < 6; i++) tile(i)]),
            const SizedBox(height: 24),
            ProActionGrid(
              compact: true,
              tiles: [for (var i = 0; i < 10; i++) tile(i, compact: true)],
            ),
          ],
        ),
      ),
      // Vertically-growing dashboard content → lives in a scroll view.
      host: LayoutHost.scrollable,
    );
  });

  testWidgets('ProPanel with header + data rows survives the device matrix',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const Padding(
        padding: EdgeInsets.all(16),
        child: ProPanel(
          title: 'Class Performance Summary For The Current Term',
          subtitle: 'Updated moments ago across all enrolled students',
          trailing: Icon(Icons.more_horiz_rounded),
          accent: Colors.indigo,
          child: Column(
            children: [
              ProDataRow(
                label: 'Average words mastered per active student',
                value: '518 / 1,000',
              ),
              ProDataRow(
                label: 'Longest active streak in the class',
                value: '365 days',
              ),
              ProDataRow(
                label: 'Assessments completed this week',
                value: '99,999',
              ),
            ],
          ),
        ),
      ),
      host: LayoutHost.scrollable,
    );
  });
}
