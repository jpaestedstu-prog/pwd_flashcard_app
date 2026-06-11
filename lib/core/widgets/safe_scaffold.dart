import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../utils/error_handler.dart';
import '../utils/responsive_utils.dart';

/// Drop-in replacement for [Scaffold] that prevents RenderFlex overflows
/// by default:
///
///   * Wraps the body in [SafeArea] (top + bottom).
///   * Clamps body width to [BuildContext.maxContentWidth] so layouts
///     don't stretch awkwardly on landscape tablets.
///   * Applies [BuildContext.pagePadding] as default horizontal padding.
///   * Wraps the body in a [SingleChildScrollView] when [scrollable] is
///     true (the default), so any height growth from accessibility text
///     scaling or keyboard insets stays inside the viewport.
///   * Defaults `resizeToAvoidBottomInset: true` so forms scroll under
///     the keyboard.
///
/// For a non-scrolling body (e.g. a screen that already uses
/// [CustomScrollView] or needs custom layout) pass `scrollable: false`.
class SafeScaffold extends StatelessWidget {
  const SafeScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.scrollable = true,
    this.padding,
    this.maxWidth,
    this.centerContent = true,
    this.resizeToAvoidBottomInset = true,
    this.extendBodyBehindAppBar = false,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;

  /// When `true` (default), wraps [body] in a [SingleChildScrollView].
  final bool scrollable;

  /// Override the horizontal padding. Defaults to
  /// [BuildContext.pagePadding] symmetric.
  final EdgeInsetsGeometry? padding;

  /// Override the max content width. Defaults to
  /// [BuildContext.maxContentWidth].
  final double? maxWidth;

  /// When `true` (default), centers the constrained body horizontally.
  final bool centerContent;

  final bool resizeToAvoidBottomInset;
  final bool extendBodyBehindAppBar;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? context.maxContentWidth;
    final effectivePadding = padding ??
        EdgeInsets.symmetric(horizontal: context.pagePadding);

    Widget content = Padding(
      padding: effectivePadding,
      child: body,
    );

    if (effectiveMaxWidth.isFinite) {
      content = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: content,
      );
      if (centerContent) {
        content = Center(child: content);
      }
    }

    if (scrollable) {
      content = SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: content,
      );
    }

    content = SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      child: content,
    );

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      body: content,
    );
  }
}

/// A [Column] variant that becomes scrollable when its parent's height
/// is bounded and the column's intrinsic height would otherwise overflow.
///
/// Useful when a widget might be embedded in both scrolling and
/// non-scrolling contexts — e.g. a settings card displayed both inside
/// a [SingleChildScrollView] and inside a fixed-height dialog.
class SafeColumn extends StatelessWidget {
  const SafeColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing = 0,
  });

  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  /// Vertical gap inserted between every pair of children.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final spaced = spacing > 0
        ? _interleaveWithGaps(children, spacing)
        : children;

    final column = Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: spaced,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return column;
        }
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(child: column),
          ),
        );
      },
    );
  }

  static List<Widget> _interleaveWithGaps(
    List<Widget> items,
    double gap,
  ) {
    if (items.length <= 1) return items;
    return [
      for (var i = 0; i < items.length; i++) ...[
        items[i],
        if (i != items.length - 1) SizedBox(height: gap),
      ],
    ];
  }
}

/// Debug-only wrapper that catches paint-time overflow errors on its
/// child and reports them through [ErrorHandler.report] without
/// crashing. In release builds it returns the child unchanged.
///
/// Useful around widgets known to be at risk so QA builds surface
/// the regression instead of silently flashing a yellow/black banner.
class OverflowGuard extends StatelessWidget {
  const OverflowGuard({
    super.key,
    required this.child,
    this.label,
  });

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return _OverflowReporter(label: label, child: child);
  }
}

class _OverflowReporter extends SingleChildRenderObjectWidget {
  const _OverflowReporter({
    required Widget child,
    this.label,
  }) : super(child: child);

  final String? label;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOverflowReporter(label: label);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderOverflowReporter renderObject,
  ) {
    renderObject.label = label;
  }
}

class _RenderOverflowReporter extends RenderProxyBox {
  _RenderOverflowReporter({this.label});

  String? label;
  bool _reported = false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child != null) {
      final childSize = child.size;
      final overflowedY = childSize.height - size.height;
      final overflowedX = childSize.width - size.width;
      if ((overflowedX > 0.5 || overflowedY > 0.5) && !_reported) {
        _reported = true;
        ErrorHandler.report(
          'Overflow detected'
          '${label != null ? ' in "$label"' : ''}'
          ' — child ${childSize.width.toStringAsFixed(1)}x'
          '${childSize.height.toStringAsFixed(1)} '
          'exceeds parent ${size.width.toStringAsFixed(1)}x'
          '${size.height.toStringAsFixed(1)}',
          StackTrace.current,
          'OverflowGuard',
        );
      }
    }
    super.paint(context, offset);
  }
}
