import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_models.dart';
import 'package:pwdpwdpwd/features/mood_tracker/models/mood_presentation.dart';
import 'package:pwdpwdpwd/features/mood_tracker/widgets/mood_picker.dart';

/// The faces, and the optional "Write why you feel this way" field beside
/// them — one widget shared by every question "My Day" asks (the after-step
/// sheet, the day-end sheet, the scheduled check-in pop-up, the routine
/// interstitial) and matching the full Mood Check-In screen.
///
/// Two shapes, and which one a learner meets is not a detail:
///
///  * **No note offered → one tap answers.** For the motor / cognitive /
///    multiple categories the keyboard *is* the barrier, and a face they had
///    to confirm with a second button would make the quick answer slower than
///    the screen it replaced.
///  * **Note offered → a face chooses, Save answers.** The sentence has to be
///    typable after the face is picked, so the answer cannot be sent on the
///    tap that picks it.
Future<List<MoodAnswer>> _pump(
  WidgetTester tester, {
  required bool showNote,
  List<MoodType> choices = MoodPresentation.fullChoices,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final answers = <MoodAnswer>[];
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: SingleChildScrollView(
            child: MoodPicker(
              choices: choices,
              showNote: showNote,
              isFilipino: false,
              onAnswer: answers.add,
            ),
          ),
        ),
      ),
    ),
  );
  return answers;
}

void main() {
  group('without a note field', () {
    testWidgets('one tap on a face is the whole answer', (tester) async {
      final answers = await _pump(tester, showNote: false);

      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();

      expect(answers, hasLength(1));
      expect(answers.single.mood, MoodType.happy);
      expect(answers.single.note, isNull);
      expect(answers.single.hasNote, isFalse);
    });

    testWidgets('no field and no Save button appear', (tester) async {
      await _pump(tester, showNote: false);
      await tester.tap(find.bySemanticsLabel('Sad'));
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.bySemanticsLabel('Save how you feel'), findsNothing);
    });
  });

  group('with a note field', () {
    testWidgets('a face chooses, and the field appears with it', (
      tester,
    ) async {
      final answers = await _pump(tester, showNote: true);

      // Nothing before a face is chosen: an empty note field above six faces
      // reads as the first thing to fill in, and it is not.
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.bySemanticsLabel('Tired'));
      await tester.pump();

      expect(answers, isEmpty, reason: 'choosing is not yet answering');
      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Write why you feel this way (optional)...'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Save how you feel'), findsOneWidget);
    });

    testWidgets('Save carries the face and the sentence', (tester) async {
      final answers = await _pump(tester, showNote: true);

      await tester.tap(find.bySemanticsLabel('Frustrated'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '  the noise was loud  ');
      await tester.tap(find.bySemanticsLabel('Save how you feel'));
      await tester.pump();

      expect(answers, hasLength(1));
      expect(answers.single.mood, MoodType.frustrated);
      // Trimmed: the leading spaces are an artefact of typing, not part of
      // what the learner said.
      expect(answers.single.note, 'the noise was loud');
    });

    testWidgets('an untouched field is no note at all', (tester) async {
      // "Optional" has to mean it. Saving an empty string would put a blank
      // note on the entry and make "has a note" useless to the educator.
      final answers = await _pump(tester, showNote: true);

      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Save how you feel'));
      await tester.pump();

      expect(answers.single.note, isNull);
    });

    testWidgets('whitespace is not a sentence', (tester) async {
      final answers = await _pump(tester, showNote: true);

      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '     ');
      await tester.tap(find.bySemanticsLabel('Save how you feel'));
      await tester.pump();

      expect(answers.single.note, isNull);
    });

    testWidgets('changing the face keeps the sentence already typed', (
      tester,
    ) async {
      // A learner who typed "my head hurts" and then decided on a different
      // face has not withdrawn the sentence.
      final answers = await _pump(tester, showNote: true);

      await tester.tap(find.bySemanticsLabel('Sad'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'my head hurts');
      await tester.tap(find.bySemanticsLabel('Tired'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Save how you feel'));
      await tester.pump();

      expect(answers.single.mood, MoodType.tired);
      expect(answers.single.note, 'my head hurts');
    });

    testWidgets('the note is capped, so it cannot run away', (tester) async {
      await _pump(tester, showNote: true);
      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();

      // The same 200 as the full Mood Check-In screen.
      expect(
        tester.widget<TextField>(find.byType(TextField)).maxLength,
        200,
      );
    });
  });

  group('the faces themselves', () {
    testWidgets('are the learner\'s own set, and say which is chosen', (
      tester,
    ) async {
      await _pump(
        tester,
        showNote: true,
        choices: MoodPresentation.simpleChoices,
      );

      // Three faces offered means three faces on screen — a shortcut that
      // quietly offered a different vocabulary would skew the insights.
      expect(find.bySemanticsLabel('Happy'), findsOneWidget);
      expect(find.bySemanticsLabel('Okay'), findsOneWidget);
      expect(find.bySemanticsLabel('Sad'), findsOneWidget);
      expect(find.bySemanticsLabel('Tired'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();

      final chosen = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == 'Happy')
          .single;
      expect(chosen.properties.selected, isTrue);
    });

    testWidgets('clear the minimum target size at every count', (
      tester,
    ) async {
      for (final choices in [
        MoodPresentation.simpleChoices,
        MoodPresentation.fullChoices,
      ]) {
        await _pump(tester, showNote: false, choices: choices);
        for (final mood in choices) {
          final size = tester.getSize(find.bySemanticsLabel(mood.label));
          expect(
            size.width,
            greaterThanOrEqualTo(44),
            reason: '${mood.label} in a set of ${choices.length}',
          );
          expect(size.height, greaterThanOrEqualTo(44));
        }
      }
    });

    testWidgets('survive the largest font on a small phone', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: MoodPicker(
                  choices: MoodPresentation.fullChoices,
                  showNote: true,
                  isFilipino: false,
                  onAnswer: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Happy'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('the policy that decides the shape', () {
    // Belongs here as well as in the presentation matrix: this is the line
    // between "one tap" and "tap then Save", and it is drawn by disability
    // rather than by the widget's caller.
    const settings = AppSettings();

    test('typing is offered only where it is not the barrier', () {
      for (final type in [
        DisabilityType.motor,
        DisabilityType.cognitive,
        DisabilityType.multiple,
      ]) {
        expect(
          MoodPresentation.forProfile(type, settings).showNote,
          isFalse,
          reason: type.name,
        );
      }
      for (final type in [
        DisabilityType.none,
        DisabilityType.visual,
        DisabilityType.hearing,
      ]) {
        expect(
          MoodPresentation.forProfile(type, settings).showNote,
          isTrue,
          reason: type.name,
        );
      }
    });
  });
}
