import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/security/adult_gate.dart';
import 'package:pwdpwdpwd/core/security/pin_credential_helper.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/providers/adult_gate_grace_provider.dart';

/// The adult gate's decision layer. Pure — no Flutter, no Hive.

UserProfile _profile(UserRole role, {String id = 'p'}) => UserProfile(
      id: id,
      name: role.name,
      role: role,
      createdAt: DateTime(2026),
    );

/// An educator with a real hashed PIN, built through the same helper the app
/// uses so the verification path under test is the production one.
UserProfile _educatorWithPin(String pin, {String id = 'edu'}) =>
    PinCredentialHelper.applyPin(_profile(UserRole.parent, id: id), pin)
        .profile;

void main() {
  group('adultGateModeFor', () {
    test('supervised learners with a PIN-holding adult get the PIN gate', () {
      for (final role in [UserRole.student, UserRole.child]) {
        expect(
          adultGateModeFor(
            profile: _profile(role),
            educators: [_educatorWithPin('1234')],
          ),
          AdultGateMode.pin,
          reason: '$role',
        );
      }
    });

    test('a learner with no linked adult falls back to the question', () {
      // A device where nobody has joined a class or home group still has to
      // let a parent edit the board — and still should not let the learner.
      expect(
        adultGateModeFor(profile: _profile(UserRole.student), educators: const []),
        AdultGateMode.math,
      );
    });

    test('linked adults who never set a PIN are the same as none', () {
      // There is nothing to verify against, so offering a PIN box would be a
      // door with no key.
      expect(
        adultGateModeFor(
          profile: _profile(UserRole.child),
          educators: [_profile(UserRole.parent, id: 'edu')],
        ),
        AdultGateMode.math,
      );
    });

    test('one PIN-holder among several is enough', () {
      expect(
        adultGateModeFor(
          profile: _profile(UserRole.student),
          educators: [
            _profile(UserRole.teacher, id: 'a'),
            _educatorWithPin('4321', id: 'b'),
          ],
        ),
        AdultGateMode.pin,
      );
    });

    test('players and educators are never gated', () {
      // A Player edits their own board and has no adult behind them; gating a
      // teacher out of the board they are demonstrating would be absurd.
      for (final role in [UserRole.player, UserRole.teacher, UserRole.parent]) {
        expect(
          adultGateModeFor(
            profile: _profile(role),
            educators: [_educatorWithPin('1234')],
          ),
          AdultGateMode.none,
          reason: '$role',
        );
      }
    });

    test('no profile is not gated', () {
      expect(
        adultGateModeFor(profile: null, educators: const []),
        AdultGateMode.none,
      );
    });
  });

  group('adultGateCandidates', () {
    test('keeps only the adults who can actually be verified', () {
      final withPin = _educatorWithPin('1234', id: 'b');
      final candidates = adultGateCandidates([
        _profile(UserRole.teacher, id: 'a'),
        withPin,
      ]);
      expect(candidates.map((e) => e.id), ['b']);
    });
  });

  group('adultGateAcceptsPin', () {
    final edu = _educatorWithPin('1234');

    test('accepts the right PIN', () {
      expect(
        adultGateAcceptsPin(
          pin: '1234',
          candidates: [edu],
          verify: PinCredentialHelper.verify,
        ),
        isTrue,
      );
    });

    test('rejects the wrong PIN', () {
      expect(
        adultGateAcceptsPin(
          pin: '9999',
          candidates: [edu],
          verify: PinCredentialHelper.verify,
        ),
        isFalse,
      );
    });

    test('any linked adult PIN opens it — first match wins', () {
      final other = _educatorWithPin('5678', id: 'edu2');
      for (final pin in ['1234', '5678']) {
        expect(
          adultGateAcceptsPin(
            pin: pin,
            candidates: [edu, other],
            verify: PinCredentialHelper.verify,
          ),
          isTrue,
          reason: pin,
        );
      }
    });

    test('a short PIN never even reaches the verifier', () {
      var called = false;
      expect(
        adultGateAcceptsPin(
          pin: '12',
          candidates: [edu],
          verify: (p, pin) {
            called = true;
            return true;
          },
        ),
        isFalse,
      );
      expect(called, isFalse);
    });

    test('no candidates means nothing is accepted', () {
      expect(
        adultGateAcceptsPin(
          pin: '1234',
          candidates: const [],
          verify: (p, pin) => true,
        ),
        isFalse,
      );
    });

    test("the learner's own PIN is not a way in", () {
      // Student profiles can carry a PIN for profile switching. A child who
      // knows theirs must not walk through the gate meant to protect them —
      // which holds because only educators are ever passed as candidates.
      final learner = PinCredentialHelper.applyPin(
        _profile(UserRole.student, id: 'kid'),
        '1111',
      ).profile;
      expect(
        adultGateCandidates([edu]).map((e) => e.id),
        isNot(contains(learner.id)),
      );
      expect(
        adultGateAcceptsPin(
          pin: '1111',
          candidates: adultGateCandidates([edu]),
          verify: PinCredentialHelper.verify,
        ),
        isFalse,
      );
    });
  });

  group('AdultMathChallenge', () {
    test('accepts the product and nothing else', () {
      const c = AdultMathChallenge(7, 8);
      expect(c.answer, 56);
      expect(c.accepts('56'), isTrue);
      expect(c.accepts(' 56 '), isTrue);
      expect(c.accepts('57'), isFalse);
      expect(c.accepts('5'), isFalse);
    });

    test('unparseable input is wrong, not a pass', () {
      const c = AdultMathChallenge(7, 8);
      // An empty box must never count as an answer.
      expect(c.accepts(''), isFalse);
      expect(c.accepts('   '), isFalse);
      expect(c.accepts('fifty six'), isFalse);
      expect(c.accepts('56a'), isFalse);
    });

    test('never generates a factor a young learner finds easy', () {
      // ×1 and ×2 are exactly the products a six-year-old does know; one
      // turning up would hand them the gate.
      for (var seed = 0; seed < 300; seed++) {
        final c = AdultMathChallenge.random(Random(seed));
        expect(c.a, greaterThanOrEqualTo(4), reason: 'seed $seed');
        expect(c.b, greaterThanOrEqualTo(4), reason: 'seed $seed');
        expect(c.a, lessThanOrEqualTo(12), reason: 'seed $seed');
        expect(c.b, lessThanOrEqualTo(12), reason: 'seed $seed');
      }
    });

    test('the question renders both factors', () {
      const c = AdultMathChallenge(4, 9);
      expect(c.question, contains('4'));
      expect(c.question, contains('9'));
    });

    test('varies across seeds, so it is not one fixed sum', () {
      final seen = {
        for (var seed = 0; seed < 40; seed++)
          AdultMathChallenge.random(Random(seed)).answer,
      };
      expect(seen.length, greaterThan(5));
    });
  });

  group('adult gate grace', () {
    late ProviderContainer container;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 4, 1, 9);
      container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(adultGateGraceProvider.notifier).now = () => now;
    });

    AdultGateGraceNotifier grace() =>
        container.read(adultGateGraceProvider.notifier);

    test('nothing is granted to begin with', () {
      expect(grace().isGranted('kid'), isFalse);
    });

    test('a grant lasts for the grace window and then lapses', () {
      grace().grant('kid');
      expect(grace().isGranted('kid'), isTrue);

      now = now.add(kAdultGateGrace - const Duration(seconds: 1));
      expect(grace().isGranted('kid'), isTrue);

      now = now.add(const Duration(seconds: 2));
      expect(grace().isGranted('kid'), isFalse);
    });

    test('a grant is per profile', () {
      // Handing the tablet to a sibling must not hand over the grace too.
      grace().grant('kid');
      expect(grace().isGranted('other-kid'), isFalse);
    });

    test('revoke ends it immediately', () {
      grace().grant('kid');
      grace().revoke('kid');
      expect(grace().isGranted('kid'), isFalse);
    });

    test('revoking one profile leaves the others alone', () {
      grace().grant('a');
      grace().grant('b');
      grace().revoke('a');
      expect(grace().isGranted('a'), isFalse);
      expect(grace().isGranted('b'), isTrue);
    });

    test('a fresh container starts ungated — the grace is not persisted', () {
      // In memory on purpose: a child picking the tablet back up after a
      // restart must not walk straight into the builder.
      grace().grant('kid');
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      expect(fresh.read(adultGateGraceProvider.notifier).isGranted('kid'),
          isFalse);
    });
  });
}
