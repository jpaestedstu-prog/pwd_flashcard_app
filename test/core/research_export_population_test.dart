import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/research_export_service.dart';
import 'package:pwdpwdpwd/data/local/hive_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_service.dart';

/// Who ends up in the research dataset, and under what id.
///
/// Three things were wrong with the export, and each lost real study data:
///
///  * **Home respondents were dropped.** It took Students only; Chapter IV
///    names respondents from homes, and a home-group learner is a Child.
///  * **Learners on another tablet were dropped.** It read only this device's
///    profiles, although their pre/post results *are* pulled here by the
///    educator sync.
///  * **Merged exports were wrong.** Ids were positional (S001, S002…), so
///    the teacher's export and a parent's — which the SUS makes necessary —
///    gave different learners the same id.
///
/// Plain `test()` against real Hive: the file builders read the boxes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('research_population');
    Hive.init(tempDir.path);
    for (final name in const [
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
      'classrooms',
      'classroom_members',
      'home_groups',
      'home_group_members',
      'active_time_logs',
    ]) {
      await Hive.openBox(name, compactionStrategy: (_, _) => false);
    }
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  (UserProfile, LearningProgress) pair(
    String id,
    UserRole role, {
    bool guest = false,
  }) => (
    UserProfile(
      id: id,
      name: id,
      role: role,
      createdAt: DateTime(2026),
      disabilityType: DisabilityType.hearing,
      isGuestPlayer: guest,
    ),
    LearningProgress(profileId: id, lastActivityDate: DateTime(2026, 9)),
  );

  AssessmentResult result(String learner, AssessmentType type, int score) =>
      AssessmentResult(
        id: '$learner-${type.name}',
        assessmentId: 'class-pre',
        profileId: learner,
        type: type,
        score: score,
        totalQuestions: 10,
        answers: [
          for (var i = 0; i < 10; i++)
            QuestionAnswer(
              questionId: 'q$i',
              givenAnswer: 'x',
              isCorrect: i < score,
              responseTimeMs: 1000,
            ),
        ],
        completedAt: type == AssessmentType.preTest
            ? DateTime(2026, 9, 2)
            : DateTime(2026, 9, 20),
        durationSeconds: 120,
      );

  // ─── The population ──────────────────────────────────────

  group('who is in the dataset', () {
    test('students and home-group children, nobody else', () {
      final population = ResearchExportService.researchPopulation([
        pair('s1', UserRole.student),
        pair('c1', UserRole.child),
        pair('t1', UserRole.teacher),
        pair('p1', UserRole.parent),
        pair('pl1', UserRole.player),
        pair('g1', UserRole.student, guest: true),
      ]);
      expect(population.map((p) => p.$1.id), ['s1', 'c1']);
    });

    test('a learner on another tablet comes in from the roster', () {
      final population = ResearchExportService.researchPopulation(
        [pair('local-1', UserRole.student)],
        roster: [pair('remote-1', UserRole.child)],
      );
      expect(population.map((p) => p.$1.id), ['local-1', 'remote-1']);
    });

    test('a learner in both keeps the local row, once', () {
      final local = pair('both', UserRole.student);
      final remote = pair('both', UserRole.student);
      final population = ResearchExportService.researchPopulation(
        [local],
        roster: [remote],
      );
      expect(population, hasLength(1));
      expect(identical(population.single.$1, local.$1), isTrue);
    });
  });

  // ─── Who is ticked by default ────────────────────────────

  group('the default participants', () {
    // A shared tablet holds other classes' learners too. The export used to
    // take all of them, indistinguishable once anonymised.
    (UserProfile, LearningProgress) inGroup(
      String id, {
      String? classroomId,
      String? homeGroupId,
    }) => (
      UserProfile(
        id: id,
        name: id,
        role: homeGroupId != null ? UserRole.child : UserRole.student,
        createdAt: DateTime(2026),
        classroomId: classroomId,
        homeGroupId: homeGroupId,
      ),
      LearningProgress(profileId: id, lastActivityDate: DateTime(2026, 9)),
    );

    final population = [
      inGroup('mine-class', classroomId: 'c-mine'),
      inGroup('mine-home', homeGroupId: 'g-mine'),
      inGroup('other-class', classroomId: 'c-other'),
      inGroup('no-group'),
      inGroup('remote-mine', classroomId: 'c-elsewhere'),
    ];

    test("only the educator's own learners are ticked", () {
      expect(
        ResearchExportService.defaultParticipants(
          population,
          rosterIds: {'remote-mine'},
          groupIds: {'c-mine', 'g-mine'},
        ),
        {'mine-class', 'mine-home', 'remote-mine'},
      );
    });

    test('offline, the class on this tablet is still found', () {
      expect(
        ResearchExportService.defaultParticipants(
          population,
          groupIds: {'c-mine'},
        ),
        {'mine-class'},
      );
    });

    test('an educator with no groups ticks nobody', () {
      expect(
        ResearchExportService.defaultParticipants(population),
        isEmpty,
      );
    });
  });

  // ─── The ids ─────────────────────────────────────────────

  group('anonymous ids', () {
    test('the same learner gets the same id every time', () {
      // Every export, from every device — which is what makes merging safe.
      expect(
        ResearchExportService.anonymousId('learner-abc'),
        ResearchExportService.anonymousId('learner-abc'),
      );
    });

    test('different learners get different ids', () {
      final ids = {
        for (var i = 0; i < 500; i++)
          ResearchExportService.anonymousId('learner-$i'),
      };
      expect(ids, hasLength(500));
    });

    test('learners and educators are told apart, and nobody is named', () {
      final learner = ResearchExportService.anonymousId('Maria Santos');
      final educator = ResearchExportService.anonymousId(
        'Maria Santos',
        learner: false,
      );
      expect(learner, startsWith('S-'));
      expect(educator, startsWith('T-'));
      expect(learner, isNot(contains('Maria')));
      expect(learner, matches(RegExp(r'^S-[0-9A-F]{8}$')));
    });
  });

  // ─── What actually lands in the files ────────────────────

  group('the exported files', () {
    test('a home-group child\'s pre/post and gain are exported', () async {
      await AssessmentService.saveResult(
        'c1',
        result('c1', AssessmentType.preTest, 4),
      );
      await AssessmentService.saveResult(
        'c1',
        result('c1', AssessmentType.postTest, 8),
      );

      final files = ResearchExportService.buildFiles(
        ResearchExportService.researchPopulation([pair('c1', UserRole.child)]),
      );
      final id = ResearchExportService.anonymousId('c1');
      final rows = files['assessment_results.csv']!
          .split('\n')
          .where((l) => l.startsWith(id))
          .toList();

      expect(rows, hasLength(2), reason: 'this child used to be dropped');
      expect(
        rows.firstWhere((r) => r.contains('postTest')),
        contains(',40,'),
        reason: 'the post-test row carries the 40-point gain',
      );
    });

    test('a learner on another tablet exports their pulled results', () async {
      // The educator sync files a remote learner's results under their id on
      // this device; there is no local profile row for them at all.
      await AssessmentService.saveResult(
        'remote-1',
        result('remote-1', AssessmentType.preTest, 3),
      );

      final files = ResearchExportService.buildFiles(
        ResearchExportService.researchPopulation(
          const [],
          roster: [pair('remote-1', UserRole.student)],
        ),
      );
      expect(
        files['assessment_results.csv'],
        contains(ResearchExportService.anonymousId('remote-1')),
      );
    });

    test('the overview says which learners are from school and home', () {
      final files = ResearchExportService.buildFiles(
        ResearchExportService.researchPopulation([
          pair('s1', UserRole.student),
          pair('c1', UserRole.child),
        ]),
      );
      final overview = files['students_overview.csv']!.split('\n');
      expect(overview.first, startsWith('student_id,learner_role,'));
      expect(
        overview.firstWhere(
          (l) => l.startsWith(ResearchExportService.anonymousId('c1')),
        ),
        contains(',child,'),
      );
      expect(
        overview.firstWhere(
          (l) => l.startsWith(ResearchExportService.anonymousId('s1')),
        ),
        contains(',student,'),
      );
    });

    test('days_active counts calendar days, not sessions', () async {
      // Found in the dry run's export: a learner created that afternoon had
      // days_active = 5. Session dates are ISO-8601, and the old split on a
      // space kept the whole timestamp, so each session was its own "day".
      // Relative to today: the session log prunes anything over 90 days old.
      final day = DateTime.now().subtract(const Duration(days: 3));
      for (final (i, at) in [
        DateTime(day.year, day.month, day.day, 9),
        DateTime(day.year, day.month, day.day, 11, 30),
        DateTime(day.year, day.month, day.day, 15),
        DateTime(day.year, day.month, day.day + 1, 10),
      ].indexed) {
        await HiveService.addSessionLog('s1', {
          'id': 'session-$i',
          'date': at.toIso8601String(),
          'durationSeconds': 600,
        });
      }

      final files = ResearchExportService.buildFiles(
        ResearchExportService.researchPopulation([
          pair('s1', UserRole.student),
        ]),
      );
      final lines = files['students_overview.csv']!.split('\n');
      final header = lines.first.split(',');
      final row = lines
          .firstWhere(
            (l) => l.startsWith(ResearchExportService.anonymousId('s1')),
          )
          .split(',');
      expect(row[header.indexOf('days_active')], '2');
      expect(row[header.indexOf('study_minutes_total')], '40');
    });

    test('every file is still produced', () {
      final files = ResearchExportService.buildFiles(
        ResearchExportService.researchPopulation([
          pair('s1', UserRole.student),
        ]),
      );
      expect(files.keys, containsAll(const [
        'students_overview.csv',
        'assessment_results.csv',
        'item_responses.csv',
        'sus_survey_results.csv',
        'student_experience.csv',
        'fsl_engagement.csv',
        'summary_stats.json',
      ]));
      expect(files, hasLength(17));
    });
  });
}
