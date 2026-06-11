import 'package:flutter/material.dart';

import '../utils/responsive_utils.dart';

/// Two-pane (master + detail) layout used on tablets to make better
/// use of landscape width. On phones and small tablets the master is
/// rendered full-width and tapping a row pushes the detail (single
/// pane). Above [breakpoint] the two render side by side.
///
/// Caller owns the selection state — pass [master] a list that calls
/// [onSelect] with the current selection, and pass [detail] a widget
/// that renders that selection.
///
/// Why a generic widget instead of bespoke per-feature: settings, deck
/// list, communication board, and parent dashboard all share the same
/// list-of-things → detail-pane shape. A shared scaffold keeps the
/// breakpoint, divider styling, and selection feedback consistent.
class MasterDetailScaffold extends StatelessWidget {
  /// Minimum width (dp) at which both panes render side by side.
  /// Below this the scaffold collapses to a single pane and the caller
  /// is expected to navigate to a separate detail route on selection.
  final double breakpoint;

  /// Master pane width when split. Picked to match the ~one-third
  /// proportion master-detail layouts read most naturally at.
  final double masterWidth;

  /// Whether the master pane is currently shown. On phones this is
  /// always true; on tablets the caller can hide it (e.g. focus mode).
  final bool showMaster;

  /// Optional AppBar — same shape as `Scaffold.appBar`.
  final PreferredSizeWidget? appBar;

  /// Master pane content (a list of selectable items).
  final Widget master;

  /// Detail pane content. When [hasSelection] is false the caller can
  /// return a placeholder (e.g. "Select an item").
  final Widget detail;

  /// True when a row has been selected. On single-pane mode used to
  /// decide whether to show the detail or just the master.
  final bool hasSelection;

  /// Optional floating action button forwarded to the underlying
  /// Scaffold.
  final Widget? floatingActionButton;

  /// Optional background color (defaults to Scaffold theme).
  final Color? backgroundColor;

  const MasterDetailScaffold({
    super.key,
    required this.master,
    required this.detail,
    this.hasSelection = false,
    this.showMaster = true,
    this.breakpoint = 900,
    this.masterWidth = 340,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
  });

  /// True when the current viewport is wide enough to render the
  /// two-pane layout. Use this to decide whether to push routes
  /// (single-pane) or just update local selection state (two-pane).
  static bool isTwoPane(BuildContext context, {double breakpoint = 900}) {
    return context.screenWidth >= breakpoint;
  }

  @override
  Widget build(BuildContext context) {
    final twoPane = isTwoPane(context, breakpoint: breakpoint);

    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: twoPane
            ? _TwoPaneLayout(
                masterWidth: masterWidth,
                showMaster: showMaster,
                master: master,
                detail: detail,
              )
            : (hasSelection ? detail : master),
      ),
    );
  }
}

class _TwoPaneLayout extends StatelessWidget {
  final double masterWidth;
  final bool showMaster;
  final Widget master;
  final Widget detail;

  const _TwoPaneLayout({
    required this.masterWidth,
    required this.showMaster,
    required this.master,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final divider = VerticalDivider(
      width: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
    );
    return Row(
      children: [
        if (showMaster) ...[
          SizedBox(width: masterWidth, child: master),
          divider,
        ],
        Expanded(child: detail),
      ],
    );
  }
}
