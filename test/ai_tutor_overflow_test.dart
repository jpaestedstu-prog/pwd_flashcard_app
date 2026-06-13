import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/ai_tutor/models/tutor_models.dart';
import 'package:pwdpwdpwd/features/ai_tutor/widgets/tutor_chat.dart';
import 'package:pwdpwdpwd/features/ai_tutor/widgets/tutor_persona.dart';

import 'support/device_matrix.dart';

/// Cross-device overflow matrix for the AI Tutor's presentational chat widgets.
/// Each is rendered at every tablet size × orientation × accessibility font
/// scale and asserted to lay out without a RenderFlex / layout exception — the
/// concrete "works on every Android tablet" guarantee.

/// Deliberately long content to stress wrapping at large font scales.
TutorMessage _quizMessage() => TutorMessage(
      id: 'q',
      role: TutorMessageRole.tutor,
      content:
          '❓ Quick Quiz!\n\nWhat is the Filipino word for "transportation" in this sentence?',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.quickQuiz,
        options: [
          'napakahabang pagpipiliang sagot',
          'pangalawang mahabang sagot dito',
          'pangatlong sagot na mahaba rin',
          'pang-apat na sagot na pagpipilian',
        ],
        correctAnswer: 'napakahabang pagpipiliang sagot',
        wordId: 'w_transport',
        categoryLabel: 'Transportation',
      ),
    );

TutorMessage _longTutorMessage() => TutorMessage(
      id: 't',
      role: TutorMessageRole.tutor,
      content:
          '🎯 Today\'s lesson is ready! We\'ll practice three words together: '
          'transportation, environment, and responsibility. Tap below to begin '
          'and you will earn stars for finishing your daily plan!',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.startLesson,
        planWordIds: ['w1', 'w2', 'w3'],
      ),
    );

TutorMessage _studentMessage() => TutorMessage(
      id: 's',
      role: TutorMessageRole.student,
      content:
          'Can you help me understand how transportation words are used in long '
          'example sentences please?',
      timestamp: DateTime.now(),
    );

/// All 12 favorite-topic chips — the widest interactive bubble.
TutorMessage _interestPickerMessage() => TutorMessage(
      id: 'i',
      role: TutorMessageRole.tutor,
      content: '💖 What topic do you love? Pick one — I\'ll use more words '
          'you like in our quizzes and examples!',
      timestamp: DateTime.now(),
      action: TutorAction(
        type: TutorActionType.pickInterests,
        options: FlashcardCategory.values.map((c) => c.name).toList(),
      ),
    );

TutorMessage _practiceMessage() => TutorMessage(
      id: 'p',
      role: TutorMessageRole.tutor,
      content: '📝 I noticed "Transportation" needs some practice. '
          'Want to work on it? Tap below to start!',
      timestamp: DateTime.now(),
      action: const TutorAction(
        type: TutorActionType.practiceRedirect,
        targetRoute: '/guided-practice',
      ),
    );

const _personas = <TutorPersona>[TutorPersona.child, TutorPersona.student];

void main() {
  for (final persona in _personas) {
    final tag = persona.titleEn;

    testWidgets('$tag quiz bubble never overflows', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _quizMessage(),
          persona: persona,
          isFilipino: false,
          onQuizAnswer: (_) {},
          onSpeak: () {},
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag answered (dimmed) quiz bubble never overflows',
        (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _quizMessage(),
          persona: persona,
          isFilipino: true,
          answered: true,
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag start-lesson bubble never overflows', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _longTutorMessage(),
          persona: persona,
          isFilipino: false,
          onActionTap: () {},
          onSpeak: () {},
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag interest-picker bubble never overflows',
        (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _interestPickerMessage(),
          persona: persona,
          isFilipino: true,
          onInterestPick: (_) {},
          onSpeak: () {},
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag practice-redirect bubble never overflows',
        (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _practiceMessage(),
          persona: persona,
          isFilipino: false,
          onActionTap: () {},
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag student bubble never overflows', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorMessageBubble(
          message: _studentMessage(),
          persona: persona,
          isFilipino: false,
        ),
        host: LayoutHost.scrollable,
      );
    });

    testWidgets('$tag typing indicator never overflows', (tester) async {
      await expectNoOverflowAcrossDevices(
        tester,
        (_) => TutorTypingIndicator(persona: persona),
        host: LayoutHost.scrollable,
      );
    });
  }

  testWidgets('stats strip never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const TutorStatsStrip(
        stats: TutorStats(
          questionsAsked: 128,
          quizzesAnswered: 64,
          quizzesCorrect: 59,
          lessonsCompleted: 23,
        ),
        padding: 32,
        isFilipino: true,
      ),
    );
  });

  testWidgets('quick-chip row never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final label in const ['Aralin', 'Quiz', 'Progress', 'Hint', 'Practice', 'Paborito'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TutorQuickChip(label: label, emoji: '🎯', onTap: () {}),
              ),
          ],
        ),
      ),
    );
  });
}
