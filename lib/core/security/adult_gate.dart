import 'dart:math';

import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// How an "is an adult holding the device?" check should be run for one
/// learner.
///
/// Talk Board's board builder can empty a non-verbal learner's vocabulary in
/// two taps, so it needs a speed bump the learner will not walk through by
/// accident. Which speed bump is available depends entirely on what has been
/// set up on this device, which is why the decision is its own pure function
/// rather than a branch inside a dialog.
enum AdultGateMode {
  /// No check at all — this profile is not a supervised learner.
  ///
  /// Players (including Player With Progress) and educators edit their own
  /// board; there is no adult "behind" them to ask, and gating a Teacher out
  /// of the board they are demonstrating would be absurd.
  none,

  /// Verify a linked parent's or teacher's PIN.
  pin,

  /// Ask an arithmetic question the learner is unlikely to answer.
  ///
  /// The fallback when nobody who could be asked has a PIN — a device where
  /// no educator is linked, or one where none of them set a PIN. Deliberately
  /// **not** security: it is the same speed bump AAC apps and OS parental
  /// gates use, and its job is to stop an accidental tap, not a determined
  /// teenager.
  math,
}

/// Decides which check [profile] needs, given the adults linked to them.
///
/// [educators] is the parent/teacher profiles cached on this device for this
/// learner (`unlockingEducatorsProvider`). Only those with a PIN actually set
/// can be verified against, so a list of PIN-less educators is the same as no
/// educators at all.
///
/// The learner's **own** PIN is deliberately never accepted: Student profiles
/// can carry one for profile switching, and a child who knows their own PIN
/// would walk straight through the gate meant to protect them.
AdultGateMode adultGateModeFor({
  required UserProfile? profile,
  required List<UserProfile> educators,
}) {
  if (profile == null) return AdultGateMode.none;
  if (!profile.role.isEnrollableLearner) return AdultGateMode.none;
  final withPin = educators.where((e) => e.hasPinProtection);
  return withPin.isEmpty ? AdultGateMode.math : AdultGateMode.pin;
}

/// The educator profiles whose PIN opens the gate for a learner.
List<UserProfile> adultGateCandidates(List<UserProfile> educators) =>
    educators.where((e) => e.hasPinProtection).toList();

/// True when [pin] matches any candidate. First match wins, like the
/// "Time's Up" lock screen.
///
/// Takes a verifier rather than calling `PinCredentialHelper` directly so the
/// matching rule stays testable without hashing a PIN in every case.
bool adultGateAcceptsPin({
  required String pin,
  required List<UserProfile> candidates,
  required bool Function(UserProfile profile, String pin) verify,
}) {
  if (pin.length < 4) return false;
  for (final candidate in candidates) {
    if (verify(candidate, pin)) return true;
  }
  return false;
}

/// An arithmetic question for the [AdultGateMode.math] fallback.
///
/// Multiplication of two numbers in [_minFactor]…[_maxFactor]: past the point
/// where a young learner answers it by counting, and still something an adult
/// does in their head without reaching for a calculator.
class AdultMathChallenge {
  final int a;
  final int b;

  const AdultMathChallenge(this.a, this.b);

  static const int _minFactor = 4;
  static const int _maxFactor = 12;

  int get answer => a * b;

  String get question => '$a × $b';

  /// True when [input] is the answer, ignoring surrounding whitespace.
  ///
  /// Anything unparseable is simply wrong — an empty box or a stray letter
  /// must not be treated as a pass.
  bool accepts(String input) => int.tryParse(input.trim()) == answer;

  /// A fresh question.
  ///
  /// Factors of 0, 1 and 2 are excluded by the range: "×1" and "×2" are
  /// exactly the products a six-year-old does know, and one of those turning
  /// up would hand the learner the gate.
  factory AdultMathChallenge.random([Random? random]) {
    final rng = random ?? Random();
    int factor() => _minFactor + rng.nextInt(_maxFactor - _minFactor + 1);
    return AdultMathChallenge(factor(), factor());
  }
}
