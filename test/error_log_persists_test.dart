import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/utils/error_handler.dart';

/// Every report is kept on the device, the quiet ones too: it is the only
/// record of what went wrong on a tablet with no debugger (the emulator's
/// "Something went wrong", 9 Nov, could only be looked for there).
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('error_log_persists');
    Hive.init(dir.path);
    await Hive.openBox('error_logs');
    await ErrorHandler.clearLogs();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('a loud report and a quiet one are both saved, newest first', () async {
    ErrorHandler.report(StateError('first'), StackTrace.current, 'ErrorLogTest');
    await settle();
    ErrorHandler.report(
      StateError('second'),
      StackTrace.current,
      'CloudMessageRepository.watch.received:silent',
    );
    await settle();

    final logs = ErrorHandler.getErrorLogs();
    expect(logs.map((e) => e.source), [
      'CloudMessageRepository.watch.received:silent',
      'ErrorLogTest',
    ]);
    expect(logs.first.message, contains('second'));
    expect(logs.first.stackTrace, isNotNull, reason: 'where it came from');
  });

  test('two reports at once are both kept', () async {
    // Each report reads the list, adds to it and writes it back; two at once
    // must not leave only one.
    ErrorHandler.report(StateError('a'), null, 'ErrorLogTest');
    ErrorHandler.report(StateError('b'), null, 'ErrorLogTest');
    ErrorHandler.report(StateError('c'), null, 'ErrorLogTest');
    await settle();
    expect(
      ErrorHandler.getErrorLogs().map((e) => e.message).toList(),
      containsAll(['Bad state: a', 'Bad state: b', 'Bad state: c']),
    );
  });

  test('the log keeps the newest 200', () async {
    for (var i = 0; i < 205; i++) {
      ErrorHandler.report(StateError('n$i'), null, 'ErrorLogTest');
    }
    await settle();
    final logs = ErrorHandler.getErrorLogs();
    expect(logs, hasLength(200));
    expect(logs.first.message, 'Bad state: n204');
    expect(logs.last.message, 'Bad state: n5');
  });
}
