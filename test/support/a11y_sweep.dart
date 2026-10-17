import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'deep_scroll.dart' show scrollEachVertical;

/// What a screen reader or a motor-impaired learner meets on a screen, top to
/// bottom: every tappable thing must say what it is (a screen reader reads
/// out its label; without one it says only "button"), and must be at least
/// 48 x 48 dp (Android's minimum for a finger; this app's learners include
/// children with motor impairments).
///
/// The same two checks as Flutter's [labeledTapTargetGuideline] and
/// [androidTapTargetGuideline], made over the whole screen as it scrolls into
/// view. A target cut off at the edge of a scrolling list reports only the
/// part on screen, so each target's size is the LARGEST it showed at any
/// scroll position: one seen whole somewhere is judged by its whole size.
/// Returns one line per problem, naming the target's label or position.
Future<List<String>> collectTapTargetIssues(
  WidgetTester tester,
  Widget Function() build, {
  List<Override> overrides = const [],
  Size size = const Size(360, 640),
  double devicePixelRatio = 3.0,
  int maxScrolls = 40,
  Duration settle = const Duration(seconds: 1),
  double minTarget = 48,
  ThemeData? theme,
}) async {
  final semantics = tester.ensureSemantics();
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: build(),
      ),
    ),
  );
  await tester.pump();
  // Entrance animations first: tiles that scale in (the Talk Board's, the
  // Daily Challenge card) report their size mid-animation otherwise.
  for (var t = 0; t < 25; t++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Largest size (dp) each tap target showed, by its name.
  final largest = <String, Size>{};
  // Unnamed targets by node id (stable while the node lives): their largest
  // size and where they were when first seen.
  final unnamed = <int, (Size, Offset)>{};
  // The widgets that made each unnamed node, for the report.
  final creators = <int, String>{};
  final screen = Offset.zero & size;

  void nameCreators() {
    void walk(RenderObject ro) {
      final node = ro.debugSemantics;
      if (node != null &&
          unnamed.containsKey(node.id) &&
          !creators.containsKey(node.id)) {
        // The text it shows, which names it in the report.
        final texts = <String>[];
        void read(RenderObject o) {
          if (o is RenderParagraph && texts.length < 3) {
            texts.add(o.text.toPlainText().replaceAll('\n', ' '));
          }
          o.visitChildren(read);
        }

        read(ro);
        final chain = ro.debugCreator
            .toString()
            .split('←')
            .map((s) => s.trim().replaceAll(RegExp(r'[-#][0-9a-f]{5}\b'), ''))
            .where((s) => s.isNotEmpty)
            .take(7)
            .join(' ← ');
        creators[node.id] = texts.isEmpty
            ? chain
            : '$chain, showing "${texts.join(' | ')}"';
      }
      ro.visitChildren(walk);
    }

    for (final view in tester.binding.renderViews) {
      walk(view);
    }
  }

  void survey() {
    bool visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final tappable = data.hasAction(SemanticsAction.tap) ||
          data.hasAction(SemanticsAction.longPress);
      // A node merged into its parent (the switch of a SwitchListTile) is
      // not what a screen reader stops on: the merged row is.
      if (tappable &&
          !node.isMergedIntoParent &&
          !data.flagsCollection.isHidden) {
        var rect = node.rect;
        for (SemanticsNode? n = node; n != null; n = n.parent) {
          final t = n.transform;
          if (t != null) rect = MatrixUtils.transformRect(t, rect);
        }
        final dpRect = Rect.fromLTRB(
          rect.left / devicePixelRatio,
          rect.top / devicePixelRatio,
          rect.right / devicePixelRatio,
          rect.bottom / devicePixelRatio,
        );
        final dp = dpRect.size;
        // Built but scrolled out of view (a list's cache): judged when seen.
        final onScreen = dpRect.overlaps(screen);
        if (!dp.isEmpty && onScreen) {
          final name = data.label.trim().isNotEmpty
              ? data.label.trim()
              : data.tooltip.trim();
          // A text field is named by its hint and the heading above it, as
          // Flutter's own labeledTapTargetGuideline accepts; the check is for
          // buttons and the like.
          final isField = data.flagsCollection.isTextField;
          if (name.isEmpty && !isField && data.hint.trim().isEmpty) {
            final was = unnamed[node.id];
            unnamed[node.id] = (
              was == null
                  ? dp
                  : Size(
                      dp.width > was.$1.width ? dp.width : was.$1.width,
                      dp.height > was.$1.height ? dp.height : was.$1.height,
                    ),
              was?.$2 ?? dpRect.center,
            );
          } else {
            final key = name.replaceAll('\n', ' / ');
            final was = largest[key];
            largest[key] = was == null
                ? dp
                : Size(
                    dp.width > was.width ? dp.width : was.width,
                    dp.height > was.height ? dp.height : was.height,
                  );
          }
        }
      }
      node.visitChildren(visit);
      return true;
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    nameCreators();
  }

  survey();
  // Every vertical scrolling area in turn (a page can hold a grid that
  // scrolls on its own, like the Talk Board's): a target only ever seen cut
  // off by an unscrolled area's edge would report its cut-off size.
  await scrollEachVertical(tester, maxScrolls: maxScrolls, step: 200,
      onStep: survey);

  // Let one-shot entrance timers finish, then unmount cleanly.
  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < settle; t += step) {
    await tester.pump(step);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  semantics.dispose();

  final issues = <String>[
    for (final MapEntry(key: id, value: (s, at)) in unnamed.entries)
      'no label: a ${s.width.round()} x ${s.height.round()} dp target, '
          'first seen at (${at.dx.round()}, ${at.dy.round()}), '
          'made by ${creators[id] ?? '?'}',
    for (final MapEntry(key: name, value: s) in largest.entries)
      if (s.width < minTarget - 0.5 || s.height < minTarget - 0.5)
        'under ${minTarget.round()} dp: "$name" '
            '${s.width.toStringAsFixed(0)} x ${s.height.toStringAsFixed(0)}',
  ];
  return issues..sort();
}
