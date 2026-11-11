import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/widgets/text_limits.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';

import 'support/source_scan.dart';

/// Every text box has a limit, from one place.
///
/// 62 of the app's 84 boxes had none, and the ones that had disagreed about
/// the same thing: a name typed into the setup form could be any length, but
/// Edit Profile stopped at 30 and showed a longer one as "45/30" in red.
/// What is typed is shown elsewhere (a class list, a top bar, a routine
/// card), and every layout is tested at these lengths.

/// The boxes that keep no limit, and why. What is typed there is not shown
/// anywhere else: it is looked for, checked or opened.
const _noLimit = <String, String>{
  'lib/features/assessment/widgets/assessment_media_editor.dart:_link': 'a pasted address',
  'lib/features/classroom/screens/join_class_screen.dart:_codeController': 'a code, checked',
  'lib/features/flashcards/screens/fsl_dictionary_screen.dart:': 'a search',
  'lib/features/home_group/screens/join_home_group_screen.dart:_codeController': 'a code, checked',
  'lib/features/messaging/screens/messaging_screen.dart:_controller': 'a search',
  'lib/features/messaging/widgets/composer_pickers.dart:': 'a search',
  'lib/features/notebook/screens/note_editor_screen.dart:_contentController': 'a note\'s body: it scrolls',
  'lib/features/notebook/screens/notebook_screen.dart:_searchController': 'a search',
  'lib/features/notebook/widgets/flashcard_link_picker.dart:_searchController': 'a search',
  'lib/features/onboarding/screens/profile_switcher_screen.dart:_codeController': 'a code, checked',
  'lib/features/onboarding/widgets/profile_setup_form.dart:': 'the birth date: picked, not typed',
  'lib/features/parent/screens/child_time_limits_screen.dart:controller': 'a pasted address',
  'lib/features/parent/screens/time_up_lock_screen.dart:controller': 'a code, checked',
  'lib/features/recovery/screens/recover_profile_screen.dart:controller': 'a code, checked',
  'lib/features/routine/screens/routine_step_editor_sheet.dart:controller': 'a pasted address',
  'lib/widgets/student_filter_bar.dart:_searchController': 'a search',
};

final _box = RegExp(r'(?<![\w.])(TextField|TextFormField)\(');
final _controller = RegExp(r'controller:\s*([\w.]+)');

/// The boxes in [source] with no `maxLength`, by their controller's name.
List<String> _unlimited(String source) {
  final found = <String>[];
  for (final m in _box.allMatches(source)) {
    final open = m.end - 1;
    final args = namedArgs(source, open);
    if (args.contains('maxLength')) continue;
    final close = matchParen(source, open) ?? open;
    final body = source.substring(open, close);
    found.add(_controller.firstMatch(body)?.group(1) ?? '');
  }
  return found;
}

void main() {
  test('every text box has a limit, or a reason on the list above', () {
    final bad = <String>[];
    final used = <String>{};
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.contains('/l10n/')) continue;
      for (final name in _unlimited(file.readAsStringSync())) {
        final key = '$path:$name';
        if (_noLimit.containsKey(key)) {
          used.add(key);
        } else {
          bad.add(key);
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'give the box maxLength: TextLimits.…, '
            'buildCounter: TextLimits.counter');
    expect(_noLimit.keys.toSet().difference(used), isEmpty,
        reason: 'that box has a limit now, or is gone: off the list with it');
  });

  test('the scan sees a box with no limit, and one with', () {
    expect(_unlimited("TextField(controller: _a, maxLength: 3)"), isEmpty);
    expect(_unlimited("TextFormField(controller: _b)"), ['_b']);
    expect(_unlimited("TextField()"), ['']);
    // A nested box's limit is not its parent's.
    expect(
      _unlimited("TextField(controller: _a, decoration: Foo(maxLength: 3))"),
      ['_a'],
    );
  });

  group('the count under a box', () {
    Future<TextEditingController> pumpBox(
      WidgetTester tester, {
      int limit = 10,
      String text = '',
      Locale locale = const Locale('en'),
    }) async {
      final controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TextField(
            controller: controller,
            maxLength: limit,
            buildCounter: TextLimits.counter,
          ),
        ),
      ));
      return controller;
    }

    testWidgets('nothing while there is room', (tester) async {
      await pumpBox(tester, text: 'abcdefg');
      expect(find.textContaining('/10'), findsNothing);
    });

    testWidgets('shows close to the limit', (tester) async {
      await pumpBox(tester, text: 'abcdefgh');
      expect(find.text('8/10'), findsOneWidget);
    });

    testWidgets('is read in words, not as "8 slash 10"', (tester) async {
      await pumpBox(tester, text: 'abcdefgh');
      expect(
        tester.widget<Text>(find.text('8/10')).semanticsLabel,
        '8 of 10 letters',
      );
    });

    testWidgets('and in Filipino', (tester) async {
      await pumpBox(tester, text: 'abcdefgh', locale: const Locale('fil'));
      expect(
        tester.widget<Text>(find.text('8/10')).semanticsLabel,
        '8 sa 10 na letra',
      );
    });

    testWidgets('typing stops at the limit', (tester) async {
      final controller = await pumpBox(tester, text: 'abcdefghij');
      await tester.showKeyboard(find.byType(TextField));
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'abcdefghijk',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );
      await tester.pump();
      expect(controller.text, 'abcdefghij');
    });
  });
}
