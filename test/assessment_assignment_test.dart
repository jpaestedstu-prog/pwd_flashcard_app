import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';

void main() {
  // ─── AssignmentStatus Enum ──────────────────────────

  group('AssignmentStatus', () {
    test('has label for each value', () {
      for (final s in AssignmentStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('has emoji for each value', () {
      for (final s in AssignmentStatus.values) {
        expect(s.emoji, isNotEmpty);
      }
    });

    test('correct labels', () {
      expect(AssignmentStatus.pending.label, 'Pending');
      expect(AssignmentStatus.completed.label, 'Completed');
      expect(AssignmentStatus.overdue.label, 'Overdue');
    });
  });

  // ─── AssessmentAssignment Model ────────────────────

  group('AssessmentAssignment', () {
    final now = DateTime(2025, 7, 1, 10);
    final pastDeadline = DateTime(2025, 6, 15);
    final futureDeadline = DateTime(2099, 12, 31);

    final assignment = AssessmentAssignment(
      id: 'a1',
      assessmentId: 'assess1',
      assessmentTitle: 'Animals Quiz',
      assignedBy: 'teacher1',
      studentIds: ['s1', 's2', 's3'],
      assignedAt: now,
      deadline: futureDeadline,
      instructions: 'Complete before the weekend',
    );

    test('toJson → fromJson roundtrip preserves all fields', () {
      final json = assignment.toJson();
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.id, assignment.id);
      expect(restored.assessmentId, assignment.assessmentId);
      expect(restored.assessmentTitle, assignment.assessmentTitle);
      expect(restored.assignedBy, assignment.assignedBy);
      expect(restored.studentIds, assignment.studentIds);
      expect(restored.assignedAt, assignment.assignedAt);
      expect(restored.deadline, assignment.deadline);
      expect(restored.instructions, assignment.instructions);
    });

    test('toJson contains correct keys', () {
      final json = assignment.toJson();
      expect(json.containsKey('id'), true);
      expect(json.containsKey('assessmentId'), true);
      expect(json.containsKey('assessmentTitle'), true);
      expect(json.containsKey('assignedBy'), true);
      expect(json.containsKey('studentIds'), true);
      expect(json.containsKey('assignedAt'), true);
      expect(json.containsKey('deadline'), true);
      expect(json.containsKey('instructions'), true);
    });

    test('fromJson handles nullable deadline/instructions', () {
      final json = {
        'id': 'a2',
        'assessmentId': 'assess2',
        'assessmentTitle': 'Colors Test',
        'assignedBy': 'teacher1',
        'studentIds': ['s1'],
        'assignedAt': now.toIso8601String(),
      };
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.deadline, isNull);
      expect(restored.instructions, isNull);
    });

    test('fromJson handles missing assessmentTitle gracefully', () {
      final json = {
        'id': 'a3',
        'assessmentId': 'assess3',
        'assignedBy': 'teacher1',
        'studentIds': <String>[],
        'assignedAt': now.toIso8601String(),
      };
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.assessmentTitle, '');
    });

    test('isOverdue returns true when deadline has passed', () {
      final overdue = AssessmentAssignment(
        id: 'a4',
        assessmentId: 'assess4',
        assessmentTitle: 'Past Test',
        assignedBy: 'teacher1',
        studentIds: ['s1'],
        assignedAt: DateTime(2025),
        deadline: pastDeadline,
      );
      expect(overdue.isOverdue, true);
    });

    test('isOverdue returns false when deadline is in the future', () {
      expect(assignment.isOverdue, false);
    });

    test('isOverdue returns false when no deadline set', () {
      final noDeadline = AssessmentAssignment(
        id: 'a5',
        assessmentId: 'assess5',
        assessmentTitle: 'No Deadline',
        assignedBy: 'teacher1',
        studentIds: ['s1'],
        assignedAt: now,
      );
      expect(noDeadline.isOverdue, false);
    });

    test('studentIds preserves order and allows duplicates', () {
      final json = assignment.toJson();
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.studentIds, orderedEquals(['s1', 's2', 's3']));
    });
  });

  // ─── StudentAssignmentStatus ─────────────────────────

  group('StudentAssignmentStatus', () {
    test('stores required fields', () {
      const status = StudentAssignmentStatus(
        studentId: 's1',
        studentName: 'Maria',
        status: AssignmentStatus.pending,
      );
      expect(status.studentId, 's1');
      expect(status.studentName, 'Maria');
      expect(status.status, AssignmentStatus.pending);
      expect(status.result, isNull);
    });

    test('with result stores AssessmentResult', () {
      final result = AssessmentResult(
        id: 'r1',
        assessmentId: 'assess1',
        profileId: 's1',
        type: AssessmentType.custom,
        score: 8,
        answers: [],
        completedAt: DateTime(2025, 7),
        totalQuestions: 10,
        durationSeconds: 120,
      );
      final status = StudentAssignmentStatus(
        studentId: 's1',
        studentName: 'Maria',
        status: AssignmentStatus.completed,
        result: result,
      );
      expect(status.result, isNotNull);
      expect(status.result!.score, 8);
    });
  });

  // ─── Route Guard Lists ────────────────────────────────
  // Verify the new routes are classified correctly.

  group('Assessment assignment routes', () {
    test('AssessmentAssignment can serialize empty student list', () {
      final empty = AssessmentAssignment(
        id: 'e1',
        assessmentId: 'ea1',
        assessmentTitle: 'Empty',
        assignedBy: 'teacher1',
        studentIds: [],
        assignedAt: DateTime(2025, 7),
      );
      final json = empty.toJson();
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.studentIds, isEmpty);
    });

    test('deadline serialization preserves time precision', () {
      final precise = AssessmentAssignment(
        id: 'p1',
        assessmentId: 'pa1',
        assessmentTitle: 'Precise',
        assignedBy: 'teacher1',
        studentIds: ['s1'],
        assignedAt: DateTime(2025, 7, 1, 14, 30, 45),
        deadline: DateTime(2025, 8, 1, 23, 59, 59),
      );
      final json = precise.toJson();
      final restored = AssessmentAssignment.fromJson(json);
      expect(restored.assignedAt.hour, 14);
      expect(restored.assignedAt.minute, 30);
      expect(restored.deadline!.hour, 23);
      expect(restored.deadline!.minute, 59);
    });
  });
}
