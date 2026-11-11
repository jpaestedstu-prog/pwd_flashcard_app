import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gamepad/logic/browser_gamepad_reader.dart';
import 'package:pwdpwdpwd/features/gamepad/models/gamepad_button.dart';

/// A controller in the web app: what the browser reports (a snapshot of every
/// button's value and every stick's position) turned into the presses and
/// releases the Android bridge sends.

List<double> _buttons({Map<int, double> on = const {}}) =>
    [for (var i = 0; i < 17; i++) on[i] ?? 0.0];

String _show(List<GamepadEvent> events) => [
      for (final e in events) '${e.button.name} ${e.pressed ? 'down' : 'up'}',
    ].join(', ');

void main() {
  test('nothing pressed, nothing said', () {
    final r = BrowserGamepadReader();
    expect(r.read(0, buttons: _buttons(), axes: [0, 0, 0, 0]), isEmpty);
    expect(r.read(0, buttons: _buttons(), axes: [0, 0, 0, 0]), isEmpty);
  });

  test('the standard layout: every button by its index', () {
    final expected = {
      0: GamepadButton.a,
      1: GamepadButton.b,
      2: GamepadButton.x,
      3: GamepadButton.y,
      4: GamepadButton.l1,
      5: GamepadButton.r1,
      6: GamepadButton.l2,
      7: GamepadButton.r2,
      8: GamepadButton.select,
      9: GamepadButton.start,
      10: GamepadButton.leftStickClick,
      11: GamepadButton.rightStickClick,
      12: GamepadButton.dpadUp,
      13: GamepadButton.dpadDown,
      14: GamepadButton.dpadLeft,
      15: GamepadButton.dpadRight,
      16: GamepadButton.mode,
    };
    for (final entry in expected.entries) {
      final r = BrowserGamepadReader();
      final down = r.read(0, buttons: _buttons(on: {entry.key: 1}), axes: []);
      expect(_show(down), '${entry.value.name} down', reason: '${entry.key}');
      final up = r.read(0, buttons: _buttons(), axes: []);
      expect(_show(up), '${entry.value.name} up', reason: '${entry.key}');
    }
  });

  test('a held button is one press, not one per snapshot', () {
    final r = BrowserGamepadReader();
    final held = _buttons(on: {15: 1});
    expect(_show(r.read(0, buttons: held, axes: [])), 'dpadRight down');
    for (var i = 0; i < 60; i++) {
      expect(r.read(0, buttons: held, axes: []), isEmpty);
    }
    expect(_show(r.read(0, buttons: _buttons(), axes: [])), 'dpadRight up');
  });

  test('a trigger counts past the press line, and lets go below the release',
      () {
    final r = BrowserGamepadReader();
    expect(r.read(0, buttons: _buttons(on: {7: 0.5}), axes: []), isEmpty);
    expect(_show(r.read(0, buttons: _buttons(on: {7: 0.7}), axes: [])),
        'r2 down');
    // Resting near the line does not chatter.
    expect(r.read(0, buttons: _buttons(on: {7: 0.45}), axes: []), isEmpty);
    expect(r.read(0, buttons: _buttons(on: {7: 0.55}), axes: []), isEmpty);
    expect(_show(r.read(0, buttons: _buttons(on: {7: 0.3}), axes: [])),
        'r2 up');
  });

  test('the sticks, both ways on both axes', () {
    final r = BrowserGamepadReader();
    expect(_show(r.read(0, buttons: _buttons(), axes: [-0.9, 0, 0, 0])),
        'leftStickLeft down');
    // Swung across: left is let go before right is pressed.
    expect(_show(r.read(0, buttons: _buttons(), axes: [0.9, 0, 0, 0])),
        'leftStickLeft up, leftStickRight down');
    expect(_show(r.read(0, buttons: _buttons(), axes: [0, 0.8, 0, 0])),
        'leftStickRight up, leftStickDown down');
    expect(_show(r.read(0, buttons: _buttons(), axes: [0, 0, 0, -0.7])),
        'leftStickDown up, rightStickUp down');
    expect(_show(r.read(0, buttons: _buttons(), axes: [0, 0, 0.7, 0])),
        'rightStickUp up, rightStickRight down');
  });

  test('a stick resting in its dead zone says nothing', () {
    final r = BrowserGamepadReader();
    for (final v in [0.05, -0.2, 0.39, -0.55, 0.59]) {
      expect(r.read(0, buttons: _buttons(), axes: [v, v, v, v]), isEmpty,
          reason: '$v');
    }
  });

  test('two controllers are told apart', () {
    final r = BrowserGamepadReader();
    final one = r.read(0, buttons: _buttons(on: {0: 1}), axes: []);
    final two = r.read(1, buttons: _buttons(on: {1: 1}), axes: []);
    expect(one.single.deviceId, 0);
    expect(two.single.deviceId, 1);
    expect(r.read(0, buttons: _buttons(on: {0: 1}), axes: []), isEmpty);
  });

  test('a controller that goes lets go of what it held', () {
    final r = BrowserGamepadReader();
    r.read(0, buttons: _buttons(on: {0: 1, 12: 1}), axes: [0, -1]);
    expect(_show(r.forget(0)), 'dpadUp up, a up, leftStickUp up');
    expect(r.forget(0), isEmpty);
    expect(r.devices, isEmpty);
  });

  test('a short report (fewer buttons) is read as far as it goes', () {
    final r = BrowserGamepadReader();
    expect(_show(r.read(0, buttons: [1, 0, 0, 0], axes: [])), 'a down');
  });

  test('the browser\'s name for a controller, without its brackets', () {
    expect(
      browserGamepadName('Xbox 360 Controller (XInput STANDARD GAMEPAD)'),
      'Xbox 360 Controller',
    );
    expect(
      browserGamepadName(
          'GamePadPlus V3 (STANDARD GAMEPAD Vendor: 1949 Product: 0402)'),
      'GamePadPlus V3',
    );
    expect(browserGamepadName('054c-09cc-Wireless Controller'),
        '054c-09cc-Wireless Controller');
    expect(browserGamepadName(''), 'Gamepad');
  });
}
