import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import '../support/real_fonts.dart';

/// Every screen, with the store full, across screen sizes, orientations, text
/// sizes, themes and languages. Reports text cut with "…", content off the
/// screen (overflow), errors, and text drawn over other text. A survey: writes
/// a build/matrix file per shard.
const _me = 'sweep-profile';

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

class _Fil extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

/// Whether [ro] is hidden by something above it.
bool _hidden(RenderObject ro) {
  RenderObject? child = ro;
  var parent = ro.parent;
  while (parent != null) {
    if (parent is RenderOffstage && parent.offstage) return true;
    if (parent is RenderOpacity && parent.opacity <= 0.01) return true;
    if (parent is RenderAnimatedOpacity && parent.opacity.value <= 0.01) {
      return true;
    }
    if (parent is RenderIndexedStack) {
      var shown = false;
      parent.visitChildrenForSemantics((c) {
        if (identical(c, child)) shown = true;
      });
      if (!shown) return true;
    }
    child = parent;
    parent = parent.parent;
  }
  return false;
}

/// What of [ro]'s own rect [rect] is left after every clip above it, globally.
Rect _clipped(RenderObject ro, Rect rect) {
  var out = rect;
  RenderObject child = ro;
  var parent = ro.parent;
  while (parent != null) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final global = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
      out = out.intersect(global);
      if (out.isEmpty) return Rect.zero;
    }
    child = parent;
    parent = parent.parent;
  }
  return out;
}

class _Line {
  _Line(this.rect, this.text, this.where, this.floating);
  final Rect rect;
  final String text;
  final String where;

  /// In a floating action button: it is meant to lie over a page that scrolls.
  final bool floating;
}

/// Whether [text] has a word in it. An emoji's or an icon's line box is much
/// bigger than what it draws, and a badge on a picture is meant to be there.
final _hasWord = RegExp(r'[A-Za-z\u00C0-\u024F]{2}');

final _report = <String, Map<String, dynamic>>{};

void main() {
  if (Platform.environment['FLASHLEARN_SURVEY'] != '1') {
    test('a long survey: runs from tool/run_surveys.sh', () {});
    return;
  }
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('matrix_${Platform.environment['MATRIX_SHARD'] ?? 'all'}');
    await seedLongContent(_me);
  });
  tearDownAll(() {
    File('build/matrix_${Platform.environment['MATRIX_SHARD'] ?? 'all'}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_report));
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

  const views = {
    'phoneP': Size(360, 640),
    'phoneL': Size(640, 360),
    'phone20x9': Size(914, 411),
    '7inP': Size(600, 960),
    '7inL': Size(960, 600),
    '10inP': Size(800, 1280),
    '10inL': Size(1280, 800),
  };
  final themes = {
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
    'contrast': () => AppTheme.highContrast,
    'dyslexia': () => AppTheme.dyslexia,
  };
  const scales = [0.85, 1.0, 1.15, 1.3, 1.5];

  // The worst text size in every theme, every text size in the plain theme,
  // and the plain case in English; each on every screen shape.
  final combos = <(String, String, double, String)>{};
  for (final v in views.keys) {
    for (final t in themes.keys) {
      combos.add((v, t, 1.5, 'fil'));
    }
    for (final s in scales) {
      combos.add((v, 'light', s, 'fil'));
    }
    combos.add((v, 'light', 1.5, 'en'));
    combos.add((v, 'light', 1.0, 'en'));
  }

  for (final (view, theme, scale, lang) in combos) {
    final combo = '$view $theme ${scale}x $lang';
    for (final entry in screens.entries) {
      if (entry.key == 'SplashScreen') continue;
      testWidgets('${entry.key} | $combo', (tester) async {
        final (build, role) = entry.value;
        tester.view.physicalSize = views[view]!;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = FlutterError.onError;
        final errors = <String>{};
        FlutterError.onError = (d) {
          final m = d.exceptionAsString();
          if (m.contains('No GoRouter')) return;
          final src = RegExp(r'lib/[\w/.]+\.dart:\d+')
              .firstMatch(d.toString())
              ?.group(0);
          errors.add('${m.split('\n').first} at $src');
        };
        final finished = Completer<void>();
        final cut = <String>{};
        final overlaps = <String>{};

        void read({bool atEnd = true}) {
          final lines = <_Line>[];
          for (final rp in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          )) {
            if (!rp.hasSize || rp.size.isEmpty || !rp.attached) continue;
            if (_hidden(rp)) continue;
            final plain = rp.text.toPlainText(includeSemanticsLabels: false);
            if (plain.trim().isEmpty) continue;
            final creator = rp.debugCreator;
            final where = creator is DebugCreator
                ? appSourceOf(creator.element) ?? '?'
                : '?';
            if (rp.didExceedMaxLines) {
              cut.add(
                '$where | ${plain.length > 50 ? plain.substring(0, 50) : plain}',
              );
            }
            if (!_hasWord.hasMatch(plain)) continue;
            // An opaque layer over the page: what it covers is not on show.
            if (where.contains('tutorial_overlay')) continue;
            final toGlobal = rp.getTransformTo(null);
            final boxes = rp.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: plain.length),
            );
            final own = Offset.zero & rp.size;
            final floating = creator is DebugCreator &&
                creator.element
                        .findAncestorWidgetOfExactType<FloatingActionButton>() !=
                    null;
            for (final b in boxes) {
              // The text's own area: a wrapped line's last space reaches past it.
              final inside = b.toRect().intersect(own);
              if (inside.isEmpty) continue;
              final r = MatrixUtils.transformRect(toGlobal, inside);
              final vis = _clipped(rp, r);
              if (vis.width >= 2 && vis.height >= 2) {
                lines.add(_Line(vis, plain, where, floating));
              }
            }
          }
          for (var i = 0; i < lines.length; i++) {
            for (var j = i + 1; j < lines.length; j++) {
              final a = lines[i], b = lines[j];
              if (a.text == b.text) continue; // A shadow or an outline.
              if ((a.floating || b.floating) && !atEnd) continue;
              final o = a.rect.intersect(b.rect);
              if (o.width >= 5 && o.height >= 5) {
                final ta = a.text.length > 28 ? a.text.substring(0, 28) : a.text;
                final tb = b.text.length > 28 ? b.text.substring(0, 28) : b.text;
                overlaps.add('${a.where} "$ta" over ${b.where} "$tb"');
              }
            }
          }
        }

        runZonedGuarded(() async {
          await tester.pumpWidget(ProviderScope(
            overrides: [
              profileProvider.overrideWith(() => _Profile(role)),
              if (lang == 'fil') settingsProvider.overrideWith(_Fil.new),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: themes[theme]!(),
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: build(),
            ),
          ));
          for (var t = 0; t < 25; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          read(atEnd: find
              .byWidgetPredicate((w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.vertical)
              .evaluate()
              .isEmpty);
          final scrollables = find
              .byWidgetPredicate((w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.vertical)
              .evaluate()
              .toList();
          for (final e in scrollables.take(3)) {
            final state = (e as StatefulElement).state;
            if (state is! ScrollableState) continue;
            final p = state.position;
            if (!p.hasContentDimensions || !p.hasViewportDimension) continue;
            final step = p.viewportDimension * 0.8;
            if (step <= 0) continue;
            for (var i = 1; i <= 20; i++) {
              final target = (step * i).clamp(0.0, p.maxScrollExtent);
              if (!e.mounted) break;
              p.jumpTo(target);
              await tester.pump(const Duration(milliseconds: 200));
              await tester.pump(const Duration(milliseconds: 200));
              read(atEnd: target >= p.maxScrollExtent);
              if (target >= p.maxScrollExtent) break;
            }
          }
          if (cut.isNotEmpty || errors.isNotEmpty || overlaps.isNotEmpty) {
            _report['${entry.key} | $combo'] = {
              'cut': cut.toList(),
              'errors': errors.toList(),
              'overlaps': overlaps.toList(),
            };
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(minutes: 3));
          FlutterError.onError = old;
          finished.complete();
        }, (error, stack) {
          errors.add('ASYNC ${error.toString().split('\n').first}');
        });
        await finished.future;
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }
}
