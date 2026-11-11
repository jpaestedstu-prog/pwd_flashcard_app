import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/spoken_words.dart';
import 'package:pwdpwdpwd/core/accessibility/spoken_words_native.dart';
import 'package:pwdpwdpwd/core/accessibility/spoken_words_web.dart'
    show WebSpokenWordsUpdateBuilder;

/// What TalkBack is told, without the emoji it would read by name.
///
/// Found on the tablet (29 Oct): "Welcome Back! waving hand" on the profile
/// list, and about a hundred more of the app's titles and messages carry an
/// emoji for the eye ("Stories 📖", "Great Job! 🎉").
void main() {
  // A binding made before the app's, as the integration test makes one.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpokenWords', () {
    test('takes the pictures out of words', () {
      expect(SpokenWords.withoutPictures('Welcome Back! 👋'), 'Welcome Back!');
      expect(SpokenWords.withoutPictures('🎉 Amazing!'), 'Amazing!');
      expect(SpokenWords.withoutPictures('Stories 📖'), 'Stories');
      expect(SpokenWords.withoutPictures('👁️  Gaze Control'), 'Gaze Control');
      expect(SpokenWords.withoutPictures('Study Time ⏱️'), 'Study Time');
      expect(SpokenWords.withoutPictures('Profile updated! ✅'),
          'Profile updated!');
      expect(SpokenWords.withoutPictures('👨‍👩‍👧 Family'), 'Family');
      expect(SpokenWords.withoutPictures('🇵🇭 Filipino'), 'Filipino');
      expect(SpokenWords.withoutPictures('Next  ➡'), 'Next');
    });

    test('keeps a label\'s lines apart', () {
      expect(
        SpokenWords.withoutPictures('Leaderboard 🏆\nTop players'),
        'Leaderboard\nTop players',
      );
    });

    test('keeps the star the app counts in', () {
      // "You earned 3 ⭐" is read "You earned 3 star": the ⭐ is the word.
      expect(SpokenWords.withoutPictures('You earned 3 ⭐'), 'You earned 3 ⭐');
      expect(SpokenWords.withoutPictures('+1 ⭐ 🎉'), '+1 ⭐');
    });

    test('leaves a picture that is all there is to say', () {
      expect(SpokenWords.withoutPictures('👋'), '👋');
      expect(SpokenWords.withoutPictures('🎉 🎉'), '🎉 🎉');
      expect(SpokenWords.strip('🎉 🎉'), '');
    });

    test('leaves words without pictures as they are', () {
      const plain = 'Ilagay ang recovery code — 10 letra/numero • bago';
      expect(identical(SpokenWords.withoutPictures(plain), plain), isTrue);
    });
  });

  group('SpokenWordsUpdateBuilder', () {
    test('passes on labels, hints and tooltips without their pictures', () {
      final spy = _Spy();
      _update(
        SpokenWordsUpdateBuilder(spy),
        label: 'Leaderboard 🏆',
        hint: '🔊 Tap to hear it again',
        tooltip: 'Close ✖️',
        value: 'I love it 😊',
      );
      expect(spy.last[#label], 'Leaderboard');
      expect(spy.last[#hint], 'Tap to hear it again');
      expect(spy.last[#tooltip], 'Close');
      expect(spy.last[#value], 'I love it 😊',
          reason: 'a value is what was typed, and its selection counts it');
    });

    test('leaves a label whose attributes count its characters', () {
      final spy = _Spy();
      _update(
        SpokenWordsUpdateBuilder(spy),
        label: 'Kamusta 👋',
        labelAttributes: [
          ui.LocaleStringAttribute(
            range: const TextRange(start: 0, end: 7),
            locale: const Locale('fil'),
          ),
        ],
      );
      expect(spy.last[#label], 'Kamusta 👋');
    });

    // TalkBack stopped on "open book", "party popper": a picture for the eye,
    // with nothing to do there (4 Nov).
    test('a picture with nothing to press is no stop', () {
      final spy = _Spy();
      _update(SpokenWordsUpdateBuilder(spy), label: '📖');
      expect(spy.last[#label], '');
      _update(SpokenWordsUpdateBuilder(spy), label: '🎉 🎉');
      expect(spy.last[#label], '');
    });

    test('a picture that can be pressed keeps its name', () {
      final spy = _Spy();
      _update(SpokenWordsUpdateBuilder(spy), label: '👋', actions: 1);
      expect(spy.last[#label], '👋');
    });

    test('so do the star and a label with words', () {
      final spy = _Spy();
      _update(SpokenWordsUpdateBuilder(spy), label: '⭐');
      expect(spy.last[#label], '⭐');
      _update(SpokenWordsUpdateBuilder(spy), label: 'Great Job! 🎉');
      expect(spy.last[#label], 'Great Job!');
    });

    test('names custom actions without pictures', () {
      final spy = _Spy();
      SpokenWordsUpdateBuilder(spy).updateCustomAction(id: 1, label: '🗑️ Delete');
      expect(spy.last[#label], 'Delete');
    });

    // TalkBack reads in the tablet's language unless told otherwise: on a
    // tablet set to English, Filipino words were read with the English
    // voice. A Filipino screen marks its words Filipino; the English words
    // it teaches stay English.
    group('the language a word is read in', () {
      setUp(() => SpokenWords.learnVocabulary(
            ['Butterfly', 'Ice Cream', 'Ice', 'Rainy', 'One'],
            ['It is rainy outside.'],
          ));
      tearDown(() => SpokenWords.learnVocabulary(const [], const []));

      test('a Filipino word on a Filipino screen is Filipino', () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy),
            label: 'Mga Laro 🎮', locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.filipino);
      });

      test('a word it teaches stays English there', () {
        final spy = _Spy();
        for (final word in ['Butterfly', 'Butterfly 🦋', 'ice cream', 'Ice Cream!']) {
          _update(SpokenWordsUpdateBuilder(spy),
              label: word, locale: SpokenWords.filipino);
          expect(spy.last[#locale], SpokenWords.english, reason: word);
        }
      });

      // Found with NVDA: the Daily Challenge's word and sentence, one under
      // the other, were read as Filipino (4 Nov).
      test('a word and its English sentence stay English', () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy),
            label: 'Rainy\nIt is rainy outside.',
            locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.english);
      });

      test('a word beside its Filipino stays Filipino', () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy),
            label: 'Rainy\nMaulan', locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.filipino);
      });

      test('a sentence with the word in it stays Filipino, with the word '
          'marked English', () {
        final spy = _Spy();
        const label = 'Ano ang Butterfly sa Filipino?';
        _update(SpokenWordsUpdateBuilder(spy),
            label: label, locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.filipino);
        final marks = spy.last[#labelAttributes]! as List<ui.StringAttribute>;
        expect(marks, hasLength(1));
        final mark = marks.single as ui.LocaleStringAttribute;
        expect(mark.locale, SpokenWords.english);
        expect(label.substring(mark.range.start, mark.range.end), 'Butterfly');
      });

      test('the longest word is the one marked', () {
        final marks = SpokenWords.englishWordsIn('Ang Ice Cream ay masarap');
        expect(marks, hasLength(1));
        final range = marks.single.range;
        expect('Ang Ice Cream ay masarap'.substring(range.start, range.end),
            'Ice Cream');
      });

      test('a Filipino word is left alone: part of a word, or another case',
          () {
        expect(SpokenWords.englishWordsIn('Oneida one Rainyng'), isEmpty);
      });

      test('a flashcard says its word in English and the rest in Filipino',
          () {
        final spy = _Spy();
        const label = 'One, kategoryang Mga Numero. Pindutin para makita.';
        _update(SpokenWordsUpdateBuilder(spy),
            label: label, locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.filipino);
        final mark = (spy.last[#labelAttributes]! as List<ui.StringAttribute>)
            .single;
        expect(label.substring(mark.range.start, mark.range.end), 'One');
      });

      // Android reads a tooltip with no language of its own: TalkBack read
      // "Buksan ang mga setting" with the English voice (4 Nov).
      test('a button named by its tooltip is named by its label in Filipino',
          () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy),
            tooltip: 'Buksan ang mga setting ⚙️', locale: SpokenWords.filipino);
        expect(spy.last[#label], 'Buksan ang mga setting');
        expect(spy.last[#tooltip], '');
        expect(spy.last[#locale], SpokenWords.filipino);
      });

      test('in English it keeps its tooltip, and a label keeps its own', () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy), tooltip: 'Open settings');
        expect(spy.last[#label], '');
        expect(spy.last[#tooltip], 'Open settings');
        _update(SpokenWordsUpdateBuilder(spy),
            label: 'Mga Setting',
            tooltip: 'Buksan',
            locale: SpokenWords.filipino);
        expect(spy.last[#label], 'Mga Setting');
        expect(spy.last[#tooltip], 'Buksan');
      });

      test('an English screen is left as it was', () {
        final spy = _Spy();
        _update(SpokenWordsUpdateBuilder(spy), label: 'Butterfly');
        expect(spy.last[#locale], isNull, reason: "the tablet's own language");
      });

      test('and so in a browser', () {
        final spy = _WebSpy();
        _update(WebSpokenWordsUpdateBuilder(spy),
            label: 'Butterfly', locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.english);
        _update(WebSpokenWordsUpdateBuilder(spy),
            label: 'Mga Laro', locale: SpokenWords.filipino);
        expect(spy.last[#locale], SpokenWords.filipino);
      });
    });
  });

  testWidgets('a Filipino screen hands its words on marked Filipino',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        localeForSubtree: SpokenWords.filipino,
        child: const Column(children: [Text('Mga Laro'), Text('Mga Kuwento')]),
      ),
    ));
    for (final words in ['Mga Laro', 'Mga Kuwento']) {
      expect(
        tester.getSemantics(find.text(words)).getSemanticsData().locale,
        SpokenWords.filipino,
        reason: words,
      );
    }
    handle.dispose();
  });

  group('WebSpokenWordsUpdateBuilder', () {
    // The browser's twin: its signature also fits the phone's, so its words
    // can be checked here; in a browser the same code runs.
    test('passes on labels, hints and tooltips without their pictures', () {
      final spy = _WebSpy();
      _update(
        WebSpokenWordsUpdateBuilder(spy),
        label: 'Welcome Back! 👋',
        hint: '🔊 Tap to hear it again',
        tooltip: 'Close ✖️',
        value: 'I love it 😊',
      );
      expect(spy.last[#label], 'Welcome Back!');
      expect(spy.last[#hint], 'Tap to hear it again');
      expect(spy.last[#tooltip], 'Close');
      expect(spy.last[#value], 'I love it 😊');
    });

    test('keeps a picture that is all there is to press, and the star', () {
      final spy = _WebSpy();
      _update(WebSpokenWordsUpdateBuilder(spy), label: '👋', actions: 1);
      expect(spy.last[#label], '👋');
      _update(WebSpokenWordsUpdateBuilder(spy), label: 'You earned 3 ⭐ 🎉');
      expect(spy.last[#label], 'You earned 3 ⭐');
    });

    test('and a picture with nothing to press says nothing', () {
      final spy = _WebSpy();
      _update(WebSpokenWordsUpdateBuilder(spy), label: '🎉');
      expect(spy.last[#label], '');
    });
  });

  test('a binding made before main() is kept', () {
    // The integration test makes its own binding before calling main():
    // SpokenWordsBinding must not try to make a second one.
    final binding = WidgetsBinding.instance;
    expect(SpokenWordsBinding.ensureInitialized(), same(binding));
    expect(binding, isNot(isA<SpokenWordsBinding>()));
  });
}

/// Records what the wrapper hands on.
class _Spy extends Fake implements ui.SemanticsUpdateBuilder {
  Map<Symbol, Object?> last = const {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode ||
        invocation.memberName == #updateCustomAction) {
      last = invocation.namedArguments;
      return null;
    }
    return super.noSuchMethod(invocation);
  }
}

/// A browser's builder, as far as the wrapper can tell: the web's own
/// `updateNode` signature (a nullable tooltip and link), which [_Spy]'s — the
/// phone's — would refuse.
class _WebSpy extends Fake implements ui.SemanticsUpdateBuilder {
  Map<Symbol, Object?> last = const {};

  @override
  void updateNode({
    required int id,
    required ui.SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int? traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required ui.Rect rect,
    required String identifier,
    required String label,
    required List<ui.StringAttribute> labelAttributes,
    required String value,
    required List<ui.StringAttribute> valueAttributes,
    required String increasedValue,
    required List<ui.StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<ui.StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<ui.StringAttribute> hintAttributes,
    String? tooltip,
    ui.TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String? linkUrl,
    ui.SemanticsRole role = ui.SemanticsRole.none,
    required List<String>? controlsNodes,
    ui.SemanticsValidationResult validationResult =
        ui.SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    last = {
      #label: label,
      #hint: hint,
      #tooltip: tooltip,
      #value: value,
      #locale: locale,
    };
  }
}

void _update(
  ui.SemanticsUpdateBuilder builder, {
  String label = '',
  List<ui.StringAttribute> labelAttributes = const [],
  String value = '',
  String hint = '',
  String tooltip = '',
  Locale? locale,
  int actions = 0,
}) {
  builder.updateNode(
    id: 1,
    flags: ui.SemanticsFlags.none,
    actions: actions,
    maxValueLength: -1,
    currentValueLength: -1,
    textSelectionBase: -1,
    textSelectionExtent: -1,
    platformViewId: -1,
    scrollChildren: 0,
    scrollIndex: 0,
    traversalParent: -1,
    scrollPosition: 0,
    scrollExtentMax: 0,
    scrollExtentMin: 0,
    rect: Rect.zero,
    identifier: '',
    label: label,
    labelAttributes: labelAttributes,
    value: value,
    valueAttributes: const [],
    increasedValue: '',
    increasedValueAttributes: const [],
    decreasedValue: '',
    decreasedValueAttributes: const [],
    hint: hint,
    hintAttributes: const [],
    tooltip: tooltip,
    textDirection: TextDirection.ltr,
    transform: Float64List(16),
    hitTestTransform: Float64List(16),
    childrenInTraversalOrder: Int32List(0),
    childrenInHitTestOrder: Int32List(0),
    additionalActions: Int32List(0),
    controlsNodes: null,
    inputType: ui.SemanticsInputType.none,
    locale: locale,
    minValue: '',
    maxValue: '',
  );
}
