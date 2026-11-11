import 'dart:ui' show CheckedState, Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/spoken_words.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings;
import 'package:pwdpwdpwd/features/home/screens/home_screen.dart'
    show DailyLoginRewardDialog;
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show SettingsNotifier, settingsProvider;

import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_editor_screen.dart';

import 'support/all_screens.dart';
import 'support/long_content.dart';
import 'support/drill_down_screens.dart';
import 'support/real_fonts.dart';

/// What TalkBack says on every screen the sweeps know, read from the same
/// semantics tree Android is given.
///
/// Found with TalkBack on the tablet (28 Oct): Home's tiles said everything
/// twice ("Games. Play & learn, game controller, Games, Play & learn,
/// button"), every profile opened with its avatar's name ("rabbit face,
/// Visual Impairment Student"), and the Daily Challenge's answers were not
/// announced as buttons. Flutter joins a node's label and the texts under it
/// into one description, line by line, so each is visible here:
///
///  * **twice** — a line the node has already said (it is inside an earlier
///    line of the same description);
///  * **twice in other words** — a line whose numbers and words an earlier
///    line has all said: Memory Match read "Matched 0 of 4 pairs in 0 moves"
///    and then its own "Matched: 0 / 4" (on the tablet, 30 Oct);
///  * **picture first** — a description that opens with an emoji or symbol
///    line, which TalkBack reads by name before the words;
///  * **no role** — something a double tap acts on that says nothing about
///    being pressable (not a button, link, switch, tick box, field or
///    slider);
///  * **no name** — a button with nothing to say;
///  * **twice over two stops** — a stop whose every line the stop before it
///    has just said;
///  * **number alone** — a number with no words ("0", "17.0", "#1", "3d"):
///    the icon that said what it counts is silent, so it means nothing;
///  * **state twice** — a switch or tick box whose label also says "On" or
///    "Off", which the reader already says from its state.
///
/// Every screen here, and every game and drill-down screen, must be clean.
class _Finding {
  _Finding(this.kind, this.text);
  final String kind;
  final String text;
  @override
  String toString() => '$kind: ${text.replaceAll('\n', ' / ')}';
}

final _word = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// "On" or "Off" ("Naka-on", "Naka-off") as a part of a label of its own
/// ("Dark Mode. Off. Easier on the eyes") — not "on" inside a sentence.
final _stateWord = RegExp(
  r'(^|[.,]\s*)(on|off|naka-on|naka-off)\s*([.,]|$)',
  caseSensitive: false,
);

/// The learner's own language set to Filipino, as on the tablet: the screens
/// that choose their words from the profile's setting, not the app's locale,
/// read it from here.
class _FilipinoSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}
final _letter = RegExp(r'\p{L}', unicode: true);
final _digit = RegExp(r'\p{N}', unicode: true);

/// The numbers in [line], in order ("Matched: 0 / 4" → 0, 4).
List<String> _numbersIn(String line) =>
    [for (final m in RegExp(r'\d+').allMatches(line)) m.group(0)!];

/// The words of three letters or more in [line], lower-cased.
Set<String> _wordsIn(String line) => {
      for (final m in RegExp(r'\p{L}{3,}', unicode: true).allMatches(line))
        m.group(0)!.toLowerCase(),
    };

/// Whether every one of [these] is in [those], as often as it is in [these].
bool _allIn(List<String> these, List<String> those) {
  final left = [...those];
  return these.every(left.remove);
}

/// A line as it is heard: case, spacing and closing punctuation aside.
String _norm(String line) => line
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), ' ')
    .replaceAll(RegExp(r'[.:!?,]+$'), '')
    .trim();

/// The widgets above the render object that made each semantics node, as a
/// short chain of type names — to say WHICH widget a finding comes from.
String _madeBy(Map<int, RenderObject> owners, SemanticsNode node) {
  final ro = owners[node.id];
  final creator = ro?.debugCreator;
  if (creator is! DebugCreator) return '?';
  final names = <String>[];
  creator.element.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && !names.contains(name)) names.add(name);
    return names.length < 8;
  });
  return '${creator.element.widget.runtimeType} < ${names.join(' < ')}';
}

Map<int, RenderObject> _owners(WidgetTester tester) {
  final out = <int, RenderObject>{};
  void walk(RenderObject ro) {
    final node = ro.debugSemantics;
    if (node != null) out.putIfAbsent(node.id, () => ro);
    ro.visitChildren(walk);
  }

  for (final view in tester.binding.renderViews) {
    walk(view);
  }
  return out;
}

List<_Finding> _survey(SemanticsNode root, Map<int, RenderObject> owners) {
  final out = <_Finding>[];
  // The stop before this one, in reading order. Said again over two swipes:
  // the same words exactly (two buttons alike cannot be told apart either),
  // or plain words that only repeat a plain stop or picture just before —
  // Home's stats read as a sentence and then as "1, Day Streak, 12...".
  String? previous;
  var previousActs = false;
  var previousImage = false;
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    // As Android is sent it: the app's binding drops the emoji from a label
    // that has words ([SpokenWordsBinding]).
    final label = SpokenWords.withoutPictures(data.label.trim());
    if (label.isNotEmpty && !data.flagsCollection.isHidden) {
      final acts = data.flagsCollection.isButton ||
          data.flagsCollection.isLink ||
          data.flagsCollection.isTextField ||
          data.hasAction(SemanticsAction.tap);
      final heard = [
        for (final l in label.split('\n'))
          if (_letter.hasMatch(l)) _norm(l),
      ];
      final earlier = previous;
      if (earlier != null && heard.isNotEmpty) {
        final before = [for (final l in earlier.split('\n')) _norm(l)];
        final whole = _norm(earlier.replaceAll('\n', ' '));
        final same = heard.every(before.contains);
        // Words, not a letter found inside another word ("A" in "D-pad").
        // A one-word heading after a sentence that happens to use the word
        // ("... or classroom records." then "Classroom") is not said twice.
        final oneWordAfterSentence = heard.length == 1 &&
            !heard.single.contains(' ') &&
            whole.split(' ').length >= 8;
        final repeats = !acts &&
            (!previousActs || previousImage) &&
            !oneWordAfterSentence &&
            heard.every((l) => l.length >= 3 && whole.contains(l));
        if (same || repeats) {
          out.add(_Finding(
            'twice over two stops',
            '$previous ⟶ $label  [${_madeBy(owners, node)}]',
          ));
        }
      }
      previous = label;
      previousActs = acts;
      previousImage = data.flagsCollection.isImage;
    }
    final lines = [
      for (final l in label.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    final acts = data.hasAction(SemanticsAction.tap);
    final role = data.flagsCollection.isButton ||
        data.flagsCollection.isLink ||
        data.flagsCollection.isTextField ||
        data.flagsCollection.isSlider ||
        data.flagsCollection.isChecked != CheckedState.none ||
        data.flagsCollection.isToggled != Tristate.none ||
        data.flagsCollection.isInMutuallyExclusiveGroup ||
        data.flagsCollection.isSelected != Tristate.none ||
        data.hasAction(SemanticsAction.increase);
    if (lines.length > 1) {
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        if (line.length < 2 || !_word.hasMatch(line)) continue;
        final earlier = lines.take(i).map((l) => l.toLowerCase());
        if (earlier.any((e) => e.contains(line))) {
          out.add(_Finding('twice', '$label  [${_madeBy(owners, node)}]'));
          break;
        }
      }
      for (var i = 1; i < lines.length; i++) {
        final numbers = _numbersIn(lines[i]);
        if (numbers.isEmpty) continue;
        final words = _wordsIn(lines[i]);
        // A bare number ("0", "+0%") is a value of its own in a grid of
        // figures, not a sentence said again.
        if (words.isEmpty) continue;
        if (lines.take(i).any((e) =>
            _allIn(numbers, _numbersIn(e)) && _wordsIn(e).containsAll(words))) {
          out.add(_Finding(
            'twice in other words',
            '$label  [${_madeBy(owners, node)}]',
          ));
          break;
        }
      }
    }
    if (lines.isNotEmpty && !_word.hasMatch(lines.first)) {
      out.add(_Finding(
        lines.length > 1 ? 'picture first' : 'picture only',
        '$label  [${_madeBy(owners, node)}]',
      ));
    }
    // "17.0" or "0m" alone: digits, no word to say what they count. A
    // single letter beside a number ("3d") is the same thing abbreviated —
    // but not a controller button's printed name ("L1", "R2"), which is
    // what the learner reads on the pad.
    if (label.isNotEmpty &&
        !RegExp(r'^[LR][12]$').hasMatch(label) &&
        _digit.hasMatch(label) &&
        label.replaceAll(_letter, '').length >= label.length - 1 &&
        !RegExp(r'\p{L}{2}', unicode: true).hasMatch(label)) {
      out.add(_Finding('number alone', '$label  [${_madeBy(owners, node)}]'));
    }
    if (acts && !role && label.isNotEmpty) {
      out.add(_Finding('no role', '$label  [${_madeBy(owners, node)}]'));
    }
    // A switch or tick box is read with its state ("on, Dark Mode,
    // switch"); a label that says it too was heard twice ("on. Dark Mode.
    // On. Easier on the eyes", Settings on the tablet, 29 Oct).
    final hasState = data.flagsCollection.isToggled != Tristate.none ||
        data.flagsCollection.isChecked != CheckedState.none;
    if (hasState && _stateWord.hasMatch(label)) {
      out.add(_Finding('state twice', '$label  [${_madeBy(owners, node)}]'));
    }
    if (data.flagsCollection.isButton &&
        acts &&
        label.isEmpty &&
        data.value.isEmpty &&
        data.tooltip.trim().isEmpty) {
      out.add(_Finding('no name', 'button made by ${_madeBy(owners, node)}'));
    }
    // A node that merges its children is all Android gets: the children are
    // not sent (Flutter's update carries no children for it), so TalkBack
    // never lands on them.
    if (node.mergeAllDescendantsIntoThisNode) return;
    // In the order TalkBack reads them, not the order they paint: an app
    // bar's title is read before the page under it.
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(root);
  return out;
}

void main() => runScreenReaderSweep();

/// What the rules below find on the screen as it is now: for the crawl, which
/// reaches states this sweep's single opening of a screen does not.
List<String> screenReaderFindingsNow(WidgetTester tester) {
  final owners = _owners(tester);
  final findings = <String>[];
  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root == null) continue;
    findings.addAll(_survey(root, owners).map((f) => '$f'));
  }
  return findings;
}

/// The sweep, on an empty store or, with [full], with the store full
/// (`screen_reader_sweep_full_test.dart`). An empty list has no rows to hear:
/// a parent's alarm row said only "switch, on", and the sweep never met it.
void runScreenReaderSweep({bool full = false}) {
  setUpAll(() async {
    await loadRealFonts();
    if (full) {
      await openMemoryBoxes('screen_reader_sweep_full');
      await seedLongContent('sweep-profile');
    } else {
      await openSweepBoxes('screen_reader_sweep');
    }
  });
  if (!full) tearDownAll(closeSweepBoxes);

  final all = <String, List<String>>{};

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    if (full) ...{
      'ChildAlarmsScreen': (
        () => const ChildAlarmsScreen(childProfileId: 'long-1'),
        UserRole.teacher,
      ),
      'RoutineEditorScreen': (
        () => const RoutineEditorScreen(childProfileId: 'long-1'),
        UserRole.teacher,
      ),
      'EducatorDashboardScreen (teacher)': (
        () => const EducatorDashboardScreen(audience: EducatorAudience.teacher),
        UserRole.teacher,
      ),
      'EducatorDashboardScreen (parent)': (
        () => const EducatorDashboardScreen(audience: EducatorAudience.parent),
        UserRole.parent,
      ),
      'MessagingScreen (teacher)': (
        kAllScreens['MessagingScreen']!.$1,
        UserRole.teacher,
      ),
    },
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
    // Pop-ups no screen shows by itself. The Daily Reward greets a learner
    // once a day; on the tablet it said "Collect! 🌟" and "+10" (28 Oct).
    'DailyLoginRewardDialog': (
      () => const Scaffold(
            body: Center(
              child: DailyLoginRewardDialog(starsEarned: 10, streakDay: 3),
            ),
          ),
      UserRole.student,
    ),
  };

  // And in Filipino: a sweep in English alone never heard a Filipino label.
  for (final lang in const ['en', 'fil']) {
  for (final entry in screens.entries) {
    final name = lang == 'en' ? entry.key : '${entry.key} [fil]';
    testWidgets('$name: says each thing once, words first, with a role',
        (tester) async {
      final (build, role) = entry.value;
      final semantics = tester.ensureSemantics();
      const size = Size(686, 1097);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sweepProfileOverride(role),
            if (lang == 'fil')
              settingsProvider.overrideWith(_FilipinoSettings.new),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: build(),
          ),
        ),
      );
      for (var t = 0; t < 25; t++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final findings = <String>{};
      void listen() {
        final owners = _owners(tester);
        for (final view in tester.binding.renderViews) {
          final root = view.owner?.semanticsOwner?.rootSemanticsNode;
          if (root == null) continue;
          for (final f in _survey(root, owners)) {
            findings.add('$f');
          }
        }
      }

      listen();
      // On down the page: what is below it has no node until it is near.
      if (full && entry.key != 'SplashScreen') {
        final scrollables = find
            .byWidgetPredicate((w) =>
                w is Scrollable &&
                axisDirectionToAxis(w.axisDirection) == Axis.vertical)
            .evaluate()
            .toList();
        for (final e in scrollables.take(2)) {
          final state = (e as StatefulElement).state;
          if (state is! ScrollableState) continue;
          final p = state.position;
          if (!p.hasContentDimensions || !p.hasViewportDimension) continue;
          final step = p.viewportDimension * 0.8;
          if (step <= 0) continue;
          for (var i = 1; i <= 12 && e.mounted; i++) {
            final target = (step * i).clamp(0.0, p.maxScrollExtent);
            p.jumpTo(target);
            await tester.pump(const Duration(milliseconds: 200));
            await tester.pump(const Duration(milliseconds: 200));
            listen();
            if (target >= p.maxScrollExtent) break;
          }
        }
      }
      for (final f in findings) {
        debugPrint('SR $name | $f');
      }
      all[name] = findings.toList();
      expect(findings, isEmpty, reason: '$name: what TalkBack would say wrongly');

      // The splash moves on by itself after 3 s, and there is no router
      // here: it is taken away before then ("No GoRouter found", now and
      // then, in Filipino).
      if (entry.key != 'SplashScreen') {
        for (var t = 0; t < 30; t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 6));
      semantics.dispose();
    });
  }
  }

  test('no screen has anything left', () {
    final total = all.values.fold<int>(0, (n, l) => n + l.length);
    debugPrint('SR TOTAL $total findings on ${all.length} screens');
    expect(all, isNotEmpty, reason: 'the screens above ran first');
    expect(total, 0);
  });
}
