import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/sign_interpreter/models/sign_interpreter_models.dart';
import 'package:pwdpwdpwd/features/sign_interpreter/widgets/sentence_sign_player.dart';

void main() {
  // Unmatched items exercise the full sequencing path (placeholder cards +
  // timers) without touching the video_player plugin.
  testWidgets('plays placeholder items in order and finishes', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentenceSignPlayer(
              items: const [
                SignPlayItem.unmatched('zebra'),
                SignPlayItem.unmatched('lion'),
              ],
              onFinished: () => finished = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // First word on stage (placeholder card + caption + chip).
    expect(find.text('zebra'), findsWidgets);
    expect(find.text('No sign for this word yet'), findsOneWidget);

    // Placeholder duration elapses → second word.
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('No sign for this word yet'), findsOneWidget);
    expect(finished, isFalse);

    // Second placeholder elapses → finished card + callback.
    await tester.pump(const Duration(milliseconds: 1700));
    expect(finished, isTrue);
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('pause stops auto-advance; resume continues', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentenceSignPlayer(
              items: [
                SignPlayItem.unmatched('zebra'),
                SignPlayItem.unmatched('lion'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump(const Duration(seconds: 3));
    // Still on the first word — the placeholder timer was cancelled.
    expect(find.text('All done!'), findsNothing);
    expect(find.text('zebra'), findsWidgets);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 1700));
    expect(find.text('All done!'), findsOneWidget);
  });

  testWidgets('renders nothing for an empty playlist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SentenceSignPlayer(items: [])),
      ),
    );
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
