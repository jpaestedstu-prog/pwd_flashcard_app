import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/widgets/animated_dialogs.dart';

import 'support/device_matrix.dart';

/// Overflow matrix for the app's generic animated dialogs (the confirm dialog
/// and the custom-content app dialog used across the app). Opened with long
/// title + content at punishing viewports × the maximum font scales, then
/// asserted to lay out without an overflow.

/// Short/narrow viewports a dialog is most likely to burst at.
const _viewports = <DeviceSize>[
  DeviceSize('phone landscape', Size(640, 360), devicePixelRatio: 3.0),
  DeviceSize('7" portrait', Size(600, 960)),
  DeviceSize('10" landscape', Size(1280, 800)),
];

Future<void> _expectDialogNoOverflow(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  for (final device in _viewports) {
    for (final scale in kTextScales) {
      tester.view.physicalSize = device.size * device.devicePixelRatio;
      tester.view.devicePixelRatio = device.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext hostContext;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) {
              hostContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      unawaited(open(hostContext));
      await tester.pumpAndSettle();

      Object? firstError;
      for (Object? e = tester.takeException();
          e != null;
          e = tester.takeException()) {
        firstError ??= e;
      }
      expect(
        firstError,
        isNull,
        reason: 'Dialog overflow at $device, textScale ${scale}x:\n$firstError',
      );

      Navigator.of(hostContext).pop();
      await tester.pumpAndSettle();
    }
  }
  await tester.pumpWidget(const SizedBox.shrink());
}

const _longTitle = 'Are you absolutely sure you want to do this right now?';
const _longBody =
    'This will permanently remove the selected items and cannot be undone. '
    'Please make sure you have reviewed everything before confirming, because '
    'there is no way to recover the data once it has been deleted from the '
    'device and synchronised to the backend.';

void main() {
  testWidgets('showAnimatedConfirmDialog never overflows', (tester) async {
    await _expectDialogNoOverflow(
      tester,
      (context) => showAnimatedConfirmDialog(
        context,
        title: _longTitle,
        content: _longBody,
        emoji: '⚠️',
        isDestructive: true,
        confirmLabel: 'Delete everything now',
        cancelLabel: 'No, keep it',
      ),
    );
  });

  testWidgets('showAnimatedAppDialog never overflows', (tester) async {
    await _expectDialogNoOverflow(
      tester,
      (context) => showAnimatedAppDialog<void>(
        context,
        title: _longTitle,
        emoji: '📋',
        content: const Text(_longBody),
        actions: [
          TextButton(onPressed: () {}, child: const Text('Maybe later today')),
          FilledButton(onPressed: () {}, child: const Text('Got it, thanks')),
        ],
      ),
    );
  });
}
