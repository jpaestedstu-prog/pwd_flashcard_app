import 'package:flutter/widgets.dart';

/// Stat tiles side by side, or two above two on a very narrow screen.
///
/// Four tiles share a narrow phone badly: each is about 60 px wide, and a
/// caption such as "Katumpakan" was drawn at 8 px to stay whole. Android's
/// Display Size at Largest makes an ordinary phone this narrow too.
///
/// The [children] are what a [Row] takes, `Expanded` included.
class StatsAcross extends StatelessWidget {
  const StatsAcross({
    super.key,
    required this.children,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });

  final List<Widget> children;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    Widget row(List<Widget> tiles) =>
        Row(crossAxisAlignment: crossAxisAlignment, children: tiles);
    if (children.length != 4 || MediaQuery.sizeOf(context).width >= 350) {
      return row(children);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(children.sublist(0, 2)),
        const SizedBox(height: 12),
        row(children.sublist(2)),
      ],
    );
  }
}
