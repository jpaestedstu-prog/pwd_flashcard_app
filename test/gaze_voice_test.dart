import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/gaze_control/logic/voice_commands.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_action.dart';
import 'package:pwdpwdpwd/features/gaze_control/models/gaze_models.dart';

void _noop() {}

GazeAction _a(GazeZone zone, String label, {bool enabled = true}) => GazeAction(
      zone: zone,
      label: label,
      icon: Icons.abc_rounded,
      color: Colors.teal,
      enabled: enabled,
      onSelect: _noop,
    );

void main() {
  // A typical flashcard-viewer action set.
  final actions = [
    _a(GazeZone.left, 'Prev'),
    _a(GazeZone.right, 'Next'),
    _a(GazeZone.up, 'Hear'),
    _a(GazeZone.down, 'Flip'),
  ];

  VoiceCommandResult r(String s) => resolveVoiceCommand(s, actions);

  group('resolveVoiceCommand', () {
    test('empty / gibberish → none', () {
      expect(r('').intent, VoiceIntent.none);
      expect(r('banana split').intent, VoiceIntent.none);
    });

    test('directional words map to the action on that edge', () {
      expect(r('next'), _action(1)); // right
      expect(r('previous'), _action(0)); // left
      expect(r('back'), _action(0)); // "back" = previous item
      expect(r('up'), _action(2));
      expect(r('down'), _action(3));
    });

    test('label words match their action', () {
      expect(r('flip'), _action(3));
      expect(r('hear').intent, VoiceIntent.action); // up / Hear
      expect(r('flip the card'), _action(3)); // substring
    });

    test('fuzzy match tolerates small mis-hearings', () {
      // "flop" → "flip" (edit distance 1, label length ≥ 4).
      expect(r('flop'), _action(3));
    });

    test('scroll commands beat the bare directional word', () {
      expect(r('scroll down').intent, VoiceIntent.scrollDown);
      expect(r('scroll up').intent, VoiceIntent.scrollUp);
    });

    test('leaving the screen is distinct from "back" (previous)', () {
      expect(r('go back').intent, VoiceIntent.goBack);
      expect(r('exit').intent, VoiceIntent.goBack);
      expect(r('close').intent, VoiceIntent.goBack);
      // plain "back" is still previous-item, not navigation.
      expect(r('back'), _action(0));
    });

    test('a disabled action is not selectable by voice', () {
      final disabled = [
        _a(GazeZone.left, 'Prev', enabled: false),
        _a(GazeZone.right, 'Next'),
      ];
      expect(resolveVoiceCommand('previous', disabled).intent, VoiceIntent.none);
      expect(resolveVoiceCommand('next', disabled).intent, VoiceIntent.action);
    });

    test('Filipino directional words work', () {
      expect(r('susunod'), _action(1)); // next
      expect(r('kaliwa'), _action(0)); // left
    });
  });
}

Matcher _action(int index) => predicate<VoiceCommandResult>(
      (res) => res.intent == VoiceIntent.action && res.actionIndex == index,
      'action #$index',
    );
