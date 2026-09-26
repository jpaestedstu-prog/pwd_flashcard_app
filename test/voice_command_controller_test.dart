import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/accessibility/stt_service.dart';
import 'package:pwdpwdpwd/features/gaze_control/controllers/voice_command_controller.dart';

/// Scriptable stand-in for the platform recogniser: tests emit partial/final
/// results and end sessions, mirroring the real engine's behaviour — including
/// its habit of killing a session (error_no_match / error_speech_timeout)
/// without ever delivering a final result.
class _FakeStt extends SttService {
  bool listening = false;
  int sessions = 0;

  /// When true every new session dies instantly with no results — the
  /// `error_client` rejection storm some recognisers produce.
  bool autoReject = false;

  /// When true `startListening` never completes — the platform never
  /// confirming the session, as seen mid-storm on real devices.
  bool hangOnStart = false;

  /// When true, [reset] clears [autoReject] — models a wedged recogniser that
  /// only a full recreate brings back.
  bool recoverOnReset = false;

  int cancels = 0;
  int resets = 0;

  void Function(String text, bool isFinal)? _onResult;

  @override
  Future<bool> init() async => true;

  @override
  bool get isListening => listening;

  @override
  Future<void> startListening({
    required String locale,
    required void Function(String text, bool isFinal) onResult,
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
    bool partialResults = true,
  }) {
    sessions++;
    if (hangOnStart) return Completer<void>().future;
    _onResult = onResult;
    listening = !autoReject;
    return Future.value();
  }

  @override
  Future<void> cancel() async {
    cancels++;
    listening = false;
  }

  @override
  Future<void> reset() async {
    resets++;
    listening = false;
    if (recoverOnReset) autoReject = false;
  }

  void emit(String text, {required bool isFinal}) =>
      _onResult?.call(text, isFinal);

  /// The platform ended the session (final delivered, or an error killed it).
  void endSession() => listening = false;
}

void main() {
  // Runs [body] with a started controller inside a fake clock. Commands land
  // in the returned list.
  void run(
    void Function(FakeAsync fake, _FakeStt stt, List<String> fired) body,
  ) {
    fakeAsync((fake) {
      final stt = _FakeStt();
      final fired = <String>[];
      final controller = VoiceCommandController(
        stt: stt,
        locale: 'en-US',
        onCommand: fired.add,
      );
      controller.start();
      fake.flushMicrotasks();
      expect(stt.listening, isTrue, reason: 'controller must arm the mic');
      body(fake, stt, fired);
      controller.dispose();
    });
  }

  group('VoiceCommandController dispatch', () {
    test('a stable partial fires without waiting for the final result', () {
      run((fake, stt, fired) {
        stt.emit('left', isFinal: false);
        expect(fired, isEmpty); // not yet stable
        fake.elapse(const Duration(milliseconds: 700));
        expect(fired, ['left']);
      });
    });

    test('the final result after a dispatched partial is not fired twice', () {
      run((fake, stt, fired) {
        stt.emit('left', isFinal: false);
        fake.elapse(const Duration(milliseconds: 700));
        stt.emit('left', isFinal: true);
        fake.flushMicrotasks();
        expect(fired, ['left']);
      });
    });

    test('an accumulating transcript fires only the new words', () {
      run((fake, stt, fired) {
        stt.emit('left', isFinal: false);
        fake.elapse(const Duration(milliseconds: 700));
        stt.emit('left right', isFinal: false);
        fake.elapse(const Duration(milliseconds: 700));
        expect(fired, ['left', 'right']);
      });
    });

    test('a re-spelled hypothesis ("lift" → "left") does not double-fire', () {
      run((fake, stt, fired) {
        stt.emit('lift', isFinal: false);
        fake.elapse(const Duration(milliseconds: 700));
        expect(fired, ['lift']);
        stt.emit('left', isFinal: true); // recogniser corrected itself
        fake.flushMicrotasks();
        expect(fired, ['lift']);
      });
    });

    test('a session killed without a final still delivers its last partial',
        () {
      run((fake, stt, fired) {
        stt.emit('kanan', isFinal: false);
        fake.elapse(const Duration(milliseconds: 300)); // not yet stable
        stt.endSession(); // error_no_match — no final ever arrives
        fake.elapse(const Duration(milliseconds: 400)); // flush tick
        expect(fired, ['kanan']);
        fake.elapse(const Duration(milliseconds: 400)); // settle → re-arm
        expect(stt.sessions, 2, reason: 'the loop must re-arm a new session');
      });
    });

    test('a final with no prior partial fires immediately', () {
      run((fake, stt, fired) {
        stt.emit('down', isFinal: true);
        expect(fired, ['down']);
      });
    });

    test('repeating the same command in the next session fires again', () {
      run((fake, stt, fired) {
        stt.emit('left', isFinal: true);
        stt.endSession();
        fake.elapse(const Duration(milliseconds: 800)); // settle → re-arm
        expect(stt.sessions, 2);
        stt.emit('left', isFinal: true);
        expect(fired, ['left', 'left']);
      });
    });

    test('a recogniser that rejects every session is retried with backoff, '
        'not thrashed', () {
      run((fake, stt, fired) {
        // From now on each session dies instantly with no result
        // (error_client storm).
        stt.autoReject = true;
        stt.endSession();
        fake.elapse(const Duration(seconds: 4));
        // Plain 400 ms re-arming would burn ~10 sessions in 4 s; the
        // exponential backoff keeps retrying, but gently.
        expect(stt.sessions, inInclusiveRange(2, 4));
        expect(fired, isEmpty);
      });
    });

    test('a healthy session re-arms after one settle tick, without backoff',
        () {
      run((fake, stt, fired) {
        stt.emit('left', isFinal: true);
        stt.endSession();
        // One tick to note the end (plus the settle the platform needs —
        // re-arming instantly provokes error_client), one tick to re-arm.
        fake.elapse(const Duration(milliseconds: 800));
        expect(stt.sessions, 2, reason: 'no backoff after a healthy session');
      });
    });

    test('a listen start that never confirms cannot wedge the loop', () {
      run((fake, stt, fired) {
        // The current session dies; the next start hangs forever.
        stt.hangOnStart = true;
        stt.endSession();
        fake.elapse(const Duration(seconds: 6)); // start + 4 s timeout
        expect(stt.cancels, greaterThan(0),
            reason: 'the half-open session must be reset');
        // The recogniser recovers — the loop must still be alive to retry.
        stt.hangOnStart = false;
        stt.autoReject = false;
        fake.elapse(const Duration(seconds: 4));
        expect(stt.listening, isTrue,
            reason: 'voice must recover once the platform does');
      });
    });

    test('a persistent rejection storm recreates the recogniser to recover',
        () {
      run((fake, stt, fired) {
        // Every session is rejected until the recogniser is fully recreated —
        // re-listening alone can never recover it.
        stt.autoReject = true;
        stt.recoverOnReset = true;
        stt.endSession();
        fake.elapse(const Duration(seconds: 30));
        expect(stt.resets, greaterThan(0),
            reason: 'sustained rejections must trigger a recogniser reset');
        expect(stt.listening, isTrue,
            reason: 'voice must be listening again after the reset recovers it');
      });
    });

    test('a zombie session holding the mic without results is cancelled', () {
      run((fake, stt, fired) {
        // The armed session just sits there: no results, never ends.
        fake.elapse(const Duration(seconds: 16));
        expect(stt.cancels, greaterThan(0));
        // After the cancel the loop re-arms a fresh session.
        fake.elapse(const Duration(seconds: 1));
        expect(stt.sessions, greaterThanOrEqualTo(2));
        expect(stt.listening, isTrue);
      });
    });
  });

  group('speak-to-type lease', () {
    // Messages' speak-to-type needs the one recogniser for a whole sentence,
    // while a gaze scope's command loop keeps it busy in bursts. The lease
    // makes the loop stand down and come back — without it, the loop killed
    // the dictation as a "zombie session" and could fire the message's words
    // as commands.
    void runLeased(
      void Function(FakeAsync fake, _FakeStt stt, MicLease lease,
              VoiceCommandController voice, List<String> fired)
          body,
    ) {
      fakeAsync((fake) {
        final stt = _FakeStt();
        final lease = MicLease();
        final fired = <String>[];
        final voice = VoiceCommandController(
          stt: stt,
          locale: 'en-US',
          onCommand: fired.add,
          lease: lease,
        );
        voice.start();
        fake.flushMicrotasks();
        expect(stt.listening, isTrue);
        body(fake, stt, lease, voice, fired);
        voice.dispose();
      });
    }

    test('taking the lease stops the command session at once', () {
      runLeased((fake, stt, lease, voice, fired) {
        final before = stt.cancels;
        lease.acquire();
        expect(stt.cancels, before + 1);
        expect(stt.listening, isFalse);
        expect(voice.pausedForDictation, isTrue);
        expect(voice.isListening, isFalse);
      });
    });

    test('a half-heard phrase is dropped, never fired, when dictation starts',
        () {
      runLeased((fake, stt, lease, voice, fired) {
        stt.emit('send', isFinal: false);
        lease.acquire();
        fake.elapse(const Duration(seconds: 2));
        expect(fired, isEmpty);
      });
    });

    test('while held, the loop neither re-arms nor kills the dictation', () {
      runLeased((fake, stt, lease, voice, fired) {
        lease.acquire();
        final sessions = stt.sessions;
        final cancels = stt.cancels;
        // The dictation's own session: long, and silent for a while.
        stt.listening = true;
        fake.elapse(const Duration(seconds: 30));
        expect(stt.sessions, sessions, reason: 'no command session started');
        expect(stt.cancels, cancels,
            reason: 'the dictation must not be cancelled as a zombie');
        expect(stt.listening, isTrue);
      });
    });

    test('releasing the lease brings voice commands back', () {
      runLeased((fake, stt, lease, voice, fired) {
        lease.acquire();
        stt.listening = false;
        final sessions = stt.sessions;
        lease.release();
        expect(voice.pausedForDictation, isFalse);
        fake.elapse(const Duration(seconds: 2));
        expect(stt.sessions, greaterThan(sessions));
        expect(stt.listening, isTrue);
        stt.emit('next', isFinal: true);
        expect(fired, ['next']);
      });
    });

    test('the lease counts holders, so a nested release keeps it', () {
      final lease = MicLease();
      var notified = 0;
      lease.addListener(() => notified++);
      lease.acquire();
      lease.acquire();
      lease.release();
      expect(lease.isHeld, isTrue);
      lease.release();
      expect(lease.isHeld, isFalse);
      lease.release(); // extra release is harmless
      expect(lease.isHeld, isFalse);
      expect(notified, 2);
    });

    test('disposing a paused loop does not cancel the dictation', () {
      fakeAsync((fake) {
        final stt = _FakeStt();
        final lease = MicLease();
        final voice = VoiceCommandController(
          stt: stt,
          locale: 'en-US',
          onCommand: (_) {},
          lease: lease,
        );
        voice.start();
        fake.flushMicrotasks();
        lease.acquire();
        stt.listening = true; // the dictation
        final cancels = stt.cancels;
        voice.dispose();
        expect(stt.cancels, cancels);
        expect(stt.listening, isTrue);
      });
    });
  });
}
