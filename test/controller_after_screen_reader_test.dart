import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/focused_label.dart';
import 'package:pwdpwdpwd/core/accessibility/screen_reader_focus_guard.dart';
import 'package:pwdpwdpwd/core/accessibility/sound_service.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';
import 'package:pwdpwdpwd/features/gamepad/providers/gamepad_status_provider.dart';
import 'package:pwdpwdpwd/features/gamepad/services/gamepad_service.dart';
import 'package:pwdpwdpwd/features/gamepad/widgets/gamepad_host.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart' show routerProvider;
import 'package:pwdpwdpwd/navigation/dpad_keys.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/all_screens.dart' show openSweepBoxes, closeSweepBoxes;

/// The controller after TalkBack has moved the page.
///
/// Found on the tablet (29 Oct): after walking Settings with TalkBack's own
/// keyboard keys, every controller press said "Nothing more that way. Still
/// on Unnamed item." TalkBack had scrolled the page, and while a screen
/// reader runs the app lets go of a D-pad focus that scrolls out of sight
/// ([ScreenReaderFocusGuard], so TalkBack is not pulled back to it). The
/// focus was left on the page's own focus scope, which has no name and no
/// neighbours — and the controller had nowhere to move from.
class _Student extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'guard-student',
        name: 'Ana',
        role: UserRole.student,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
      );
}

class _FakePad extends GamepadService {
  final _buttons = StreamController<GamepadEvent>.broadcast();
  final _connections = StreamController<GamepadConnectionEvent>.broadcast();

  @override
  Stream<GamepadEvent> get buttons => _buttons.stream;

  @override
  Stream<GamepadConnectionEvent> get connections => _connections.stream;

  @override
  void start() {}

  @override
  Future<void> setCaptureEnabled(bool enabled) async {}

  void press(GamepadButton button) {
    _buttons.add(GamepadEvent(button: button, pressed: true));
    _buttons.add(GamepadEvent(button: button, pressed: false));
  }

  void connect() => _connections.add(
        const GamepadConnectionEvent(
          deviceId: 80,
          name: 'GamePadPlus V3',
          connected: true,
        ),
      );

  @override
  Future<void> dispose() async {
    await _buttons.close();
    await _connections.close();
  }
}

class _FakeTts extends TtsService {
  final List<String> spoken = [];

  @override
  Future<void> init({double speed = 0.5, double pitch = 1.0}) async {}

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> speakEnglish(String text) async => spoken.add(text);

  @override
  Future<void> speakFilipino(String text) async => spoken.add(text);

  @override
  Future<void> stop() async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> dispose() async {}
}

class _SilentSound implements SoundService {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

/// Which rows were pressed.
final _tapped = <int>[];

/// A long page, as Settings is: forty named rows.
GoRouter _router() => GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  ListTile(title: Text('Row $i'), onTap: () => _tapped.add(i)),
              ],
            ),
          ),
        ),
      ],
    );

String? _focusedLabel() =>
    FocusedLabel.of(FocusManager.instance.primaryFocus?.context);

void main() {
  setUpAll(() => openSweepBoxes('controller_after_reader'));
  tearDownAll(closeSweepBoxes);

  late _FakePad pad;
  late _FakeTts tts;
  // A focus above the app's own shortcuts: from here no arrow reaches them.
  late FocusNode outside;
  setUp(() {
    pad = _FakePad();
    tts = _FakeTts();
    outside = FocusNode(debugLabel: 'outside the app');
    _tapped.clear();
  });
  tearDown(() {
    outside.dispose();
    ScreenReaderFocusGuard.screenReaderOn = () => false;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var t = 0; t < 6; t++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// The app's own nesting (main.dart): the controller's host around the
  /// guard, around the screens.
  Future<void> pumpPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileProvider.overrideWith(_Student.new),
          routerProvider.overrideWithValue(router),
          gamepadServiceProvider.overrideWithValue(pad),
          ttsServiceProvider.overrideWithValue(tts),
          soundServiceProvider.overrideWithValue(_SilentSound()),
        ],
        child: Focus(
          focusNode: outside,
          child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          shortcuts: dpadShortcuts,
          actions: dpadActions,
          routerConfig: router,
          builder: (context, child) => DpadFieldExits(
            child: GamepadHost(
              child: ScreenReaderFocusGuard(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        ),
      ),
    );
    await settle(tester);
    pad.connect();
    await settle(tester);
  }

  /// The controller on a row near the top; then, with a screen reader on,
  /// the page scrolled until that row is out of sight, as TalkBack's walk
  /// scrolled Settings. Returns the label the D-pad had.
  Future<String?> leaveFocusBehind(
    WidgetTester tester, {
    bool screenReader = true,
  }) async {
    for (var i = 0; i < 3; i++) {
      pad.press(GamepadButton.dpadDown);
      await settle(tester);
    }
    final had = _focusedLabel();
    ScreenReaderFocusGuard.screenReaderOn = () => screenReader;
    final list = tester.state<ScrollableState>(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      ),
    );
    list.position.jumpTo(list.position.maxScrollExtent / 2);
    await settle(tester);
    return had;
  }



  testWidgets('the guard lets go of a focus scrolled out of sight',
      (tester) async {
    await pumpPage(tester);
    final had = await leaveFocusBehind(tester);
    expect(had, isNotNull);
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>(),
        reason: 'the setting the controller has to cope with');
  });

  testWidgets('the controller then moves, onto a row on screen',
      (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester);
    tts.spoken.clear();
    pad.press(GamepadButton.dpadDown);
    await settle(tester);
    final said = tts.spoken.join(' | ');
    expect(said, isNot(contains('Nothing more that way')), reason: said);
    expect(said, isNot(contains('Unnamed item')), reason: said);
    final now = _focusedLabel();
    expect(now, isNotNull, reason: said);
    final box = tester.getRect(find.text(now!));
    expect(box.top >= 0 && box.bottom <= 1280, isTrue,
        reason: '$now is on screen, where the learner is: $box');
  });

  testWidgets('and so do the arrow keys', (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await settle(tester);
    final now = _focusedLabel();
    expect(now, isNotNull);
    final box = tester.getRect(find.text(now!));
    expect(box.top >= 0 && box.bottom <= 1280, isTrue, reason: '$now $box');
  });

  testWidgets('A on the scope presses nothing it should not, and lands on a '
      'row on screen', (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester);
    tts.spoken.clear();
    pad.press(GamepadButton.a);
    await settle(tester);
    final said = tts.spoken.join(' | ');
    expect(said, isNot(contains('Unnamed item')), reason: said);
  });
  bool onScreen(WidgetTester tester, String label) {
    final box = tester.getRect(find.text(label));
    return box.top >= 0 && box.bottom <= 1280;
  }

  // The same with no screen reader: a finger (or a mouse wheel) scrolled
  // the page under the controller's focus. The focus stays, kept alive off
  // stage with no place on the screen.
  testWidgets('after a finger scrolls the page, the controller moves onto '
      'a row on screen', (tester) async {
    await pumpPage(tester);
    final had = await leaveFocusBehind(tester, screenReader: false);
    expect(_focusedLabel(), had, reason: 'no screen reader: the focus stays');
    tts.spoken.clear();
    pad.press(GamepadButton.dpadDown);
    await settle(tester);
    final said = tts.spoken.join(' | ');
    expect(said, isNot(contains('Nothing more that way')), reason: said);
    final now = _focusedLabel();
    expect(now, isNot(had));
    expect(onScreen(tester, now!), isTrue, reason: now);
  });

  testWidgets('up from there lands on the last row on screen',
      (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester, screenReader: false);
    pad.press(GamepadButton.dpadUp);
    await settle(tester);
    final now = _focusedLabel()!;
    expect(onScreen(tester, now), isTrue, reason: now);
    final row = int.parse(now.split(' ').last);
    expect(row, greaterThan(20), reason: 'the bottom of what is shown: $now');
  });

  testWidgets('A does not press the row out of sight', (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester, screenReader: false);
    pad.press(GamepadButton.a);
    await settle(tester);
    expect(_tapped, isEmpty, reason: 'a row the learner cannot see');
    expect(onScreen(tester, _focusedLabel()!), isTrue);
  });

  testWidgets('R2 steps on from a row on screen', (tester) async {
    await pumpPage(tester);
    await leaveFocusBehind(tester, screenReader: false);
    pad.press(GamepadButton.r2);
    await settle(tester);
    expect(onScreen(tester, _focusedLabel()!), isTrue);
  });

  // The other half, found on the tablet (4 Nov): TalkBack's keys are Alt +
  // arrow, TalkBack keeps the arrow, and it can keep the release of Alt too.
  // Flutter then believes Alt is held, until the keyboard's next key says
  // otherwise, and a controller's presses never pass that way. A plain arrow
  // does not match while Alt is held: every press said "Nothing more that
  // way. Still on Unnamed item", while L2 and R2, which send no key, worked.
  group('with a keyboard modifier left held', () {
    tearDown(HardwareKeyboard.instance.clearState);

    for (final held in [
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
    ]) {
      testWidgets('${held.debugName} does not stop the controller',
          (tester) async {
        await pumpPage(tester);
        await simulateKeyDownEvent(held);
        await tester.pump();
        expect(HardwareKeyboard.instance.logicalKeysPressed, contains(held));
        tts.spoken.clear();
        pad.press(GamepadButton.dpadDown);
        await settle(tester);
        final said = tts.spoken.join(' | ');
        expect(said, isNot(contains('Nothing more that way')), reason: said);
        expect(_focusedLabel(), isNotNull, reason: said);
        final first = _focusedLabel();
        pad.press(GamepadButton.dpadDown);
        await settle(tester);
        expect(_focusedLabel(), isNot(first), reason: 'and it goes on moving');
        expect(HardwareKeyboard.instance.logicalKeysPressed, isNot(contains(held)),
            reason: 'let go of, so the next press matches too');
      });
    }

    testWidgets('after TalkBack scrolled the page as well', (tester) async {
      await pumpPage(tester);
      await leaveFocusBehind(tester);
      await simulateKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.pump();
      tts.spoken.clear();
      pad.press(GamepadButton.dpadDown);
      await settle(tester);
      final said = tts.spoken.join(' | ');
      expect(said, isNot(contains('Nothing more that way')), reason: said);
      expect(said, isNot(contains('Unnamed item')), reason: said);
      expect(onScreen(tester, _focusedLabel()!), isTrue);
    });

    // Whatever else keeps an arrow from the app's shortcuts: here the focus
    // is above them. The controller does the move itself.
    testWidgets('and an arrow nothing takes still moves', (tester) async {
      await pumpPage(tester);
      outside.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(outside));
      tts.spoken.clear();
      pad.press(GamepadButton.dpadDown);
      await settle(tester);
      final said = tts.spoken.join(' | ');
      expect(said, isNot(contains('Nothing more that way')), reason: said);
      expect(said, isNot(contains('Unnamed item')), reason: said);
      expect(onScreen(tester, _focusedLabel()!), isTrue);
    });

    testWidgets('a key really held on a keyboard is not a modifier: it stays',
        (tester) async {
      await pumpPage(tester);
      await simulateKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.pump();
      pad.press(GamepadButton.dpadDown);
      await settle(tester);
      expect(HardwareKeyboard.instance.logicalKeysPressed,
          contains(LogicalKeyboardKey.keyA));
    });
  });
}
