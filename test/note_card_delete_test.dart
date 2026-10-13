import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_colors.dart';
import 'package:pwdpwdpwd/features/parent_teacher_notes/models/parent_teacher_note_models.dart';
import 'package:pwdpwdpwd/features/parent_teacher_notes/screens/parent_teacher_notes_screen.dart';

/// A note's delete control was an 18-pixel icon under a bare tap handler: no
/// label for a screen reader (it was missing from the screen's accessibility
/// tree on the Honor, 13 October 2026), nothing a switch, gaze or keyboard
/// could reach, and a target far under 48 dp.

final _note = ParentTeacherNote(
  id: 'n1',
  authorProfileId: 'teacher',
  authorName: 'Guro',
  studentProfileId: 'kid',
  content: 'Did well today',
  createdAt: DateTime(2026, 10, 13),
);

Widget _card({
  required bool isAuthor,
  VoidCallback? onDelete,
  bool filipino = false,
}) => MaterialApp(
  home: Scaffold(
    body: Builder(
      builder: (context) => NoteCard(
        note: _note,
        hc: HCColor.of(context),
        isFilipino: filipino,
        isAuthor: isAuthor,
        onDelete: onDelete ?? () {},
      ),
    ),
  ),
);

void main() {
  testWidgets('the author gets a labelled, full-size delete button', (tester) async {
    final semantics = tester.ensureSemantics();
    var deleted = 0;
    await tester.pumpWidget(_card(isAuthor: true, onDelete: () => deleted++));

    final button = find.byTooltip('Delete note');
    expect(button, findsOneWidget);
    // What a screen reader announces (Android reads the tooltip out, as it
    // does for the app's other icon buttons) and what a switch can act on.
    expect(
      tester.getSemantics(find.byType(IconButton)),
      isSemantics(
        tooltip: 'Delete note',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Delete Note?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(deleted, 1);
    semantics.dispose();
  });

  testWidgets('a keyboard, switch or gaze user can reach it', (tester) async {
    await tester.pumpWidget(_card(isAuthor: true));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final icon = tester.element(find.byIcon(Icons.delete_outline_rounded));
    expect(Focus.of(icon).hasFocus, isTrue);
  });

  testWidgets('its label is Filipino in Filipino', (tester) async {
    await tester.pumpWidget(_card(isAuthor: true, filipino: true));

    expect(find.byTooltip('Burahin ang tala'), findsOneWidget);
  });

  testWidgets('only the author can delete', (tester) async {
    await tester.pumpWidget(_card(isAuthor: false));

    expect(find.byType(IconButton), findsNothing);
  });
}
