import 'package:flutter/widgets.dart';

/// The widest a single button, or a column of them, is drawn. Wider than this
/// and a button reads as a banner rather than something to press, and the eye
/// has a long way to travel from one end of its label to the other.
const double kMaxButtonWidth = 600;

/// Fills the width it is given, up to [maxWidth], centred.
///
/// On a phone this is exactly the full-width button it wraps; on a tablet held
/// sideways or a computer's browser the button stops at a comfortable width
/// instead of running 1,000 px or more across the page. Put it around the
/// thing that was full width (a `SizedBox(width: double.infinity)`, a button
/// with `minimumSize: Size.fromHeight(…)`, a gaze tile), so a focus ring still
/// hugs the button.
class CappedWidth extends StatelessWidget {
  const CappedWidth({
    super.key,
    required this.child,
    this.maxWidth = kMaxButtonWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}
