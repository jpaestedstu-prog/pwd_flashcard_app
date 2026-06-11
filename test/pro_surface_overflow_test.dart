import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/pro_surface.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow suite for the professional teacher/parent surface kit
/// (see lib/core/widgets/pro_surface.dart). Every component is rendered with
/// deliberately worst-case content (long labels, huge numbers) across
/// [kTabletMatrix] × [kTextScales] and must not overflow.

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
