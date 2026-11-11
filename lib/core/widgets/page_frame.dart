import 'package:flutter/material.dart';

/// How wide a screen's content may run on a big screen. Set per route
/// (`AppPageTransitions`); phones are never affected.
enum PageWidth {
  /// The whole window: the tab hubs (they lay out their own grids and gutters,
  /// over a background that fills the window), the camera, the lock screens.
  full(null, null),

  /// Lists, dashboards, games and readers.
  content(1040, 1200),

  /// A column of fields and buttons: a name box 1,300 px wide is not a form
  /// anyone can read across.
  form(640, 720);

  const PageWidth(this.maxWidth, this.minWindow);

  /// How wide the screen's content is laid out when framed.
  final double? maxWidth;

  /// The window width the frame starts at.
  final double? minWindow;
}

/// Lays a whole route out in the column its [PageWidth] allows, centred on a
/// big window, instead of stretching it edge to edge.
///
/// Everything inside is told the column is the window — that is what the app's
/// responsive helpers, grids and app bars ask — so a screen needs no change to
/// lay itself out properly in it. Dialogs and sheets open on the root
/// navigator and are not framed.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.width, required this.child});

  final PageWidth width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxWidth = width.maxWidth;
    final minWindow = width.minWindow;
    if (maxWidth == null || minWindow == null) return child;
    final media = MediaQuery.of(context);
    if (media.size.width < minWindow) return child;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SizedBox(
          width: maxWidth,
          child: MediaQuery(
            data: media.copyWith(size: Size(maxWidth, media.size.height)),
            child: child,
          ),
        ),
      ),
    );
  }
}
