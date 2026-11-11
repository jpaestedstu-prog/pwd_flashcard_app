import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart'
    show AppSettings, UserProfile;
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;

import '../support/all_screens.dart';
import '../support/app_harness.dart';
import '../support/contrast.dart' show appSourceOf;
import 'package:pwdpwdpwd/core/widgets/page_frame.dart';
import 'package:pwdpwdpwd/core/theme/accessible_theme.dart' show luminance;
import '../support/drill_down_screens.dart';
import '../support/long_content.dart';
import '../support/real_fonts.dart';

/// Measures what the other surveys cannot see, on every screen: how each
/// button's label sits in its button, and what a layout does on a big screen.
///
/// Writes build/ui_metrics_(shard).json for tool/ui_metrics_report.py. It
/// reports; it does not pass or fail.
///
///  * label: lines used, how much room it had, how far off centre it sits,
///    the size it is drawn at against the size it was asked for;
///  * rows: buttons side by side at different heights;
///  * stretched: buttons, fields and paragraphs far wider than they should be.
const _me = 'sweep-profile';

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
    id: _me,
    name: longName,
    role: role,
    disabilityType: Platform.environment['UI_DISABILITY'] == 'hearing'
        ? DisabilityType.hearing
        : DisabilityType.visual,
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

bool _hidden(RenderObject ro) {
  RenderObject? child = ro;
  var parent = ro.parent;
  while (parent != null) {
    if (parent is RenderOffstage && parent.offstage) return true;
    if (parent is RenderOpacity && parent.opacity <= 0.01) return true;
    if (parent is RenderAnimatedOpacity && parent.opacity.value <= 0.01) {
      return true;
    }
    child = parent;
    parent = parent.parent;
  }
  return child == null;
}

/// The route width a screen is given in the router (`app_router.dart`).
const _full = {
  'HomeScreen', 'ChildHomeScreen', 'EducatorHomeScreen', 'PlayerHomeScreen',
  'DeckListScreen', 'GameHubScreen', 'StoryListScreen', 'ProgressScreen',
  'GazeControlScreen', 'GazeCalibrationScreen', 'ObjectScanScreen',
  'SignItScreen', 'SettingsScreen', 'TimeUpLockScreen', 'RoutineLockScreen',
};
const _forms = {
  'JoinClassScreen', 'JoinHomeGroupScreen', 'EditProfileScreen',
  'EnhancedCreateFlashcardScreen', 'CreateFlashcardScreen', 'NoteEditorScreen',
  'RecoverProfileScreen', 'ShowRecoveryCodeScreen', 'BackupAccountScreen',
  'BackupRestoreScreen', 'RoleSetupScreen', 'PostJoinSetupScreen',
  'AccessibilitySetupScreen', 'ProfileImportExportScreen',
  'ParentalControlsScreen', 'AlertSettingsScreen', 'ExportReportScreen',
  'ResearchExportScreen', 'GoalsScreen', 'ExperimentSetupScreen',
  'FocusModeScreen', 'AssessmentBuilderScreen', 'AssessmentAssignScreen',
  'QuizBuilderScreen', 'SusSurveyScreen', 'SmileyometerScreen',
  'VoiceGuidedModeScreen', 'GazeSettingsScreen', 'GamepadSettingsScreen',
  'ChildTimeLimitsScreen', 'ChildAlarmsScreen', 'WordOfDayScreen',
  'MoodCheckInScreen',
};

PageWidth _widthFor(String name) {
  final c = name.split(' ').first;
  if (_full.contains(c)) return PageWidth.full;
  if (_forms.contains(c)) return PageWidth.form;
  return PageWidth.content;
}

/// [appSourceOf], naming the caller of FitText and AutoFit, not the helper.
String? _sourceOf(Element e) {
  String? found = appSourceOf(e);
  if (found != null && found.contains('core/widgets/fit_text.dart')) {
    Element? up;
    e.visitAncestorElements((a) {
      final w = a.widget.runtimeType.toString();
      if (w == 'FitText') {
        up = a;
        return false;
      }
      return true;
    });
    if (up != null) {
      up!.visitAncestorElements((a) {
        final s = appSourceOf(a);
        if (s != null && !s.contains('core/widgets/fit_text.dart')) {
          found = s;
          return false;
        }
        return true;
      });
    }
  }
  return found;
}

/// Words, as opposed to an icon's glyph or an emoji.
final _hasWord = RegExp(r'[A-Za-zÀ-ɏ]{2}');

/// What of [ro]'s own rect [rect] is left after every clip above it, globally,
/// and whether a clip that is not a scrolling viewport is what took it.
(Rect, bool) _clippedByBox(RenderObject ro, Rect rect) {
  var out = rect;
  var byBox = false;
  RenderObject child = ro;
  var parent = ro.parent;
  while (parent != null) {
    final clip = parent.describeApproximatePaintClip(child);
    if (clip != null) {
      final global = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
      final next = out.intersect(global);
      final lost = (out.width - next.width) > 1.5 ||
          (out.height - next.height) > 1.5;
      if (lost && parent is! RenderAbstractViewport) byBox = true;
      out = next;
      if (out.isEmpty) return (Rect.zero, byBox);
    }
    child = parent;
    parent = parent.parent;
  }
  return (out, byBox);
}

/// Whether this [widget] is a text button of some kind.
bool _isButton(Widget w) => w is ButtonStyleButton;

final _report = <String, Map<String, dynamic>>{};

void main() {
  final shard = Platform.environment['UI_SHARD'] ?? 'all';
  if (Platform.environment['FLASHLEARN_SURVEY'] != '1') {
    test('a long survey: runs from tool/run_surveys.sh', () {});
    return;
  }
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('ui_$shard');
    await seedLongContent(_me);
    // The real clip list: without it a flashcard has no Show Me button, and
    // the viewer looks roomier than it is.
    await ActionClipService.load();
  });
  tearDownAll(() {
    File(
      'build/ui_metrics_$shard.json',
    ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_report));
  });

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
  };

  const views = {
    'phone320': Size(320, 568),
    'phone360': Size(360, 640),
    'villaon': Size(423, 941),
    'phoneL': Size(800, 360),
    '7inP': Size(600, 960),
    'honorP': Size(686, 1097),
    'honorL': Size(1097, 608),
    '10inL': Size(1280, 800),
    'desktop': Size(1440, 900),
    'desk1920': Size(1920, 1080),
  };
  const scales = [1.0, 1.5];
  const langs = ['fil', 'en'];
  // Light panels left on a dark page, once per screen: one size, one scale.
  final darkThemes = {'dark': () => AppTheme.dark, 'contrast': () => AppTheme.highContrast};

  for (final MapEntry(key: themeName, value: theme) in darkThemes.entries) {
    for (final entry in screens.entries) {
      if (entry.key == 'SplashScreen') continue;
      testWidgets('${entry.key} | panels $themeName', (tester) async {
        final (build, role) = entry.value;
        tester.view.physicalSize = const Size(686, 1097);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = FlutterError.onError;
        FlutterError.onError = (d) {};
        final finished = Completer<void>();
        final panels = <String>{};
        runZonedGuarded(() async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [profileProvider.overrideWith(() => _Profile(role))],
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme(),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: harnessBuilder(),
                home: PageFrame(width: _widthFor(entry.key), child: build()),
              ),
            ),
          );
          for (var t = 0; t < 25; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          for (final box in tester.allRenderObjects
              .whereType<RenderDecoratedBox>()) {
            if (!box.attached || !box.hasSize || _hidden(box)) continue;
            final d = box.decoration;
            if (d is! BoxDecoration || d.color == null || d.color!.a < 0.9) {
              continue;
            }
            if (box.size.width < 90 || box.size.height < 40) continue;
            if (luminance(d.color!) < 0.75) continue;
            final dc = box.debugCreator;
            panels.add(
              '${box.size.width.round()}x${box.size.height.round()} '
              '${dc is DebugCreator ? appSourceOf(dc.element) : "?"}',
            );
          }
          _report['${entry.key} | panels $themeName'] = {
            'labels': <String, dynamic>{},
            'rows': <String>[],
            'stretched': <String>[],
            'tiny': <String>[],
            'clipped': <String>[],
            'panels': panels.toList(),
          };
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(minutes: 3));
          FlutterError.onError = old;
          finished.complete();
        }, (error, stack) {});
        await finished.future;
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }

  for (final view in views.keys) {
    for (final scale in scales) {
      for (final lang in langs) {
        final combo = '$view ${scale}x $lang';
        for (final entry in screens.entries) {
          if (entry.key == 'SplashScreen') continue;
          testWidgets('${entry.key} | $combo', (tester) async {
            final (build, role) = entry.value;
            tester.view.physicalSize = views[view]!;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final old = FlutterError.onError;
            FlutterError.onError = (d) {};
            final finished = Completer<void>();
            final labels = <String, Map<String, dynamic>>{};
            final rows = <String>{};
            final stretched = <String>{};
            final tiny = <String>{};
            final panels = <String>{};
            final clipped = <String>{};
            void readText() {
              for (final rp in tester.allRenderObjects
                  .whereType<RenderParagraph>()) {
                if (!rp.attached || !rp.hasSize || rp.size.isEmpty) continue;
                if (_hidden(rp)) continue;
                final plain = rp.text.toPlainText(
                  includeSemanticsLabels: false,
                );
                if (!_hasWord.hasMatch(plain)) continue;
                final toGlobal = rp.getTransformTo(null);
                final rect = MatrixUtils.transformRect(
                  toGlobal,
                  Offset.zero & rp.size,
                );
                // Off the screen altogether, or scrolled away.
                final screen = Offset.zero & tester.view.physicalSize;
                if (!rect.overlaps(screen)) continue;
                final (vis, byBox) = _clippedByBox(rp, rect);
                if (vis.isEmpty) continue;
                final span = rp.text;
                final size =
                    (span is TextSpan ? span.style?.fontSize : null) ?? 14;
                final squeeze = rect.width / rp.size.width;
                final drawn = size * rp.textScaler.scale(1.0) * squeeze;
                if (drawn >= 11.0 && !byBox) continue;
                final dc = rp.debugCreator;
                final where = dc is DebugCreator
                    ? _sourceOf(dc.element) ?? '?'
                    : '?';
                final short = plain.length > 30
                    ? plain.substring(0, 30)
                    : plain;
                if (drawn < 11.0) {
                  tiny.add('${drawn.toStringAsFixed(1)} $where "$short"');
                }
                if (byBox) {
                  clipped.add('$where "$short"');
                }
              }
            }

            void read() {
              readText();
              for (final e in find
                  .byWidgetPredicate(_isButton)
                  .evaluate()) {
                final ro = e.renderObject;
                if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
                if (_hidden(ro) || ro.size.isEmpty) continue;
                final paragraphs = <RenderParagraph>[];
                void walk(RenderObject r) {
                  if (r is RenderParagraph) {
                    paragraphs.add(r);
                    return;
                  }
                  r.visitChildren(walk);
                }

                walk(ro);
                final words = [
                  for (final r in paragraphs)
                    if (_hasWord.hasMatch(r.text.toPlainText())) r,
                ];
                if (words.length != 1) continue;
                final rp = words.single;
                if (!rp.attached || !rp.hasSize) continue;
                final text = rp.text.toPlainText();
                if (text.trim().isEmpty) continue;
                final creator = rp.debugCreator;
                final where = creator is DebugCreator
                    ? appSourceOf(creator.element) ?? '?'
                    : '?';
                final boxes = rp.getBoxesForSelection(
                  TextSelection(baseOffset: 0, extentOffset: text.length),
                );
                if (boxes.isEmpty) continue;
                final lineTops = <double>{
                  for (final b in boxes) b.top.roundToDouble(),
                };
                var left = double.infinity, right = 0.0;
                for (final b in boxes) {
                  if (b.left < left) left = b.left;
                  if (b.right > right) right = b.right;
                }
                final tl = rp.localToGlobal(Offset(left, 0));
                final tr = rp.localToGlobal(Offset(right, 0));
                final bl = ro.localToGlobal(Offset.zero);
                // The ink of everything the button draws, its icon included:
                // an icon and its label are centred together, so the label
                // alone sits half an icon to one side by design.
                var inkLeft = tl.dx, inkRight = tr.dx;
                for (final other in paragraphs) {
                  if (identical(other, rp) || !other.hasSize) continue;
                  final o = other.localToGlobal(Offset.zero);
                  if (o.dx < inkLeft) inkLeft = o.dx;
                  final r = o.dx + other.size.width;
                  if (r > inkRight) inkRight = r;
                }
                final inkCentre = (inkLeft + inkRight) / 2;
                final boxCentre = bl.dx + ro.size.width / 2;
                final span = rp.text;
                final asked = span is TextSpan
                    ? (span.style?.fontSize ?? 14)
                    : 14.0;
                final scaler = rp.textScaler.scale(1.0);
                final drawn = asked * scaler;
                final old = labels[where];
                final record = <String, dynamic>{
                  'text': text.length > 40 ? text.substring(0, 40) : text,
                  'lines': lineTops.length,
                  'w': ro.size.width.round(),
                  'h': ro.size.height.round(),
                  'side': ((ro.size.width - (right - left)) / 2).round(),
                  'off': (inkCentre - boxCentre).abs().toStringAsFixed(1),
                  'font': drawn.toStringAsFixed(1),
                };
                final oldLines = old?['lines'] as int? ?? -1;
                if (old == null ||
                    (record['lines'] as int) > oldLines ||
                    ((record['lines'] as int) == oldLines &&
                        (record['side'] as int) < (old['side'] as int))) {
                  labels[where] = record;
                }
                if (view != 'phone360' && ro.size.width > 560) {
                  stretched.add('button ${ro.size.width.round()} $where');
                }
              }
              // Buttons in one row at different heights.
              for (final flex in tester.allRenderObjects.whereType<RenderFlex>()) {
                if (!flex.attached || !flex.hasSize || _hidden(flex)) continue;
                if (flex.direction != Axis.horizontal) continue;
                final heights = <int, String>{};
                flex.visitChildren((c) {
                  if (c is! RenderBox || !c.hasSize) return;
                  RenderObject? found = c;
                  // The button under this cell, if the cell holds one.
                  Element? button;
                  void look(RenderObject r) {
                    if (button != null) return;
                    final dc = r.debugCreator;
                    if (dc is DebugCreator && _isButton(dc.element.widget)) {
                      button = dc.element;
                      return;
                    }
                    r.visitChildren(look);
                  }

                  look(found);
                  if (button != null) {
                    final ro = button!.renderObject as RenderBox;
                    if (ro.attached && ro.hasSize) {
                      heights[ro.size.height.round()] =
                          appSourceOf(button!) ?? '?';
                    }
                  }
                });
                if (heights.length > 1) {
                  final hs = heights.keys.toList()..sort();
                  if (hs.last - hs.first >= 6) {
                    rows.add('${hs.join("/")} ${heights.values.first}');
                  }
                }
              }
              if (view != 'phone360') {
                for (final rp in tester.allRenderObjects
                    .whereType<RenderParagraph>()) {
                  if (!rp.attached || !rp.hasSize || _hidden(rp)) continue;
                  final span = rp.text;
                  final plain = span.toPlainText();
                  if (plain.length < 120) continue;
                  final size =
                      (span is TextSpan ? span.style?.fontSize : null) ?? 14;
                  final em = rp.size.width / (size * rp.textScaler.scale(1.0));
                  if (em > 48) {
                    final dc = rp.debugCreator;
                    stretched.add(
                      'paragraph ${em.round()}em '
                      '${dc is DebugCreator ? appSourceOf(dc.element) : "?"}',
                    );
                  }
                }
                for (final e in find.byType(EditableText).evaluate()) {
                  final ro = e.renderObject;
                  if (ro is RenderBox &&
                      ro.attached &&
                      ro.hasSize &&
                      ro.size.width > 640 &&
                      !_hidden(ro)) {
                    stretched.add(
                      'field ${ro.size.width.round()} ${appSourceOf(e)}',
                    );
                  }
                }
              }
            }

            runZonedGuarded(() async {
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    profileProvider.overrideWith(() => _Profile(role)),
                    if (lang == 'fil') settingsProvider.overrideWith(_Fil.new),
                  ],
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: AppTheme.light,
                    locale: Locale(lang),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: harnessBuilder(textScale: scale),
                    home: PageFrame(
                      width: _widthFor(entry.key),
                      child: build(),
                    ),
                  ),
                ),
              );
              for (var t = 0; t < 25; t++) {
                await tester.pump(const Duration(milliseconds: 100));
              }
              read();
              final scrollables = find
                  .byWidgetPredicate(
                    (w) =>
                        w is Scrollable &&
                        axisDirectionToAxis(w.axisDirection) == Axis.vertical,
                  )
                  .evaluate()
                  .toList();
              for (final e in scrollables.take(3)) {
                final state = (e as StatefulElement).state;
                if (state is! ScrollableState) continue;
                final p = state.position;
                if (!p.hasContentDimensions || !p.hasViewportDimension) {
                  continue;
                }
                final step = p.viewportDimension * 0.8;
                if (step <= 0) continue;
                for (var i = 1; i <= 20; i++) {
                  final target = (step * i).clamp(0.0, p.maxScrollExtent);
                  if (!e.mounted) break;
                  p.jumpTo(target);
                  await tester.pump(const Duration(milliseconds: 200));
                  await tester.pump(const Duration(milliseconds: 200));
                  read();
                  if (target >= p.maxScrollExtent) break;
                }
              }
              _report['${entry.key} | $combo'] = {
                'labels': labels,
                'rows': rows.toList(),
                'stretched': stretched.toList(),
                'panels': panels.toList(),
                'tiny': tiny.toList(),
                'clipped': clipped.toList(),
              };
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump(const Duration(minutes: 3));
              FlutterError.onError = old;
              finished.complete();
            }, (error, stack) {});
            await finished.future;
          }, timeout: const Timeout(Duration(minutes: 5)));
        }
      }
    }
  }
}
