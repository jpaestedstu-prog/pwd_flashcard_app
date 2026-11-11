import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';
import 'package:pwdpwdpwd/widgets/error_boundary.dart';

/// The live listeners behind every Home's Messages tile never put "Something
/// went wrong" in front of a learner.
///
/// A Home starts them as it opens (the inbox, friend requests, friends and a
/// parent's approvals), with nothing asked for. On a failure each keeps
/// showing what it last had and starts again when the profile is next
/// opened, so a refusal is nothing a learner can act on, yet it raised the
/// generic message: a guest's refused inbox on the Villaon, and possibly the
/// one on the emulator's test Student on opening the profile (9 Nov). They are
/// logged, not shown; what a learner does (sending a message) still reports
/// where they can see it.
void main() {
  /// Where each listener reports, as `file: source`.
  const listeners = <String, List<String>>{
    'lib/features/messaging/services/cloud_message_repository.dart': [
      'CloudMessageRepository.watch.received',
      'CloudMessageRepository.watch.sent',
    ],
    'lib/features/messaging/services/friend_service.dart': [
      'FriendService.watchIncomingRequests',
      'FriendService.watchFriends.a',
      'FriendService.watchFriends.b',
      'FriendService.watchApprovals',
    ],
  };

  test('each listener reports under its quiet name, and only that', () {
    for (final MapEntry(key: path, value: sources) in listeners.entries) {
      final code = File(path).readAsStringSync();
      for (final source in sources) {
        expect(
          code.contains("'$source:silent'"),
          isTrue,
          reason: '$path: the listener reports as $source:silent',
        );
        expect(
          code.contains("'$source'"),
          isFalse,
          reason: '$path: "$source" (without :silent) raises the message',
        );
        expect(
          ErrorHandler.isSilentSource('$source:silent'),
          isTrue,
          reason: '$source:silent is registered as silent',
        );
      }
    }
  });

  Widget app() => MaterialApp(
    builder: (context, child) =>
        ErrorBoundary(child: child ?? const SizedBox.shrink()),
    home: const Scaffold(body: Center(child: Text('A learner Home'))),
  );

  final message = find.textContaining('Something went wrong');

  testWidgets('a listener refused by the cloud shows nothing', (tester) async {
    await tester.pumpWidget(app());
    final refused = StateError(
      '[cloud_firestore/permission-denied] The caller does not have '
      'permission to execute the specified operation.',
    );
    for (final sources in listeners.values) {
      for (final source in sources) {
        ErrorHandler.report(refused, null, '$source:silent');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));
        expect(message, findsNothing, reason: '$source raised the message');
      }
    }

    // What a learner does still tells them it failed.
    ErrorHandler.report(refused, null, 'CloudMessageRepository.sendMessage');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    expect(message, findsOneWidget, reason: 'a failed send is shown');
    await tester.pump(errorSnackBarDuration + const Duration(seconds: 1));
  });
}
