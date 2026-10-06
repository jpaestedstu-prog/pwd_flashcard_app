import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/home/models/educator_home_tiles.dart';
import 'package:pwdpwdpwd/features/parent/models/educator_audience.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_fil.dart';

/// The teacher's and the parent's home are built from ONE tile list.
///
/// They used to be two hand-written lists and drifted twice: the parent's
/// lost the whole Assessments group, then Worksheets. Now a tile is on both
/// homes unless it is marked for one role with a reason — and every such
/// decision is pinned here, so leaving a tile off a home has to be done on
/// purpose, in two places.
void main() {
  const teacher = EducatorAudience.teacher;
  const parent = EducatorAudience.parent;

  List<String> ids(EducatorAudience a, EducatorTileSection s) =>
      [for (final t in educatorTilesFor(a, s)) t.id];

  test('tile ids are unique', () {
    final all = [for (final t in educatorHomeTiles) t.id];
    expect(all.toSet().length, all.length);
  });

  test('only these tiles are for one role, each with a reason', () {
    final teacherOnly = {
      for (final t in educatorHomeTiles)
        if (t.onlyFor == teacher) t.id,
    };
    final parentOnly = {
      for (final t in educatorHomeTiles)
        if (t.onlyFor == parent) t.id,
    };
    expect(
      teacherOnly,
      {'allLearners', 'analytics', 'classroom', 'experimentSetup'},
      reason: 'a new teacher-only tile is a decision: add it here on purpose',
    );
    expect(parentOnly, {'parentalControls'});
    for (final t in educatorHomeTiles.where((t) => t.onlyFor != null)) {
      expect(t.because, isNotNull, reason: t.id);
      expect(t.because!.trim(), isNotEmpty, reason: t.id);
    }
  });

  test('everything else is on both homes — Worksheets included', () {
    for (final t in educatorHomeTiles.where((t) => t.onlyFor == null)) {
      expect(t.isFor(teacher), isTrue, reason: t.id);
      expect(t.isFor(parent), isTrue, reason: t.id);
    }
    for (final a in EducatorAudience.values) {
      expect(ids(a, EducatorTileSection.content), contains('worksheets'));
    }
  });

  test('each home shows its tiles in the order it always has', () {
    expect(ids(teacher, EducatorTileSection.primary), [
      'allLearners', 'analytics', 'reports', 'classroom', 'cards', 'shareCode',
    ]);
    expect(ids(parent, EducatorTileSection.primary), [
      'reports', 'parentalControls', 'cards', 'shareCode',
    ]);
    for (final a in EducatorAudience.values) {
      expect(ids(a, EducatorTileSection.content), [
        'tvCast', 'worksheets', 'messages', 'notes',
      ]);
      expect(ids(a, EducatorTileSection.assessments), [
        'assessments', 'assignTasks', 'trackProgress', 'classReport',
        'manageGroups',
      ]);
    }
    expect(ids(teacher, EducatorTileSection.research), [
      'experimentSetup', 'susSurvey', 'researchExport',
    ]);
    expect(ids(parent, EducatorTileSection.research), [
      'susSurvey', 'researchExport',
    ]);
  });

  test('a parent manages home groups, a teacher classes — never the other’s',
      () {
    final byId = {for (final t in educatorHomeTiles) t.id: t};
    for (final id in ['shareCode', 'manageGroups']) {
      expect(byId[id]!.route(teacher), '/classroom-manage', reason: id);
      expect(byId[id]!.route(parent), '/home-group-manage', reason: id);
    }
  });

  test('every tile goes to a route the router knows', () {
    final router = File('lib/navigation/app_router.dart').readAsStringSync();
    final paths = RegExp(r"path:\s*'([^']+)'")
        .allMatches(router)
        .map((m) => m.group(1)!)
        .toSet();
    for (final t in educatorHomeTiles) {
      for (final a in EducatorAudience.values.where(t.isFor)) {
        expect(paths, contains(t.route(a)), reason: '${t.id} (${a.name})');
      }
    }
  });

  test('every label and caption is filled in, in English and Filipino', () {
    for (final l10n in [AppLocalizationsEn(), AppLocalizationsFil()]) {
      for (final t in educatorHomeTiles) {
        for (final a in EducatorAudience.values.where(t.isFor)) {
          expect(t.label(l10n, a).trim(), isNotEmpty, reason: t.id);
          if (t.section == EducatorTileSection.primary) {
            expect(t.caption, isNotNull, reason: '${t.id} needs a caption');
            expect(t.caption!(l10n, a).trim(), isNotEmpty, reason: t.id);
          }
        }
      }
    }
  });
}
