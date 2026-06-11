import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/progress_stat_card.dart';
import 'package:pwdpwdpwd/features/progress/widgets/shared/category_progress_row.dart';

/// Regression guard for the Progress screen layout.
///
/// The shared progress widgets live inside a `SliverList`, which gives its
/// children an UNBOUNDED height constraint. A `Row` with
/// `CrossAxisAlignment.stretch` (or any widget that demands a finite height)
/// throws "BoxConstraints forces an infinite height" there and blanks the
/// screen. `dart analyze` can't catch that — these tests render the exact
/// pattern and assert no layout exception is thrown.
Widget _inSliver(List<Widget> children) {
  return MaterialApp(
    home: Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverList(delegate: SliverChildListDelegate(children)),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('top stats row of ProgressStatCards lays out in an unbounded sliver',
      (tester) async {
    await tester.pumpWidget(_inSliver([
      const Row(
        children: [
          Expanded(
            child: ProgressStatCard(
              icon: Icons.local_fire_department_rounded,
              label: 'Streak',
              value: '3',
              suffix: 'days',
              color: Colors.orange,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ProgressStatCard(
              icon: Icons.star_rounded,
              label: 'Stars',
              value: '12',
              color: Colors.amber,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ProgressStatCard(
              icon: Icons.menu_book_rounded,
              label: 'Words',
              value: '5',
              suffix: '/ 100',
              color: Colors.blue,
            ),
          ),
        ],
      ),
    ]));

    expect(tester.takeException(), isNull);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Stars'), findsOneWidget);
    expect(find.text('Words'), findsOneWidget);
  });

  testWidgets('ProgressStatCard row survives a very large text scale',
      (tester) async {
    // NOTE: the text scaler must be applied *inside* MaterialApp — it rebuilds
    // MediaQuery from the test view, so a MediaQuery wrapped around MaterialApp
    // is ignored. We override it via MaterialApp.builder here.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2.0)),
          child: child!,
        ),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildListDelegate(const [
                  Row(
                    children: [
                      Expanded(
                        child: ProgressStatCard(
                          icon: Icons.star_rounded,
                          label: 'Stars Earned This Week',
                          value: '99999',
                          suffix: '/ 99999',
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('CategoryProgressRow lays out with a long label without overflow',
      (tester) async {
    await tester.pumpWidget(_inSliver([
      const CategoryProgressRow(
        icon: Icons.category_rounded,
        label: 'A very long category name that would otherwise overflow',
        color: Colors.green,
        mastered: 3,
        total: 10,
        percent: 0.3,
      ),
    ]));

    expect(tester.takeException(), isNull);
  });
}
