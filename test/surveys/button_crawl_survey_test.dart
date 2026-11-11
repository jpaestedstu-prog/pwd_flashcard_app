import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart'
    show AppSettings, UserProfile;
import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_editor_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;

import '../support/all_screens.dart';
import '../support/contrast.dart' show appSourceOf;
import '../support/drill_down_screens.dart';
import '../support/long_content.dart';
import '../screen_reader_sweep_test.dart' show screenReaderFindingsNow;

/// Presses every control on every screen, each from a fresh start, with the
/// store full. What a press reveals is pressed in turn, up to [_maxDepth] levels
/// down: every control in a pop-up that opens, and the controls a tab or a
/// switch brings up. Where there are boxes to type in, all of it again with the
/// boxes filled in. Writes a build/crawl_ file per shard: per screen, each
/// control's name and what the press did: the exceptions and overflows it
/// caused, the routes it asked for, the text it left cut, and whether anything
/// happened. It also notes words in the other language: build/english_ and
/// build/filipino_.
/// CRAWL_SMALL=1: a 360 dp phone at the largest text size, in Filipino.
const _me = 'sweep-profile';
const _maxPerScreen = 70;
const _maxPerPopup = 16;
const _maxRevealed = 16;
const _maxDepth = 3;
const _maxPressesPerScreen = 500;

/// A screen's share of the run, by the wall clock: a roster of thirty names
/// with something behind each of them can take an hour otherwise.
const _maxTimePerScreen = Duration(minutes: 5);
final _small = Platform.environment['CRAWL_SMALL'] == '1';

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
        id: _me,
        name: longName,
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
        classroomId: role == UserRole.student ? 'long-class' : null,
        homeGroupId: role == UserRole.child ? 'long-group' : null,
        section: longSection,
      );
}

final _report = <String, Map<String, dynamic>>{};

class _Fil extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

/// The text cut short with an ellipsis now on the screen, with its source.
List<String> _cutTexts(WidgetTester tester) {
  final out = <String>{};
  for (final rp in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (!rp.hasSize || rp.size.isEmpty || !rp.didExceedMaxLines) continue;
    final plain = rp.text.toPlainText(includeSemanticsLabels: false);
    final creator = rp.debugCreator;
    final where =
        creator is DebugCreator ? appSourceOf(creator.element) ?? '?' : '?';
    out.add('$where | ${plain.length > 50 ? plain.substring(0, 50) : plain}');
  }
  return out.toList();
}

/// Every platform call during a press (speech, haptics, a share sheet): a
/// press may have no effect on the screen and still have done its job.
final _platformCalls = <String>[];

void _listenToPlatform(WidgetTester tester) {
  final m = tester.binding.defaultBinaryMessenger;
  m.setMockMethodCallHandler(const MethodChannel('flutter_tts'), (c) async {
    _platformCalls.add('tts ${c.method}');
    if (c.method == 'isLanguageAvailable') return true;
    if (c.method == 'getLanguages') return ['en-US', 'fil-PH'];
    return 1;
  });
  m.setMockMethodCallHandler(SystemChannels.platform, (c) async {
    _platformCalls.add('platform ${c.method}');
    return null;
  });
  m.setMockMethodCallHandler(SystemChannels.textInput, (c) async {
    _platformCalls.add('text ${c.method}');
    return null;
  });
  for (final name in const [
    'plugins.flutter.io/url_launcher',
    'dev.fluttercommunity.plus/share',
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'plugins.flutter.io/camera',
    'plugins.flutter.io/image_picker',
    'miguelruivo.flutter.plugins.filepicker',
    'net.nfet.printing',
    'flashlearn/audio',
  ]) {
    m.setMockMethodCallHandler(MethodChannel(name), (c) async {
      _platformCalls.add('$name ${c.method}');
      return null;
    });
  }
}

List<SemanticsNode> _nodes(WidgetTester tester) {
  final out = <SemanticsNode>[];
  bool visit(SemanticsNode n) {
    out.add(n);
    n.visitChildren(visit);
    return true;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return out;
}

/// Everyday English words: on a screen in Filipino, a sign of a string that
/// was never translated. Vocabulary (one word, "Apple") does not trip it.
final _englishWords = RegExp(
  r"\b(the|your|you|this|that|with|and|for|are|from|have|has|will|please|tap"
  r"|press|choose|select|delete|save|cancel|added|saved|failed|could|couldn't"
  r"|don't|can't|won't|isn't|yet|there|here|when|where|what|which|who|their"
  r"|they|them|been|being|before|after|into|about)\b",
  caseSensitive: false,
);
final _filipinoWords = RegExp(
  r"\b(ang|mga|ng|para|ito|iyong|kung|hindi|lang|wala|naka|nang|dito|kapag"
  r"|pindutin|pa|na|sa|at|ay)\b",
  caseSensitive: false,
);
final _englishSeen = <String, Set<String>>{};

/// Everything read on the screens, by where it is drawn: tool/survey_report.py
/// weighs each against the words of the two translation files.
final _allSeen = <String, Set<String>>{};

void _noteEnglish(WidgetTester tester) {
  final other = _small ? _englishWords : _filipinoWords;
  for (final rp
      in tester.renderObjectList<RenderParagraph>(find.byType(RichText))) {
    final plain = rp.text.toPlainText(includeSemanticsLabels: false);
    if (plain.trim().isNotEmpty) {
      final creator = rp.debugCreator;
      final where = creator is DebugCreator
          ? appSourceOf(creator.element) ?? '?'
          : '?';
      (_allSeen[where] ??= {})
          .add(plain.length > 200 ? plain.substring(0, 200) : plain);
    }
    if (!other.hasMatch(plain)) continue;
    final creator = rp.debugCreator;
    final where = creator is DebugCreator
        ? appSourceOf(creator.element) ?? '?'
        : '?';
    (_englishSeen[where] ??= {})
        .add(plain.length > 140 ? plain.substring(0, 140) : plain);
  }
  for (final n in _nodes(tester)) {
    final d = n.getSemanticsData();
    for (final s in [d.label, d.hint, d.tooltip, d.value]) {
      if (s.trim().isNotEmpty) {
        (_allSeen['semantics'] ??= {})
            .add(s.length > 200 ? s.substring(0, 200) : s);
      }
      if (s.isEmpty || !other.hasMatch(s)) continue;
      (_englishSeen['semantics'] ??= {})
          .add(s.length > 140 ? s.substring(0, 140) : s);
    }
  }
}

/// Pop-ups (dialogs and sheets) now up: only they have a coloured barrier.
int _popups() => find
    .byWidgetPredicate((w) => w is ModalBarrier && w.color != null)
    .evaluate()
    .length;

/// Something plausible in every box on the screen, the way a person would fill
/// a form in. Set on the box's controller: no keyboard is involved.
void _fillBoxes(WidgetTester tester) {
  for (final box in tester.widgetList<EditableText>(find.byType(EditableText))) {
    if (box.controller.text.isNotEmpty || box.readOnly) continue;
    final kind = box.keyboardType;
    final text = kind == TextInputType.number || kind == TextInputType.phone
        ? '1234'
        : kind == TextInputType.emailAddress
            ? 'sample@example.com'
            : box.obscureText
                ? 'Sample1234'
                : 'Sample';
    box.controller.text = text;
    box.onChanged?.call(text);
  }
}

/// The scrolling part of the top pop-up.
Future<void> _scrollPopup(WidgetTester tester, int steps) async {
  if (steps == 0) return;
  final all = find
      .byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical)
      .evaluate()
      .toList();
  for (final e in all.reversed) {
    final state = (e as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final p = state.position;
    if (!p.hasContentDimensions ||
        !p.hasViewportDimension ||
        p.maxScrollExtent <= 0) {
      continue;
    }
    p.jumpTo((p.viewportDimension * 0.8 * steps).clamp(0.0, p.maxScrollExtent));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    return;
  }
}

/// One press on the way to a state: a control's name, and how far down its page
/// or pop-up it is.
typedef _Step = ({String name, int place, bool inPopup});

/// What a person could press now, by name, inside the window.
List<(String, SemanticsNode)> _pressable(WidgetTester tester, Size window) {
  final out = <(String, SemanticsNode)>[];
  for (final n in _nodes(tester)) {
    final d = n.getSemanticsData();
    if (!d.hasAction(SemanticsAction.tap)) continue;
    if (n.isInvisible || n.isMergedIntoParent) continue;
    // ignore: deprecated_member_use
    if (d.hasFlag(SemanticsFlag.hasEnabledState) &&
        // ignore: deprecated_member_use
        !d.hasFlag(SemanticsFlag.isEnabled)) {
      continue;
    }
    var rect = n.rect;
    var transform = n.transform;
    var parent = n.parent;
    while (parent != null) {
      if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
      transform = parent.transform;
      parent = parent.parent;
    }
    final center = rect.center;
    if (!(Offset.zero & window).contains(center)) continue;
    final name = d.label.isNotEmpty
        ? d.label
        : (d.tooltip.isNotEmpty ? d.tooltip : d.hint);
    out.add((name.replaceAll('\n', ' / '), n));
  }
  return out;
}

/// What is over a control a screen reader can press and a finger cannot reach:
/// a pop-up drawn in the screen's own Stack does not hide what it covers unless
/// it says so (the new sticker's card, on the tablet, 4 Nov). Null when a finger
/// reaches it at any of five points.
String? _coveredBy(WidgetTester tester, SemanticsNode node, Size window) {
  // Scrolled out of its list: a reader brings it back into view by itself.
  // ignore: deprecated_member_use
  if (node.getSemanticsData().hasFlag(SemanticsFlag.isHidden)) return null;
  var rect = node.rect;
  final clip = node.parentPaintClipRect;
  if (clip != null) {
    rect = rect.intersect(clip);
    if (rect.width < 4 || rect.height < 4) return null;
  }
  var transform = node.transform;
  var parent = node.parent;
  while (parent != null) {
    if (transform != null) rect = MatrixUtils.transformRect(transform, rect);
    transform = parent.transform;
    parent = parent.parent;
  }
  final w = rect.width / 4, h = rect.height / 4;
  String? top;
  for (final p in [
    rect.center,
    rect.topLeft.translate(w, h),
    rect.topRight.translate(-w, h),
    rect.bottomLeft.translate(w, -h),
    rect.bottomRight.translate(-w, -h),
  ]) {
    if (!(Offset.zero & window).contains(p)) continue;
    final result = HitTestResult();
    tester.binding.hitTestInView(result, p, tester.view.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderObject && identical(target.debugSemantics, node)) {
        return null;
      }
    }
    final first = result.path.isEmpty ? null : result.path.first.target;
    final creator = first is RenderObject ? first.debugCreator : null;
    top ??= creator is DebugCreator
        ? creator.element.widget.runtimeType.toString()
        : first.runtimeType.toString();
  }
  return top;
}

/// The screen as a reader meets it, to tell whether a press changed anything.
String _snapshot(WidgetTester tester) {
  final parts = <String>[];
  for (final n in _nodes(tester)) {
    if (n.isInvisible) continue;
    final d = n.getSemanticsData();
    // ignore: deprecated_member_use
    parts.add('${d.label}|${d.value}|${d.flags}|${d.actions}');
  }
  parts.sort();
  return parts.join('\n');
}

Future<void> _scrollTo(WidgetTester tester, int steps) async {
  if (steps == 0) return;
  final scrollables = find
      .byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical)
      .evaluate()
      .toList();
  if (scrollables.isEmpty) return;
  final state = (scrollables.first as StatefulElement).state;
  if (state is! ScrollableState) return;
  final p = state.position;
  if (!p.hasContentDimensions || !p.hasViewportDimension) return;
  p.jumpTo((p.viewportDimension * 0.8 * steps).clamp(0.0, p.maxScrollExtent));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  if (Platform.environment['FLASHLEARN_SURVEY'] != '1') {
    test('a long survey: runs from tool/run_surveys.sh', () {});
    return;
  }
  setUp(() async {
    // The deeper presses can delete things: every screen starts from the same
    // full store.
    await openMemoryBoxes('crawl_${Platform.environment['CRAWL_SHARD'] ?? 'all'}');
    await seedLongContent(_me);
  });
  tearDownAll(() async {
    File('build/crawl_${Platform.environment['CRAWL_SHARD'] ?? 'all'}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_report));
    File('build/${_small ? 'english' : 'filipino'}_'
            '${Platform.environment['CRAWL_SHARD'] ?? 'all'}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      for (final e in _englishSeen.entries) e.key: e.value.toList(),
    }));
    File('build/${_small ? 'seen_fil' : 'seen_en'}_'
            '${Platform.environment['CRAWL_SHARD'] ?? 'all'}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
      for (final e in _allSeen.entries) e.key: e.value.toList(),
    }));
  });

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
    'ChildAlarmsScreen': (
      () => const ChildAlarmsScreen(childProfileId: 'long-1'),
      UserRole.teacher
    ),
    'RoutineEditorScreen': (
      () => const RoutineEditorScreen(childProfileId: 'long-1'),
      UserRole.teacher
    ),
    'EducatorDashboardScreen (teacher)': (
      () => const EducatorDashboardScreen(audience: EducatorAudience.teacher),
      UserRole.teacher
    ),
    'EducatorDashboardScreen (parent)': (
      () => const EducatorDashboardScreen(audience: EducatorAudience.parent),
      UserRole.parent
    ),
    'MessagingScreen (teacher)': (
      kAllScreens['MessagingScreen']!.$1,
      UserRole.teacher
    ),
    'HomeScreen (child)': (kAllScreens['ChildHomeScreen']!.$1, UserRole.child),
  };

  for (final entry in screens.entries) {
    if (entry.key == 'SplashScreen') continue;
    testWidgets('crawl ${entry.key}', (tester) async {
      final (build, role) = entry.value;
      final window = _small ? const Size(360, 640) : const Size(800, 1280);
      tester.view.physicalSize = window;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      _listenToPlatform(tester);

      final routes = <String>[];
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final src = RegExp(r'lib/[\w/.]+\.dart:\d+')
            .firstMatch(d.toString())
            ?.group(0);
        errors.add('${d.exceptionAsString().split('\n').first} at $src');
      };

      Future<void> open() async {
        final router = GoRouter(
          initialLocation: '/__screen',
          routes: [
            GoRoute(path: '/__screen', builder: (_, _) => build()),
          ],
          errorBuilder: (context, state) {
            routes.add(state.uri.toString());
            return Scaffold(body: Text('ROUTE ${state.uri}'));
          },
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpWidget(ProviderScope(
          overrides: [
            profileProvider.overrideWith(() => _Profile(role)),
            if (_small) settingsProvider.overrideWith(_Fil.new),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            locale: Locale(_small ? 'fil' : 'en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(_small ? 1.5 : 1.0),
              ),
              child: child!,
            ),
          ),
        ));
        for (var t = 0; t < 12; t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      // An error nobody catches in a press's own async work (a save, a sound)
      // is a finding, not the end of the crawl: the test binding would stop
      // the test there.
      final finished = Completer<void>();
      runZonedGuarded(() async {
      // What there is to press, at each place on the page.
      await open();
      final targets = <String, int>{};
      var steps = 0;
      Future<void> gather() async {
        _noteEnglish(tester);
        for (final (name, _) in _pressable(tester, window)) {
          targets.putIfAbsent(name, () => steps);
        }
      }

      await gather();
      for (steps = 1; steps <= 12; steps++) {
        await _scrollTo(tester, steps);
        await gather();
      }

      final presses = <Map<String, dynamic>>[];

      SemanticsNode? nodeNamed(String name) => _pressable(tester, window)
          .where((p) => p.$1 == name)
          .map((p) => p.$2)
          .firstOrNull;

      Set<String> names() => _pressable(tester, window).map((p) => p.$1).toSet();

      Future<void> settle() async {
        for (var t = 0; t < 8; t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Real time, for what waits on assets or files, then its answer.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)),
        );
        for (var t = 0; t < 8; t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      void press(SemanticsNode node) {
        _platformCalls.clear();
        node.owner!.performAction(node.id, SemanticsAction.tap);
      }

      var before = '';
      var namesBefore = <String>{};
      var popupsBefore = 0;

      // From a fresh start, press by press to the end of [path]. False when a
      // step is no longer there.
      Future<bool> walk(List<_Step> path, {required bool filled}) async {
        await open();
        for (var i = 0; i < path.length; i++) {
          final step = path[i];
          if (filled && !step.inPopup) {
            for (var s = 0; s <= step.place; s++) {
              await _scrollTo(tester, s);
              _fillBoxes(tester);
              await tester.pump(const Duration(milliseconds: 100));
            }
          } else if (step.inPopup) {
            await _scrollPopup(tester, step.place);
          } else {
            await _scrollTo(tester, step.place);
          }
          var node = nodeNamed(step.name);
          for (var s = 0; s <= 12 && node == null; s++) {
            if (step.inPopup) {
              await _scrollPopup(tester, s);
            } else {
              await _scrollTo(tester, s);
            }
            node = nodeNamed(step.name);
          }
          if (node == null) return false;
          if (i == path.length - 1) {
            before = _snapshot(tester);
            namesBefore = names();
            popupsBefore = _popups();
            errors.clear();
            routes.clear();
          }
          press(node);
          await settle();
          if (filled) {
            _fillBoxes(tester);
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        return true;
      }

      Map<String, dynamic> result(String name) {
        final exception = tester.takeException();
        _noteEnglish(tester);
        final after = _snapshot(tester);
        final problems = [
          ...errors.where((e) => !e.contains('MissingPluginException')),
          if (exception != null &&
              !exception.toString().contains('MissingPluginException'))
            exception.toString().split('\n').first,
        ];
        return {
          'name': name,
          'changed': after != before,
          'routes': routes.toList(),
          'platform': _platformCalls.toSet().toList(),
          'cut': _cutTexts(tester),
          if (problems.isNotEmpty) 'problems': problems.toSet().toList(),
        };
      }

      // Pressed so far on this screen, outside pop-ups: what a tab or a switch
      // reveals is only new if it has not been pressed already.
      final pressed = {...targets.keys};
      var hasBoxes = false;
      final spent = Stopwatch()..start();
      // Each target's largest size at any place it was seen: one cut off at
      // the edge of a list reports only the part on screen.
      final targetSizes = <String, double>{};
      // Each finding, with the presses that first led to it.
      final readerFindings = <String, String>{};
      final coveredFindings = <String, String>{};

      void noteA11y(String path) {
        // A pop-up's barrier is Flutter's own, with no role on any screen.
        for (final f in screenReaderFindingsNow(tester).where(
            (f) => !(f.startsWith('no role') && f.contains('ModalBarrier')))) {
          readerFindings.putIfAbsent(f, () => path);
        }
        for (final (name, node) in _pressable(tester, window)) {
          // Cut off by its list or its pop-up: the part showing is not its size.
          final clip = node.parentPaintClipRect;
          final r = node.rect;
          if (clip != null &&
              ((r.top - clip.top).abs() < 0.5 ||
                  (r.bottom - clip.bottom).abs() < 0.5 ||
                  (r.left - clip.left).abs() < 0.5 ||
                  (r.right - clip.right).abs() < 0.5)) {
            continue;
          }
          final size = math.min(r.width, r.height);
          targetSizes[name] = math.max(targetSizes[name] ?? 0, size);
          final over = _coveredBy(tester, node, window);
          if (over != null) {
            coveredFindings.putIfAbsent('$name (under $over)', () => path);
          }
        }
      }

      Future<void> explore(List<_Step> path, {required bool filled}) async {
        if (presses.length >= _maxPressesPerScreen ||
            spent.elapsed > _maxTimePerScreen) {
          return;
        }
        final label = [
          if (filled) '[filled]',
          ...path.map((p) => p.name),
        ].join(' >> ');
        if (!await walk(path, filled: filled)) {
          presses.add({'name': label, 'result': 'not found again'});
          return;
        }
        hasBoxes = hasBoxes || find.byType(EditableText).evaluate().isNotEmpty;
        presses.add(result(label));
        noteA11y(label);
        if (path.length >= _maxDepth || routes.isNotEmpty) return;

        final popupsNow = _popups();
        if (popupsNow > popupsBefore) {
          // A new pop-up: everything in it, scrolled through.
          final inner = <String, int>{};
          for (var s = 0; s <= 6; s++) {
            await _scrollPopup(tester, s);
            for (final name in names()) {
              inner.putIfAbsent(name, () => s);
            }
          }
          final boxes = find.byType(EditableText).evaluate().isNotEmpty;
          for (final f in {filled, if (boxes) true}) {
            for (final e in inner.entries.take(_maxPerPopup)) {
              await explore([
                ...path,
                (name: e.key, place: e.value, inPopup: true),
              ], filled: f);
            }
          }
        } else if (popupsNow == popupsBefore) {
          // The same page or pop-up, with new things on it: a tab, a switch.
          final revealed = names()
              .difference(namesBefore)
              .where((n) => popupsNow > 0 || !pressed.contains(n))
              .take(_maxRevealed)
              .toList();
          pressed.addAll(revealed);
          for (final name in revealed) {
            await explore([
              ...path,
              (name: name, place: 0, inPopup: popupsNow > 0),
            ], filled: filled);
          }
        }
      }

      for (final target in targets.entries.take(_maxPerScreen)) {
        await explore(
          [(name: target.key, place: target.value, inPopup: false)],
          filled: false,
        );
      }
      if (hasBoxes) {
        for (final target in targets.entries.take(_maxPerScreen)) {
          await explore(
            [(name: target.key, place: target.value, inPopup: false)],
            filled: true,
          );
        }
      }
      _report[entry.key] = {
        'targets': targets.length,
        'presses': presses,
        'reader': [
          for (final e in readerFindings.entries) '${e.key}  <<< ${e.value}',
        ],
        'small': [
          for (final e in targetSizes.entries)
            if (e.value < 47.5) '${e.value.round()} dp: ${e.key}',
        ],
        'covered': [
          for (final e in coveredFindings.entries) '${e.key}  <<< ${e.value}',
        ],
      };
      await tester.pumpWidget(const SizedBox.shrink());
      // Long enough for what a press left running (a note's 20 s, a toast).
      await tester.pump(const Duration(minutes: 3));
      // Back before the binding checks the test: it needs its own handler.
      FlutterError.onError = old;
      semantics.dispose();
      finished.complete();
      }, (error, stack) {
        final src = RegExp(r'lib/[\w/.]+\.dart:\d+')
            .firstMatch(stack.toString())
            ?.group(0);
        errors.add('ASYNC ${error.toString().split('\n').first} at $src');
      });
      await finished.future;
    }, timeout: const Timeout(Duration(minutes: 45)));
  }
}
