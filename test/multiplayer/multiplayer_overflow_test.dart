import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/multiplayer/models/multiplayer_models.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/memory_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/quiz_race_player.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/race_result_view.dart';
import 'package:pwdpwdpwd/features/multiplayer/widgets/scramble_race_player.dart';

import '../support/device_matrix.dart';

/// Overflow matrix for the "Play Together" gameplay surfaces — the real
/// RenderFlex risks (answer grid, memory board, result cards). Each is
/// rendered at every tablet size × orientation × accessibility font scale and
/// asserted to lay out without a layout exception.

List<MpQuestion> _questions() => List.generate(
      6,
      (i) => MpQuestion(
        prompt: 'A fairly long English word number $i',
        promptLabel: 'What is this in Filipino?',
        subtitle: 'An example sentence long enough to test wrapping $i',
        options: [
          'long-option-a-$i',
          'long-option-b-$i',
          'long-option-c-$i',
          'long-option-d-$i',
        ],
        correctIndex: i % 4,
      ),
    );

List<MemoryCardSpec> _layout() => List.generate(
      12,
      (i) => MemoryCardSpec(
        cardId: 'c${i ~/ 2}',
        emoji: '🐶',
        label: 'longish-label-${i ~/ 2}',
      ),
    );

List<MpQuestion> _trueFalse() => List.generate(
      6,
      (i) => MpQuestion(
        prompt: 'long-english-word-$i = long-filipino-word-$i?',
        promptLabel: 'True or False?',
        options: const ['Tama / True', 'Mali / False'],
        correctIndex: i.isEven ? 0 : 1,
      ),
    );

List<MpScrambleItem> _scramble() => List.generate(
      5,
      (i) => MpScrambleItem(
        prompt: 'longish-clue-$i',
        promptEmoji: '🐶',
        answer: 'kahapon$i',
        letters: 'kahapon$i'.split('')..shuffle(),
      ),
    );

void main() {
  testWidgets('QuizRacePlayer never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => QuizRacePlayer(
        questions: _questions(),
        accentColor: Colors.indigo,
        onFinished: (_) {},
      ),
    );
  });

  testWidgets('MemoryRacePlayer never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => MemoryRacePlayer(
        layout: _layout(),
        accentColor: Colors.purple,
        onFinished: (_) {},
      ),
    );
  });

  testWidgets('QuizRacePlayer (true/false, 2 options) never overflows',
      (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => QuizRacePlayer(
        questions: _trueFalse(),
        accentColor: Colors.green,
        onFinished: (_) {},
      ),
    );
  });

  testWidgets('ScrambleRacePlayer never overflows', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => ScrambleRacePlayer(
        items: _scramble(),
        accentColor: Colors.orange,
        onFinished: (_) {},
      ),
    );
  });

  testWidgets('RaceResultView never overflows (win + draw)', (tester) async {
    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const RaceResultView(
        player1Name: 'Maria Bituin',
        player1Score: 5,
        player2Name: 'Juan dela Cruz',
        player2Score: 3,
        mode: MpGameMode.quizRace,
        onHome: _noop,
        onRematch: _noop,
      ),
    );

    await expectNoOverflowAcrossDevices(
      tester,
      (_) => const RaceResultView(
        player1Name: 'Aleksandra',
        player1Score: 4,
        player2Name: 'Bartholomew',
        player2Score: 4,
        mode: MpGameMode.memoryRace,
        onHome: _noop,
      ),
    );
  });
}

void _noop() {}
