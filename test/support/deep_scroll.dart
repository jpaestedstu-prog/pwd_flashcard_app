import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'readability.dart';

/// The text inside [flex], for naming a row that does not fit.
String _texts(RenderObject flex) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(flex);
  return out.join(' | ');
}

/// Rows wider, and columns taller, than their own box: the flex that
/// overflowed, named by the text inside it.
Iterable<String> overflowingRows(WidgetTester tester) sync* {
  final found = <RenderFlex>[];
  void walk(RenderObject o) {
    if (o is RenderFlex && o.hasSize) {
      final across = o.direction == Axis.horizontal;
      var total = 0.0;
      o.visitChildren((c) {
        if (c is RenderBox && c.hasSize) {
          total += across ? c.size.width : c.size.height;
        }
      });
      final room = across ? o.size.width : o.size.height;
      if (total > room + 0.5) found.add(o);
    }
    o.visitChildren(walk);
  }

  for (final view in tester.binding.renderViews) {
    walk(view);
  }
  for (final flex in found) {
    final text = _texts(flex);
    final kind = flex.direction == Axis.horizontal ? 'row' : 'column';
    yield '$kind overflows: '
        '${text.length > 90 ? '${text.substring(0, 90)}…' : text}';
  }
}

/// A screen top to bottom on a phone: renders [build] at [size] and [scale],
/// scrolls its main list to the end a part of a screen at a time, and
/// collects every layout error, row wider than its space and unreadable
/// word ([findReadabilityIssues]) on the way. The device matrices look at
/// the first screenful only; the rows further down were where Settings broke
/// at large text.
Future<List<String>> collectDeepLayoutIssues(
  WidgetTester tester,
  Widget Function() build, {
  List<Override> overrides = const [],
  Size size = const Size(360, 640),
  double scale = 1.0,
  Locale locale = const Locale('en'),
  ThemeData? theme,
  int maxScrolls = 60,
  Duration settle = const Duration(seconds: 1),
}) async {
  tester.view.physicalSize = size * 2.0;
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: build(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  final problems = <String>{};
  void collect() {
    for (Object? e = tester.takeException();
        e != null;
        e = tester.takeException()) {
      problems.add(e.toString().split('\n').first);
    }
    problems.addAll(overflowingRows(tester));
    for (final issue in findReadabilityIssues(tester)) {
      problems.add('$issue');
    }
  }

  collect();
  // Every vertical scrolling area in turn, so content inside an inner one
  // (a grid with its own scroll) is laid out and checked too.
  await scrollEachVertical(tester, maxScrolls: maxScrolls, step: 250,
      onStep: collect);

  const step = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < settle; t += step) {
    await tester.pump(step);
  }
  collect();
  await tester.pumpWidget(const SizedBox.shrink());
  return problems.toList()..sort();
}

/// Scrolls each vertical scrolling area on screen to its end, [step] dp at a
/// time, calling [onStep] after each move. Areas found later (built only once
/// an outer one scrolled them into view) are taken too, up to [maxAreas].
Future<void> scrollEachVertical(
  WidgetTester tester, {
  required int maxScrolls,
  required double step,
  required void Function() onStep,
  int maxAreas = 6,
}) async {
  final done = <ScrollableState>{};
  for (var area = 0; area < maxAreas; area++) {
    final vertical = find.byWidgetPredicate((w) =>
        w is Scrollable &&
        axisDirectionToAxis(w.axisDirection) == Axis.vertical);
    ScrollableState? next;
    final all = vertical.evaluate().toList();
    for (var i = 0; i < all.length; i++) {
      final state = tester.state<ScrollableState>(vertical.at(i));
      if (done.contains(state)) continue;
      if (!state.position.hasContentDimensions ||
          state.position.maxScrollExtent <= 0) {
        done.add(state);
        continue;
      }
      next = state;
      break;
    }
    if (next == null) return;
    done.add(next);
    // Moved by the position, not dragged: a drag starts at the area's
    // centre, and a smaller scrolling box sitting there (Home's hero card)
    // took the gesture, so the page itself never moved.
    for (var i = 0; i < maxScrolls && next.position.extentAfter > 0; i++) {
      final position = next.position;
      position.jumpTo(
        (position.pixels + step).clamp(0.0, position.maxScrollExtent),
      );
      // Rows built as they scroll in and fade in one after another (the
      // survey's: 50 ms more per row) have no semantics while transparent:
      // a second lets them arrive before they are looked at.
      for (var t = 0; t < 4; t++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      onStep();
    }
  }
}
