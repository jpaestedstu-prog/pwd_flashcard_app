import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/haptic_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/services/shared_media_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_media_presentation.dart';
import 'package:pwdpwdpwd/features/assessment/models/assessment_models.dart';
import 'package:pwdpwdpwd/features/assessment/providers/assessment_provider.dart';
import 'package:pwdpwdpwd/features/assessment/screens/assessment_test_screen.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_cloud_service.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_cache.dart';
import 'package:pwdpwdpwd/features/assessment/services/assessment_media_store.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_editor.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_panel.dart';
import 'package:pwdpwdpwd/features/assessment/widgets/assessment_media_sheets.dart';
import 'package:pwdpwdpwd/features/experiment/models/experiment_models.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/providers/experiment_provider.dart';

/// What a learner meets when an educator attached pictures, video, sound or
/// a signed version — per accessibility category — and the educator's sheets.
///
/// No Hive writes anywhere in this file (see `widget-test-hive-write-hang`).
/// The video plugin is stood in for by [AssessmentMediaPanel.debugVideoBuilder]
/// and downloads by [AssessmentMediaCache.debugFetch], which also keeps the
/// real cache manager (and its platform plugins) from ever being touched.

class _Learner extends ProfileNotifier {
  static DisabilityType type = DisabilityType.hearing;

  @override
  UserProfile? build() => UserProfile(
    id: 'learner-1',
    name: 'Learner',
    role: UserRole.student,
    createdAt: DateTime(2026),
    disabilityType: type,
  );
}

class _FakeResults extends StateNotifier<List<AssessmentResult>>
    implements AssessmentResultsNotifier {
  _FakeResults() : super([]);

  @override
  String get profileId => 'learner-1';

  @override
  AssessmentCloudService get cloud => const AssessmentCloudService();

  @override
  void Function()? get onUploadMissed => null;

  @override
  Future<void> saveResult(AssessmentResult result) async {
    state = [...state, result];
  }

  @override
  void refresh() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTts extends TtsService {
  final List<String> spoken = [];

  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}
}

/// A cloud that accepts nothing and holds nothing — enough for the editor to
/// know sharing is possible without any upload happening.
class _NoopBackend implements SharedMediaBackend {
  @override
  Future<void> writeMeta(SharedMediaMeta meta) async {}
  @override
  Future<void> writeChunk(String id, int index, Uint8List bytes) async {}
  @override
  Future<SharedMediaMeta?> readMeta(String id) async => null;
  @override
  Future<Uint8List?> readChunk(String id, int index) async => null;
  @override
  Future<void> deleteChunk(String id, int index) async {}
  @override
  Future<void> deleteMeta(String id) async {}
  @override
  Future<List<String>> idsOwnedBy(String ownerProfileId) async => const [];
}

const _photo = 'assets/test/cat.png';
const _sign = 'https://res.cloudinary.com/demo/video/upload/cat_fsl.mp4';
const _video = 'https://res.cloudinary.com/demo/video/upload/cat.mp4';
const _description = 'A small grey animal sitting on a mat';

Assessment _test(AssessmentMedia media) => Assessment(
  id: 'custom-media',
  title: 'Animals with pictures',
  type: AssessmentType.custom,
  questions: [
    AssessmentQuestion(
      id: 'q1',
      questionText: 'Which animal is this?',
      correctAnswer: 'Cat',
      choices: const ['Cat', 'Dog', 'Bird', 'Fish'],
      category: FlashcardCategory.animals,
      media: media,
    ),
  ],
  categories: const [FlashcardCategory.animals],
  createdBy: 'teacher-1',
  createdAt: DateTime(2026, 9),
);

/// The picture's own semantics node — not the caption, which carries the
/// same words for a learner who reads them.
Finder imageLabelled(String label) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      (w.properties.image ?? false) &&
      w.properties.label == label,
);

/// Brings [target] on screen, taps it, and lets any sheet it opens slide all
/// the way in. One long pump is not enough: the first frame only *starts* a
/// route's animation, so a nested sheet is still parked below the screen.
Future<void> tapThrough(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  late _FakeTts tts;

  setUp(() {
    tts = _FakeTts();
    AssessmentMediaPanel.debugVideoBuilder = (context, value, kind, autoplay) =>
        Text('VIDEO:${kind.name}:$autoplay');
    AssessmentMediaCache.debugFetch = (_) async => null;
  });

  tearDown(() {
    AssessmentMediaPanel.debugVideoBuilder = null;
    AssessmentMediaCache.debugFetch = null;
    AssessmentMediaStore.debugPick = null;
    _Learner.type = DisabilityType.hearing;
  });

  List<Override> overrides() => [
    profileProvider.overrideWith(_Learner.new),
    hapticServiceProvider.overrideWithValue(HapticService(enabled: false)),
    assessmentResultsProvider.overrideWith((ref) => _FakeResults()),
    gamificationFeatureProvider(
      GamificationFeature.stars,
    ).overrideWithValue(false),
    ttsServiceProvider.overrideWithValue(tts),
  ];

  // ─── In a test ───────────────────────────────────────────

  group('in a test', () {
    Future<void> pumpTest(
      WidgetTester tester,
      Assessment assessment, {
      Future<List<String>> Function(List<String>)? prepareMedia,
    }) async {
      final router = GoRouter(
        initialLocation: '/take',
        routes: [
          GoRoute(
            path: '/take',
            builder: (_, _) => AssessmentTestScreen(
              assessment: assessment,
              clock: () => DateTime(2026, 9, 25, 9),
              prepareSignClips: (_) async => const [],
              prepareMedia: prepareMedia ?? (_) async => const [],
            ),
          ),
          GoRoute(
            path: '/assessment/summary',
            builder: (_, _) => const Scaffold(body: Text('SUMMARY')),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1200, 3200) * 1.75;
      tester.view.devicePixelRatio = 1.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    const everything = AssessmentMedia(
      photo: _photo,
      sign: _sign,
      description: _description,
    );

    testWidgets('a Deaf learner meets the signed version first, playing, '
        'with the description as a caption', (tester) async {
      _Learner.type = DisabilityType.hearing;
      await pumpTest(tester, _test(everything));

      final sign = find.text('VIDEO:sign:true');
      expect(sign, findsOneWidget, reason: 'the sign plays by itself');
      final picture = imageLabelled(_description);
      expect(picture, findsOneWidget);
      expect(
        tester.getTopLeft(sign).dy,
        lessThan(tester.getTopLeft(picture).dy),
        reason: 'the signed version leads for a Deaf learner',
      );
      expect(find.text('What it shows or says'), findsOneWidget);
      expect(find.text(_description), findsOneWidget);
      expect(find.text('Read it to me'), findsNothing);
      // The question itself is still there to answer.
      expect(find.text('Cat'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a learner with low vision gets no sign video, and can have '
        'the picture described aloud', (tester) async {
      _Learner.type = DisabilityType.visual;
      await pumpTest(tester, _test(everything));

      expect(find.textContaining('VIDEO:sign'), findsNothing);
      expect(imageLabelled(_description), findsOneWidget);
      await tester.tap(find.text('Read it to me'));
      await tester.pump();
      expect(tts.spoken, [_description]);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a learner with a cognitive disability sees one thing at a '
        'time', (tester) async {
      _Learner.type = DisabilityType.cognitive;
      await pumpTest(
        tester,
        _test(const AssessmentMedia(photo: _photo, video: _video)),
      );

      expect(find.textContaining('VIDEO:video'), findsNothing);
      expect(find.text('Show more (1)'), findsOneWidget);
      await tester.tap(find.text('Show more (1)'));
      await tester.pump();
      expect(find.text('VIDEO:video:false'), findsOneWidget);
      expect(find.text('Show more (1)'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('it waits for only the media this learner will be shown', (
      tester,
    ) async {
      _Learner.type = DisabilityType.visual;
      List<String>? asked;
      await pumpTest(
        tester,
        _test(everything),
        prepareMedia: (values) async {
          asked = values;
          return const [];
        },
      );
      expect(asked, [_photo], reason: 'no sign video for a blind learner');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('missing media holds the test, and the learner may start '
        'without it', (tester) async {
      _Learner.type = DisabilityType.hearing;
      await pumpTest(
        tester,
        _test(everything),
        prepareMedia: (values) async => values,
      );
      expect(
        find.text("Some pictures or videos aren't on this tablet"),
        findsOneWidget,
      );
      expect(find.textContaining('Question 1'), findsNothing);

      await tester.tap(find.text('Start without them'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('Question 1'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a question with no media starts at once and shows no panel', (
      tester,
    ) async {
      var asked = false;
      await pumpTest(
        tester,
        _test(AssessmentMedia.none),
        prepareMedia: (values) async {
          asked = true;
          return const [];
        },
      );
      expect(asked, isFalse);
      expect(find.textContaining('Question 1'), findsOneWidget);
      expect(find.byType(AssessmentMediaPanel), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  // ─── The sheets ──────────────────────────────────────────

  Future<void> pumpHost(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onOpen, {
    Size size = const Size(1200, 2600),
    double textScale = 1,
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size * 1.75;
    tester.view.devicePixelRatio = 1.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => onOpen(context),
                  child: const Text('OPEN'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('the "Before you start" sheet', () {
    final assignment = AssessmentAssignment(
      id: 'as1',
      assessmentId: 'custom-media',
      assessmentTitle: 'Animals with pictures',
      assignedBy: 'teacher-1',
      studentIds: const ['learner-1'],
      assignedAt: DateTime(2026, 9, 25),
      instructions: 'Watch my video, then pick the word.',
      media: const AssessmentMedia(sign: _sign),
    );

    test('only appears when there is media this learner will see', () {
      final hearing = AssessmentMediaPresentation.forType(DisabilityType.hearing);
      final visual = AssessmentMediaPresentation.forType(DisabilityType.visual);
      final signOnly = AssessmentAssignment(
        id: 'as2',
        assessmentId: 'a',
        assessmentTitle: 'A',
        assignedBy: 't',
        studentIds: const ['x'],
        assignedAt: DateTime(2026, 9, 25),
        media: const AssessmentMedia(sign: _sign),
      );
      expect(assignmentHasBriefing(signOnly, hearing), isTrue);
      expect(
        assignmentHasBriefing(signOnly, visual),
        isFalse,
        reason: 'a blind learner is not stopped for a video they cannot use',
      );
      final wordsOnly = AssessmentAssignment(
        id: 'as3',
        assessmentId: 'a',
        assessmentTitle: 'A',
        assignedBy: 't',
        studentIds: const ['x'],
        assignedAt: DateTime(2026, 9, 25),
        instructions: 'Do this before Friday.',
      );
      expect(
        assignmentHasBriefing(wordsOnly, hearing),
        isFalse,
        reason: 'written instructions are already on the tile; no extra tap',
      );
    });

    testWidgets('shows the instructions and the signed version, and starts', (
      tester,
    ) async {
      bool? started;
      await pumpHost(tester, (context) async {
        started = await showAssignmentBriefing(
          context,
          assignment: assignment,
          assessment: _test(AssessmentMedia.none),
          presentation: AssessmentMediaPresentation.forType(
            DisabilityType.hearing,
          ),
        );
      });
      expect(find.text('Before you start'), findsOneWidget);
      expect(find.text('Watch my video, then pick the word.'), findsOneWidget);
      expect(find.text('VIDEO:sign:true'), findsOneWidget);
      await tester.tap(find.text('Start the test'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(started, isTrue);
    });
  });

  group('the feedback editor', () {
    Future<FeedbackEdit?> Function(BuildContext) open(
      void Function(FeedbackEdit?) done, {
      List<String> tips = const [],
    }) => (context) async {
      done(
        await showFeedbackEditor(
          context,
          learnerName: 'Ana',
          assignmentTitle: 'Animals',
          ownerKey: 'fb_as1_ana',
          tips: tips,
        ),
      );
      return null;
    };

    testWidgets('names what reaches this learner best', (tester) async {
      final t = await AppLocalizations.delegate.load(const Locale('en'));
      final tips = assessmentMediaTips(t, [
        (name: 'Ana', type: DisabilityType.hearing, supports: const {}),
      ]);
      await pumpHost(tester, open((_) {}, tips: tips));
      expect(find.text('Feedback for Ana'), findsOneWidget);
      expect(
        find.text('For Ana: add an FSL video, and put any sound into words.'),
        findsOneWidget,
      );
      expect(find.text('Not finished yet'), findsOneWidget);
    });

    testWidgets('will not send an empty note', (tester) async {
      FeedbackEdit? result;
      var closed = false;
      await pumpHost(tester, open((r) {
        result = r;
        closed = true;
      }));
      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      expect(
        find.text('Write a note or add a picture, video or sound first.'),
        findsOneWidget,
      );
      expect(closed, isFalse);
      expect(result, isNull);
    });

    testWidgets('sends a note with a linked picture and its description', (
      tester,
    ) async {
      FeedbackEdit? result;
      await pumpHost(tester, open((r) => result = r));

      await tester.enterText(
        find.widgetWithText(TextField, 'Your note'),
        'You signed every animal right!',
      );
      await tapThrough(tester, find.text('Add Photo'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Or paste a link'),
        'https://example.com/cat.jpg',
      );
      await tapThrough(tester, find.text('Use this link'));

      expect(find.text('A link reaches every device.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Describe it in words'),
        'Your drawing of a cat',
      );
      await tapThrough(tester, find.text('Send feedback'));

      expect(result?.feedback?.note, 'You signed every animal right!');
      expect(result?.feedback?.media.photo, 'https://example.com/cat.jpg');
      expect(result?.feedback?.media.description, 'Your drawing of a cat');
    });

    testWidgets('adding media does not bring the keyboard back afterwards', (
      tester,
    ) async {
      // Seen on the tablet: closing a media sheet returned focus to the note
      // field, and the keyboard sprang up over the slot just filled.
      await pumpHost(tester, open((_) {}));
      await tester.tap(find.widgetWithText(TextField, 'Your note'));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      await tapThrough(tester, find.text('Add Photo'));
      await tester.tapAt(const Offset(600, 20)); // the sheet's barrier
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Or paste a link'), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('a link that is not a link is refused', (tester) async {
      await pumpHost(tester, open((_) {}));
      await tapThrough(tester, find.text('Add FSL video'));
      // The sign slot explains who sees it before anything is added.
      expect(find.textContaining('Shown to learners who sign'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Or paste a link'),
        'my video',
      );
      await tapThrough(tester, find.text('Use this link'));
      expect(find.text('Paste a link that starts with https://'), findsOneWidget);
    });
  });

  // ─── Sharing ─────────────────────────────────────────────

  group('where each file stands', () {
    Future<void> pumpEditor(
      WidgetTester tester,
      AssessmentMedia value, {
      String? owner,
    }) async {
      await pumpHost(
        tester,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SingleChildScrollView(
            child: AssessmentMediaEditor(
              value: value,
              onChanged: (_) {},
              ownerKey: 'q1',
              ledger: AssessmentMediaLedger(),
              ownerProfileId: owner,
            ),
          ),
        ),
      );
    }

    testWidgets('a shared file says it reaches every device', (tester) async {
      await pumpEditor(tester, const AssessmentMedia(sign: 'shared://abc'));
      expect(find.text('Shared — reaches every device.'), findsOneWidget);
      expect(find.text('Share now'), findsNothing);
    });

    testWidgets('a file still on this tablet offers to share it', (
      tester,
    ) async {
      SharedMediaService.debugBackend = _NoopBackend();
      addTearDown(() => SharedMediaService.debugBackend = null);
      await pumpEditor(
        tester,
        const AssessmentMedia(photo: 'file:///d/assessment_media/q_photo_1.jpg'),
        owner: 'teacher-1',
      );
      expect(find.text('On this tablet only — not shared yet.'), findsOneWidget);
      expect(find.text('Share now'), findsOneWidget);
    });

    testWidgets('with no cloud at all it only warns, and offers nothing', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        const AssessmentMedia(photo: 'file:///d/assessment_media/q_photo_1.jpg'),
        owner: 'teacher-1',
      );
      expect(
        find.text(
          "On this tablet only — learners on another device won't see it.",
        ),
        findsOneWidget,
      );
      expect(find.text('Share now'), findsNothing);
    });
  });

  // ─── Big type on a small phone ───────────────────────────

  group('at 2.0x text on a 360×640 phone', () {
    testWidgets('the editor with every slot filled does not overflow', (
      tester,
    ) async {
      final ledger = AssessmentMediaLedger();
      await pumpHost(
        tester,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssessmentMediaEditor(
              value: const AssessmentMedia(
                photo: 'assets/x.png',
                gif: 'assets/x.gif',
                video: _video,
                audio: 'assets/x.m4a',
                sign: 'file:///d/assessment_media/x_sign_1.mp4',
                description: _description,
              ),
              onChanged: (_) {},
              ownerKey: 'q1',
              ledger: ledger,
              forQuestion: true,
              tips: const [
                'For Ana, Ben, Cy +2: add an FSL video, and put any sound '
                    'into words.',
              ],
            ),
          ),
        ),
        size: const Size(360, 640),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('On this tablet only — learners on another device '
          "won't see it."), findsOneWidget);
    });

    testWidgets('the empty editor in Filipino keeps every button whole', (
      tester,
    ) async {
      final ledger = AssessmentMediaLedger();
      await pumpHost(
        tester,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssessmentMediaEditor(
              value: AssessmentMedia.none,
              onChanged: (_) {},
              ownerKey: 'q1',
              ledger: ledger,
            ),
          ),
        ),
        size: const Size(360, 640),
        textScale: 2.0,
        locale: const Locale('fil'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Magdagdag ng GIF na gumagalaw'), findsOneWidget);
      // The label wraps inside its button rather than being cut: it is laid
      // out within the screen's width.
      final label = tester.getRect(find.text('Magdagdag ng GIF na gumagalaw'));
      expect(label.right, lessThanOrEqualTo(360));
      expect(label.left, greaterThanOrEqualTo(0));
    });

    testWidgets('the learner panel with every aid on does not overflow', (
      tester,
    ) async {
      await pumpHost(
        tester,
        (context) => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AssessmentMediaPanel(
              media: const AssessmentMedia(
                photo: _photo,
                sign: _sign,
                audio: 'assets/x.m4a',
                description: _description,
              ),
              presentation: AssessmentMediaPresentation.forType(
                DisabilityType.multiple,
              ),
              fallbackLabel: 'Question',
            ),
          ),
        ),
        size: const Size(360, 640),
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Read it to me'), findsOneWidget);
    });
  });
}
