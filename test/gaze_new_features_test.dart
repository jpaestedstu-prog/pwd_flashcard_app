import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';
import 'package:pwdpwdpwd/data/models/enums.dart' show UserRole;
import 'package:pwdpwdpwd/data/models/models.dart'
    show AppSettings, UserProfile;
import 'package:pwdpwdpwd/features/gaze_control/controllers/gaze_controller.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_camera_owners.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_home_grid.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/nav_gaze_scope.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;
import 'package:pwdpwdpwd/features/gaze_control/logic/gaze_focus_driver.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/one_euro_filter.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_settings.dart';
import 'package:pwdpwdpwd/features/gaze_control/providers/gaze_settings_provider.dart';
import 'package:pwdpwdpwd/features/gaze_control/screens/gaze_settings_screen.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_detector.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_metrics.dart';
import 'package:pwdpwdpwd/features/gaze_control/services/gaze_switch_input.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_hints.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_keyboard.dart';
import 'package:pwdpwdpwd/features/gaze_control/widgets/gaze_traversal.dart';
import 'package:pwdpwdpwd/l10n/app_localizations_en.dart';

import 'support/device_matrix.dart';
import 'support/screen_matrix.dart';

/// The seven Gaze Control additions of 1.2.5: resting position, smoothing,
/// the gaze keyboard, one-switch scanning, look and hold, spoken highlights,
/// per-learner settings for teachers and parents, and the usage measurements.

class _FakeDetector implements GazeDetector {
  @override
  Future<FaceSignal> detect(InputImage image) async => FaceSignal.absent;
  @override
  Future<void> close() async {}
}

class _MemoryStore implements GazeMetricsStore {
  final Map<String, Map> saved = {};
  @override
  Map? load(String profileId) => saved[profileId];
  @override
  void save(String profileId, Map<String, Map<String, int>> days) =>
      saved[profileId] = {
        for (final e in days.entries) e.key: Map<String, int>.of(e.value),
      };
  @override
  void remove(String profileId) => saved.remove(profileId);
}

class _FixedSettings extends GazeSettingsNotifier {
  _FixedSettings(this._value);
  final GazeSettings _value;
  @override
  GazeSettings build() => _value;
}

/// A teacher looking at a learner's dashboard ("view as student").
class _ViewingAs extends ProfileNotifier {
  _ViewingAs(this.learner, this.educator);
  final UserProfile learner;
  final UserProfile educator;
  @override
  UserProfile? build() => learner;
  @override
  bool get isViewingAsStudent => true;
  @override
  UserProfile? get savedEducatorProfile => educator;
}

class _StubAppSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

Future<List<CameraDescription>> _noCameras() async => const [];

class _TypedText implements GazeKeyboardTarget {
  @override
  TextEditingValue value = TextEditingValue.empty;
  @override
  TextCapitalization get capitalization => TextCapitalization.sentences;
  @override
  void submit() {}
}

GazeController _controller(GazeSettings settings) => GazeController(
  settings: settings,
  detectorFactory: _FakeDetector.new,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── Smoothing ────────────────────────────────────────────────────────
  group('OneEuroFilter', () {
    test('a steady head reads exactly where it is', () {
      final f = OneEuroFilter(minCutoff: 1.2, beta: 0.04);
      var out = 0.0;
      for (var i = 0; i < 30; i++) {
        out = f.filter(12, Duration(milliseconds: 33 * i));
      }
      expect(out, closeTo(12, 1e-9));
    });

    test('a tremor is damped, a real turn still arrives', () {
      final f = OneEuroFilter(minCutoff: 0.5, beta: 0.02);
      final random = math.Random(4);
      var maxSwing = 0.0;
      for (var i = 0; i < 60; i++) {
        final shake = (random.nextDouble() - 0.5) * 12; // ±6°
        final out = f.filter(shake, Duration(milliseconds: 33 * i));
        if (i > 5) maxSwing = math.max(maxSwing, out.abs());
      }
      expect(maxSwing, lessThan(4), reason: 'the ±6° shake is smoothed');

      // A deliberate 30° turn, held: reaches well past any threshold.
      var out = 0.0;
      for (var i = 60; i < 75; i++) {
        out = f.filter(30, Duration(milliseconds: 33 * i));
      }
      expect(out, greaterThan(20));
    });

    test('reset forgets the old angle', () {
      final f = OneEuroFilter(minCutoff: 0.5, beta: 0.02);
      f.filter(25, Duration.zero);
      f.reset();
      expect(f.filter(-10, const Duration(milliseconds: 33)), -10);
    });
  });

  group('controller smoothing', () {
    void shake(GazeController c, int frames) {
      // Settled in the middle first, then a ±17° tremor (past the 14°
      // threshold either way) every frame.
      for (var i = 1; i <= 5; i++) {
        c.debugFeed(const FaceSignal(hasFace: true),
            Duration(milliseconds: 33 * i));
      }
      for (var i = 6; i <= frames + 5; i++) {
        c.debugFeed(
          FaceSignal(hasFace: true, headTurn: i.isEven ? 17 : -17),
          Duration(milliseconds: 33 * i),
        );
      }
    }

    test('off: a jittering head flips the zone; strong: it stays put', () {
      final off = _controller(
        const GazeSettings(enabled: true, smoothing: GazeSmoothing.off),
      );
      final zones = <GazeZone>{};
      off.addListener(() => zones.add(off.zone));
      shake(off, 20);
      expect(zones, containsAll([GazeZone.left, GazeZone.right]));
      off.dispose();

      final strong = _controller(
        const GazeSettings(enabled: true, smoothing: GazeSmoothing.strong),
      );
      final steady = <GazeZone>{};
      strong.addListener(() => steady.add(strong.zone));
      shake(strong, 20);
      expect(steady, {GazeZone.none});
      strong.dispose();
    });
  });

  // ─── Resting position ─────────────────────────────────────────────────
  group('restFromSamples', () {
    List<(double, double)> still(double turn, double tilt, [int n = 20]) => [
      for (var i = 0; i < n; i++) (turn + (i.isEven ? 0.5 : -0.5), tilt),
    ];

    test('too few readings (the face was not seen) give nothing', () {
      expect(
        restFromSamples(still(5, 5, 7),
            mirrorHorizontal: true, invertVertical: false),
        isNull,
      );
    });

    test('a moving head gives nothing', () {
      final moving = [for (var i = 0; i < 20; i++) (i * 2.0, 0.0)];
      expect(
        restFromSamples(moving, mirrorHorizontal: true, invertVertical: false),
        isNull,
      );
    });

    test('looking far away is not a resting position', () {
      expect(
        restFromSamples(still(40, 0),
            mirrorHorizontal: false, invertVertical: false),
        isNull,
      );
    });

    test('a turned, tilted rest is kept as raw camera angles', () {
      // The learner rests turned 10° to their right and 5° down. Mirrored
      // front camera: the raw yaw is the opposite sign.
      final rest = restFromSamples(still(10, -5),
          mirrorHorizontal: true, invertVertical: false)!;
      expect(rest.yaw, closeTo(-10, 1e-9));
      expect(rest.pitch, closeTo(-5, 1e-9));
    });

    test('movements are then measured from the rest', () {
      // Resting turned 10° right (raw −10 under the mirror). Sitting there
      // must read as the middle; turning a further 16° must read as right.
      final c = _controller(const GazeSettings(
        enabled: true,
        smoothing: GazeSmoothing.off,
        restYaw: -10,
      ));
      c.debugFeed(const FaceSignal(hasFace: true, headTurn: 10), Duration.zero);
      expect(c.zone, GazeZone.none);
      c.debugFeed(const FaceSignal(hasFace: true, headTurn: 26),
          const Duration(milliseconds: 33));
      expect(c.zone, GazeZone.right);
      c.dispose();
    });
  });

  // ─── The settings model ───────────────────────────────────────────────
  group('GazeSettings: the new choices', () {
    test('an old saved map gets the new defaults', () {
      final s = GazeSettings.fromMap(const {
        'enabled': true,
        'sensitivity': 4,
        'blinkEnabled': false,
      });
      expect(s.smoothing, GazeSmoothing.light);
      expect(s.pickWith, GazePick.blink);
      expect(s.dwellSelect, isFalse);
      expect(s.speakHighlight, isFalse);
      expect(s.hasRestPosition, isFalse);
    });

    test('round-trips and clamps', () {
      const s = GazeSettings(
        enabled: true,
        restYaw: -12.5,
        restPitch: 4,
        smoothing: GazeSmoothing.strong,
        pickWith: GazePick.either,
        dwellSelect: true,
        dwellSelectMs: 3000,
        speakHighlight: true,
      );
      expect(GazeSettings.fromMap(s.toMap()), s);
      final wild = GazeSettings.fromMap({
        ...s.toMap(),
        'restYaw': 80,
        'dwellSelectMs': 99999,
        'pickWith': 'nonsense',
      });
      expect(wild.restYaw, GazeSettings.maxRestDeg);
      expect(wild.dwellSelectMs, GazeSettings.maxDwellSelectMs);
      expect(wild.pickWith, GazePick.blink);
    });

    test('switch scanning needs no camera, and only the switch picks', () {
      const s = GazeSettings(
        enabled: true,
        scanMode: true,
        pickWith: GazePick.switchButton,
      );
      expect(s.usesCamera, isFalse);
      expect(s.blinkSelects, isFalse);
      expect(s.switchSelects, isTrue);
      expect(s.restSelects, isFalse);
      expect(s.lookUpSelects, isFalse);
    });

    test('head moves with a switch to pick: camera on, blinks do not pick', () {
      const s = GazeSettings(enabled: true, pickWith: GazePick.switchButton);
      expect(s.usesCamera, isTrue);
      expect(s.blinkSelects, isFalse);
      expect(s.lookUpSelects, isFalse, reason: 'up moves up again');
    });

    test('look-up is the pick only when nothing else is', () {
      const noBlink = GazeSettings(enabled: true, blinkEnabled: false);
      expect(noBlink.lookUpSelects, isTrue);
      final hold = noBlink.copyWith(dwellSelect: true);
      expect(hold.restSelects, isTrue);
      expect(hold.lookUpSelects, isFalse);
      // Scanning never uses keep-still.
      expect(hold.copyWith(scanMode: true).restSelects, isFalse);
    });
  });

  // ─── Look and hold ────────────────────────────────────────────────────
  group('look and hold to choose', () {
    late GazeController c;
    var t = Duration.zero;
    var rests = 0;

    void feed(double turn, int ms) {
      for (var i = 0; i < ms ~/ 50; i++) {
        t += const Duration(milliseconds: 50);
        c.debugFeed(FaceSignal(hasFace: true, headTurn: turn), t);
      }
    }

    setUp(() {
      t = Duration.zero;
      rests = 0;
      c = _controller(const GazeSettings(
        enabled: true,
        smoothing: GazeSmoothing.off,
        dwellSelect: true,
        dwellSelectMs: 1000,
      ));
      c.onRest = () => rests++;
    });
    tearDown(() => c.dispose());

    test('keeping still where you already are picks nothing', () {
      feed(0, 3000);
      expect(rests, 0);
    });

    test('after a move, keeping still picks — once', () {
      c.armRestSelect();
      feed(0, 500);
      expect(rests, 0);
      expect(c.restProgress, closeTo(0.5, 0.06));
      feed(30, 200);
      expect(c.restProgress, 0, reason: 'moving starts the count over');
      feed(0, 1100);
      expect(rests, 1);
      feed(0, 3000);
      expect(rests, 1, reason: 'one pick per move');
    });

    test('a pick by other means, or the screen going away, disarms it', () {
      c.armRestSelect();
      c.disarmRestSelect();
      feed(0, 2000);
      expect(rests, 0);

      c.armRestSelect();
      c.suspendCamera();
      expect(c.restArmed, isFalse);
    });

    test('off unless the learner chose it', () {
      final plain = _controller(const GazeSettings(enabled: true));
      plain.armRestSelect();
      expect(plain.restArmed, isFalse);
      plain.dispose();
    });
  });

  // ─── Hints ────────────────────────────────────────────────────────────
  group('GazeHints', () {
    final t = AppLocalizationsEn();
    test('says what actually picks', () {
      expect(GazeHints.pick(t, const GazeSettings(enabled: true)),
          t.gzHintPickBlink);
      expect(
        GazeHints.pick(t, const GazeSettings(enabled: true, blinkEnabled: false)),
        t.gzHintPickLookUp,
      );
      expect(
        GazeHints.pick(
            t, const GazeSettings(enabled: true, pickWith: GazePick.switchButton)),
        t.gzHintPickSwitch,
      );
      expect(
        GazeHints.pick(
            t, const GazeSettings(enabled: true, pickWith: GazePick.either)),
        t.gzHintPickEither,
      );
      expect(
        GazeHints.pick(t, const GazeSettings(enabled: true, dwellSelect: true)),
        t.gzHintPickRest,
      );
      expect(
        GazeHints.scan(
          t,
          const GazeSettings(
              enabled: true, scanMode: true, pickWith: GazePick.switchButton),
        ),
        t.gzHintScanSwitch,
      );
    });
  });

  test('while a teacher views a learner, the gaze in use is the teacher’s',
      () {
    UserProfile p(String id, UserRole role) =>
        UserProfile(id: id, name: id, role: role, createdAt: DateTime(2026));
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(
        () => _ViewingAs(p('ana', UserRole.student), p('rose', UserRole.teacher)),
      ),
    ]);
    addTearDown(container.dispose);
    // The camera reads the teacher, and the study must not count the
    // teacher's gaze as Ana's.
    expect(gazeProfileIdAtTablet(container.read), 'rose');
  });

  // ─── Usage measurements ───────────────────────────────────────────────
  group('GazeMetrics', () {
    late DateTime now;
    final m = GazeMetrics.instance;

    setUp(() {
      m.reset();
      now = DateTime(2026, 10, 5, 9);
      m.clock = () => now;
    });
    tearDown(m.reset);

    test('counts time used, choices, speed and undone choices', () {
      final token = m.begin('kid');
      now = now.add(const Duration(seconds: 2));
      m.moved();
      now = now.add(const Duration(seconds: 3));
      m.moved();
      m.selected(GazeSelectBy.blink);
      now = now.add(const Duration(seconds: 1));
      m.backed(); // straight away: the wrong thing opened
      now = now.add(const Duration(seconds: 10));
      m.scanned();
      now = now.add(const Duration(seconds: 2));
      m.selected(GazeSelectBy.switchButton);
      now = now.add(const Duration(seconds: 30));
      m.backed(); // long after: an ordinary Back
      m.keyTyped();
      now = now.add(const Duration(seconds: 12));
      m.end(token);

      final day = m.total('kid', days: 1);
      // Time used runs between the learner's own inputs: 3 + 1 + 12 + 30 s.
      // The scan step is not one (the scanner steps by itself), and the 12 s
      // after the last key are not use either.
      expect(day.activeMs, 46000);
      expect(day.moves, 2);
      expect(day.scanSteps, 1);
      expect(day.selections, 2);
      expect(day.blinkSelects, 1);
      expect(day.switchSelects, 1);
      expect(day.backs, 2);
      expect(day.misSelections, 1);
      expect(day.keyboardKeys, 1);
      expect(day.selectionsPerMinute, closeTo(2 / (46 / 60), 1e-9));
      // 3 s from the first move to the blink; 2 s from the scan step.
      expect(day.avgSecondsToSelect, closeTo(2.5, 1e-9));
      expect(day.misSelectionRate, closeTo(0.5, 1e-9));
    });

    test('a long pause is not use, and is not a slow choice', () {
      final token = m.begin('kid');
      m.moved();
      now = now.add(const Duration(minutes: 10)); // put the tablet down
      m.selected(GazeSelectBy.blink);
      now = now.add(const Duration(seconds: 30));
      m.moved();
      m.end(token);
      final day = m.total('kid', days: 1);
      expect(day.activeMs, 30000);
      expect(day.latencyCount, 0, reason: 'ten minutes is not time to choose');
    });

    test('the app in the background stops the clock', () {
      final token = m.begin('kid');
      m.moved();
      m.pause();
      now = now.add(const Duration(seconds: 50));
      m.moved();
      now = now.add(const Duration(seconds: 5));
      m.moved();
      m.end(token);
      expect(m.total('kid', days: 1).activeMs, 5000);
    });

    test('nothing is counted outside a gaze session', () {
      m.moved();
      m.selected(GazeSelectBy.blink);
      expect(m.total('kid', days: 1).isEmpty, isTrue);
    });

    test('saved per learner and read back after a restart', () {
      final store = _MemoryStore();
      m.store = store;
      final token = m.begin('kid');
      m.moved();
      now = now.add(const Duration(seconds: 90));
      m.selected(GazeSelectBy.rest);
      now = now.add(const Duration(minutes: 2));
      m.end(token);
      m.calibrated('kid');
      expect(store.saved['kid'], isNotNull);

      // A fresh app: the counters come back from the store.
      m.reset();
      m.store = store;
      m.clock = () => now;
      final day = m.total('kid', days: 1);
      expect(day.restSelects, 1);
      expect(day.calibrations, 1);
      expect(day.activeMs, 90000);
      expect(m.total('someone-else', days: 1).isEmpty, isTrue);

      // Forgetting a learner drops what was kept for them.
      m.forget('kid');
      expect(store.saved['kid'], isNull);
      expect(m.total('kid', days: 1).isEmpty, isTrue);
    });

    test('CSV: a header and one row per day with use', () {
      final token = m.begin('kid');
      m.moved();
      now = now.add(const Duration(minutes: 1));
      m.selected(GazeSelectBy.headHold);
      m.end(token);
      final lines = m.csv('kid', learner: 'Ana "Bee"').trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('date,learner,active_minutes'));
      expect(lines.first, contains('head_hold'));
      expect(lines.last, startsWith('2026-10-05,"Ana ""Bee""",1.0,1,0,1,'));
    });
  });

  // ─── One switch ───────────────────────────────────────────────────────
  group('GazeSwitchInput', () {
    final input = GazeSwitchInput.instance;
    setUp(input.reset);
    tearDown(input.reset);

    test('a press goes to the newest listener, and claims the controller',
        () async {
      final got = <String>[];
      final first = input.attach(onPress: () => got.add('first'));
      final second = input.attach(onPress: () => got.add('second'));
      await Future<void>.delayed(Duration.zero);
      expect(input.claiming.value, isTrue);

      input.press();
      input.press(); // a bouncy switch: ignored
      expect(got, ['second']);

      input.detach(second);
      await Future<void>.delayed(GazeSwitchInput.debounce);
      input.press();
      expect(got, ['second', 'first']);

      input.detach(first);
      await Future<void>.delayed(Duration.zero);
      expect(input.claiming.value, isFalse);
      input.press();
      expect(got, hasLength(2));
    });

    testWidgets('a switch interface that types Space is heard',
        (tester) async {
      var presses = 0;
      final token = input.attach(onPress: () => presses++);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(presses, 1);
      // Arrows are left for the app.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(presses, 1);
      input.detach(token);
    });
  });

  // ─── Going round a long page ──────────────────────────────────────────
  group('the start of a surface is its real start', () {
    late List<FocusNode> nodes;
    late ScrollController scroll;

    Future<void> pumpList(WidgetTester tester, int n) async {
      nodes = [for (var i = 0; i < n; i++) FocusNode(debugLabel: 'item $i')];
      scroll = ScrollController();
      addTearDown(() {
        for (final f in nodes) {
          f.dispose();
        }
        scroll.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: scroll,
            itemCount: n,
            itemBuilder: (_, i) => TextButton(
              focusNode: nodes[i],
              onPressed: () {},
              child: Text('item $i'),
            ),
          ),
        ),
      ));
    }

    testWidgets('down from the last control of a lazy list wraps to the top',
        (tester) async {
      await pumpList(tester, 60);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      nodes[59].requestFocus();
      await tester.pump();
      expect(GazeFocusDriver.isLast(), isTrue);

      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(nodes[0].hasPrimaryFocus, isTrue,
          reason: 'not the first control the list happened to have built');
    });

    testWidgets('scanning comes round to the top after the Back pill',
        (tester) async {
      await pumpList(tester, 60);
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      nodes[59].requestFocus();
      await tester.pump();
      final traversal = GazeTraversal(onMoved: () {}, onPressed: (_) {});

      traversal.scanStep();
      expect(traversal.onExit, isTrue, reason: 'Back after the last control');
      traversal.scanStep();
      await tester.pumpAndSettle();
      expect(traversal.onExit, isFalse);
      expect(nodes[0].hasPrimaryFocus, isTrue);
      expect(scroll.offset, 0);
    });

    testWidgets('down from the Back pill is the first control, not the second',
        (tester) async {
      await pumpList(tester, 3);
      nodes[0].requestFocus();
      await tester.pump();
      final traversal = GazeTraversal(onMoved: () {}, onPressed: (_) {});

      traversal.move(TraversalDirection.up);
      expect(traversal.onExit, isTrue);
      traversal.move(TraversalDirection.down);
      await tester.pumpAndSettle();
      expect(traversal.onExit, isFalse);
      expect(nodes[0].hasPrimaryFocus, isTrue);
    });
  });

  // ─── ▼ does not jump over a row ────────────────────────────────────────
  group('down reaches the next row, even from a narrow button', () {
    testWidgets('a back button over an inset text field (Join Home Group)',
        (tester) async {
      final back = FocusNode(debugLabel: 'back');
      final field = FocusNode(debugLabel: 'field');
      final join = FocusNode(debugLabel: 'join');
      addTearDown(() {
        back.dispose();
        field.dispose();
        join.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              focusNode: back,
              icon: const Icon(Icons.arrow_back),
              onPressed: () {},
            ),
            title: const Text('Join Home Group'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The text box starts right of the back button's column.
                TextFormField(
                  focusNode: field,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 24),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  focusNode: join,
                  onPressed: () {},
                  child: const Text('Join group'),
                ),
              ],
            ),
          ),
        ),
      ));
      back.requestFocus();
      await tester.pump();
      expect(field.rect.left, greaterThan(back.rect.right),
          reason: 'the setup this guards against');

      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();
      expect(field.hasPrimaryFocus, isTrue, reason: 'not the button under it');
      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();
      expect(join.hasPrimaryFocus, isTrue);
      expect(GazeFocusDriver.move(TraversalDirection.up), isTrue);
      await tester.pumpAndSettle();
      expect(field.hasPrimaryFocus, isTrue);
    });

    testWidgets('side by side, the control below in the column still wins',
        (tester) async {
      final top = FocusNode(debugLabel: 'top');
      final tall = FocusNode(debugLabel: 'tall');
      final side = FocusNode(debugLabel: 'side');
      addTearDown(() {
        top.dispose();
        tall.dispose();
        side.dispose();
      });
      Widget box(FocusNode n, double h) => SizedBox(
            width: 200,
            height: h,
            child: TextButton(focusNode: n, onPressed: () {}, child: Text('$n')),
          );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              box(top, 60),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  box(tall, 300),
                  const SizedBox(width: 40),
                  // Beside the tall card, overlapping it vertically: not a
                  // row in between.
                  Padding(padding: const EdgeInsets.only(top: 20), child: box(side, 60)),
                ],
              ),
            ],
          ),
        ),
      ));
      top.requestFocus();
      await tester.pump();
      expect(GazeFocusDriver.move(TraversalDirection.down), isTrue);
      await tester.pumpAndSettle();
      expect(tall.hasPrimaryFocus, isTrue);
    });
  });

  // ─── The gaze keyboard ────────────────────────────────────────────────
  testWidgets('the gaze keyboard types, capitalises, deletes and finishes',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    GazeMetrics.instance.reset();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var submitted = 0;

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => GazeKeyboard.show(
                  context,
                  controller: controller,
                  hint: 'Message',
                  onSubmit: () => submitted++,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A sheet, not the whole screen: the conversation stays in view above it.
    expect(tester.getSize(find.byType(GazeKeyboardSheet)).height,
        lessThanOrEqualTo(1280 * 0.72 + 0.5));

    // The start of a sentence is a capital.
    expect(find.text('Message'), findsOneWidget);
    await tester.tap(find.text('H'));
    await tester.pump();
    expect(controller.text, 'H');
    // …and the rest is lower case.
    await tester.tap(find.text('i'));
    await tester.pump();
    expect(controller.text, 'Hi');
    await tester.tap(find.text('Space'));
    await tester.tap(find.text('x'));
    await tester.pump();
    expect(controller.text, 'Hi x');
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(controller.text, 'Hi ');

    // Numbers and punctuation.
    await tester.tap(find.text('123'));
    await tester.pump();
    await tester.tap(find.text('!'));
    await tester.pump();
    expect(controller.text, 'Hi !');
    await tester.tap(find.text('ABC'));
    await tester.pump();
    // After "!" a new sentence starts: capitals again.
    expect(find.text('A'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Space'), findsNothing, reason: 'the sheet closed');
    expect(submitted, 1);
  });

  testWidgets('a capitals-only field (a join code) gets a capitals keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final node = FocusNode();
    final code = TextEditingController();
    addTearDown(() {
      node.dispose();
      code.dispose();
    });
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TextField(
            focusNode: node,
            controller: code,
            textCapitalization: TextCapitalization.characters,
          ),
        ),
      ),
    ));
    node.requestFocus();
    await tester.pump();
    // Gaze pressed the field.
    expect(GazeKeyboard.openForFocus(), isTrue);
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(find.text('B'), findsOneWidget, reason: 'still capitals');
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(code.text, 'AB');
  });

  testWidgets('the gaze keyboard fits phones and tablets at large text',
      (tester) async {
    await expectScreenNoOverflowAcrossDevices(
      tester,
      () => Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: GazeKeyboardSheet(target: _TypedText(), hint: 'Message'),
        ),
      ),
      devices: [...kNarrowPortrait, ...kTabletMatrix],
    );
  });

  // ─── A learner's settings, opened by their teacher or parent ─────────
  testWidgets('a grown-up edits the learner’s settings, not their own',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GazeSettingsScreen(profileId: 'kid-1', learnerName: 'Ana'),
      ),
    ));
    await tester.pump();

    expect(find.text('Gaze Control for Ana'), findsOneWidget);
    await tester.tap(find.text('A switch or controller button'));
    await tester.pump();
    await tester.tap(find.text('Read the highlight aloud'));
    await tester.pump();

    final learner = container.read(gazeSettingsForProfileProvider('kid-1'));
    expect(learner.pickWith, GazePick.switchButton);
    expect(learner.speakHighlight, isTrue);
    // The signed-in profile's own settings are untouched.
    expect(container.read(gazeSettingsProvider).pickWith, GazePick.blink);
    expect(container.read(gazeSettingsProvider).speakHighlight, isFalse);
  });

  // ─── One switch, in the shell ─────────────────────────────────────────
  group('the shell with one-switch scanning', () {
    setUp(() {
      while (gazeCameraOwners.isBusy) {
        gazeCameraOwners.release();
      }
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
    });
    tearDown(() {
      gazeHomeGrid.clearGrid();
      GazeSwitchInput.instance.reset();
    });

    Future<List<int>> pumpShell(
      WidgetTester tester,
      GazeSettings settings,
      void Function(NavGazeState) onState,
    ) async {
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(() => _FixedSettings(settings)),
        settingsProvider.overrideWith(_StubAppSettings.new),
      ]);
      addTearDown(container.dispose);
      final commits = <int>[];
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: NavGazeScope(
            currentIndex: 0,
            itemCount: 3,
            onCommit: commits.add,
            camerasLoader: _noCameras,
            detectorFactory: _FakeDetector.new,
            builder: (context, gaze) {
              onState(gaze);
              return const Scaffold(body: Text('hub'));
            },
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      return commits;
    }

    testWidgets('no camera at all, and the switch picks what is lit',
        (tester) async {
      var opened = 0;
      gazeHomeGrid.publishGrid([
        [GazeTileCell(label: 'tile', onActivate: () => opened++)],
      ]);
      var now = DateTime(2026, 10, 5, 9);
      GazeSwitchInput.instance.clock = () => now;
      late NavGazeState last;
      final commits = await pumpShell(
        tester,
        const GazeSettings(
          enabled: true,
          scanMode: true,
          scanStepMs: 1000,
          pickWith: GazePick.switchButton,
        ),
        (s) => last = s,
      );
      expect(last.ready, isTrue);
      expect(GazeController.debugLive.last.usesCamera, isFalse);
      expect(GazeSwitchInput.instance.claiming.value, isTrue);

      // The tile row is lit first; one control in it, so a press opens it.
      expect(gazeHomeGrid.focusRow, 0);
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(opened, 1);

      // Then the tab bar: a press steps in, the tabs light, a press opens.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(last.wholeNavRow, isTrue);
      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(last.targetIndex, 0);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(last.targetIndex, 1);
      now = now.add(const Duration(seconds: 1));
      GazeSwitchInput.instance.press();
      await tester.pump();
      expect(commits, [1]);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(GazeSwitchInput.instance.claiming.value, isFalse,
          reason: 'the controller is handed back when gaze stands down');
    });

    testWidgets('a blink pick stops the pending keep-still', (tester) async {
      gazeHomeGrid.publishGrid([
        [
          GazeTileCell(label: 'a', onActivate: () {}),
          GazeTileCell(label: 'b', onActivate: () {}),
        ],
      ]);
      await pumpShell(
        tester,
        const GazeSettings(enabled: true, dwellSelect: true),
        (_) {},
      );
      final camera = GazeController.debugLive.last;
      // Up into the tiles, then right: a move arms the keep-still.
      camera.debugSelect(GazeZone.up);
      await tester.pump();
      camera.debugSelect(GazeZone.right);
      await tester.pump();
      expect(camera.restArmed, isTrue);
      camera.debugBlink();
      await tester.pump();
      expect(camera.restArmed, isFalse,
          reason: 'keeping still after a blink must not pick again');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });

  // ─── No locking yourself out ──────────────────────────────────────────
  group('a learner cannot switch off the input they are using', () {
    setUp(GazeSwitchInput.instance.reset);
    tearDown(GazeSwitchInput.instance.reset);

    Future<ProviderContainer> pumpOwn(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = ProviderContainer(overrides: [
        gazeSettingsProvider.overrideWith(
          () => _FixedSettings(const GazeSettings(enabled: true)),
        ),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GazeSettingsScreen()),
      ));
      await tester.pump();
      return container;
    }

    testWidgets('choosing the switch is kept by a switch press', (tester) async {
      final c = await pumpOwn(tester);
      await tester.tap(find.text('A switch or controller button'));
      await tester.pump();
      expect(find.text('Keep this change?'), findsOneWidget);
      expect(c.read(gazeSettingsProvider).pickWith, GazePick.switchButton);

      GazeSwitchInput.instance.press();
      await tester.pumpAndSettle();
      expect(find.text('Keep this change?'), findsNothing);
      expect(c.read(gazeSettingsProvider).pickWith, GazePick.switchButton);
    });

    testWidgets('…and undone by waiting, for a learner with no switch',
        (tester) async {
      final c = await pumpOwn(tester);
      await tester.tap(find.text('A switch or controller button'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(find.text('Keep this change?'), findsNothing);
      expect(c.read(gazeSettingsProvider).pickWith, GazePick.blink);
    });

    testWidgets('switching gaze off comes back on unless kept', (tester) async {
      final c = await pumpOwn(tester);
      await tester.tap(find.text('Enable Gaze Control'));
      await tester.pump();
      expect(c.read(gazeSettingsProvider).enabled, isFalse);
      await tester.pump(const Duration(seconds: 16));
      await tester.pumpAndSettle();
      expect(c.read(gazeSettingsProvider).enabled, isTrue);

      // Keep (touch) makes it stick.
      await tester.tap(find.text('Enable Gaze Control'));
      await tester.pump();
      await tester.tap(find.text('Keep'));
      await tester.pumpAndSettle();
      expect(c.read(gazeSettingsProvider).enabled, isFalse);
    });
  });

  testWidgets('switch scanning hides the camera-only settings',
      (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(gazeSettingsForProfileProvider('kid-2').notifier)
        .update(const GazeSettings(
          enabled: true,
          scanMode: true,
          pickWith: GazePick.switchButton,
        ));

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: GazeSettingsScreen(profileId: 'kid-2', learnerName: 'Ben'),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('The camera stays off'), findsOneWidget);
    expect(find.text('Sensitivity'), findsNothing);
    expect(find.text('Set resting position'), findsNothing);
    expect(find.text('Blink to confirm'), findsNothing);
  });
}
