import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/messaging/models/composer_presentation.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';

/// The message composer, per accessibility type.
///
/// Messaging was the last learner surface that looked identical for everyone:
/// a text field and a row of chips. For a Deaf learner whose first language is
/// FSL, and for a learner who cannot read yet, a text field is not a channel.
///
/// Pure policy — no Flutter, no Hive.
void main() {
  UserProfile learner(DisabilityType type) => UserProfile(
    id: 'p1',
    name: 'Learner',
    role: UserRole.student,
    disabilityType: type,
    createdAt: DateTime(2026, 8, 15),
  );

  group('every learner keeps a way to say something', () {
    for (final type in DisabilityType.values) {
      test('${type.name} has at least one composer', () {
        final policy = ComposerPresentation.forType(type);
        expect(policy.modes, isNotEmpty);
        expect(policy.maxQuickReplies, greaterThan(0));
      });
    }
  });

  test('a Deaf learner leads with signs', () {
    final policy = ComposerPresentation.forType(DisabilityType.hearing);
    expect(policy.primary, ComposerMode.sign);
    expect(policy.allowsSigns, isTrue);
    expect(
      policy.allowsText,
      isTrue,
      reason: 'FSL leads, but the text field stays available underneath',
    );
  });

  test('a blind learner is offered no picture-only channel', () {
    // A sticker and a sign are both images a screen reader cannot convey, so
    // offering them would be offering nothing.
    final policy = ComposerPresentation.forType(DisabilityType.visual);
    expect(policy.allowsStickers, isFalse);
    expect(policy.allowsSigns, isFalse);
    expect(policy.allowsText, isTrue);
  });

  test('cognitive and multiple lead with pictures and drop free text', () {
    for (final type in [DisabilityType.cognitive, DisabilityType.multiple]) {
      final policy = ComposerPresentation.forType(type);
      expect(policy.primary, ComposerMode.sticker, reason: type.name);
      expect(
        policy.allowsText,
        isFalse,
        reason: 'an empty text field is a demand for composition (${type.name})',
      );
      expect(
        policy.maxQuickReplies,
        lessThanOrEqualTo(4),
        reason: 'a wall of chips is its own barrier (${type.name})',
      );
    }
  });

  test('a motor learner keeps every mode', () {
    // The barrier is input, not comprehension.
    final policy = ComposerPresentation.forType(DisabilityType.motor);
    expect(policy.allowsStickers, isTrue);
    expect(policy.allowsSigns, isTrue);
    expect(policy.allowsText, isTrue);
  });

  test('an educator gets the full composer whatever their own profile', () {
    // A teacher's own accessibility settings must not strip the sign picker
    // they use to reach a Deaf child.
    final teacher = UserProfile(
      id: 't1',
      name: 'Teacher',
      role: UserRole.teacher,
      disabilityType: DisabilityType.visual,
      createdAt: DateTime(2026, 8, 15),
    );

    final policy = ComposerPresentation.forProfile(teacher);
    expect(policy.allowsSigns, isTrue);
    expect(policy.allowsStickers, isTrue);
  });

  test('a learner profile follows its own disability type', () {
    expect(
      ComposerPresentation.forProfile(learner(DisabilityType.hearing)).primary,
      ComposerMode.sign,
    );
    expect(
      ComposerPresentation.forProfile(learner(DisabilityType.cognitive)).primary,
      ComposerMode.sticker,
    );
  });

  test('no profile falls back to the full composer', () {
    expect(ComposerPresentation.forProfile(null).allowsText, isTrue);
  });

  group('MessageType is persisted by index', () {
    test('sign was appended, so existing indices did not move', () {
      // LocalMessage.fromJson reads `MessageType.values[index]`, so reordering
      // this enum would silently rewrite every stored message's type.
      expect(MessageType.values.indexOf(MessageType.text), 0);
      expect(MessageType.values.indexOf(MessageType.encouragement), 1);
      expect(MessageType.values.indexOf(MessageType.sticker), 2);
      expect(MessageType.values.indexOf(MessageType.achievement), 3);
      expect(MessageType.values.indexOf(MessageType.sign), 4);
    });

    test('an unknown future type degrades to text instead of crashing', () {
      final message = LocalMessage.fromJson({
        'id': 'm1',
        'senderId': 's',
        'senderName': 'S',
        'recipientId': 'r',
        'content': 'hello',
        'type': 99,
        'timestamp': DateTime(2026, 8, 15).toIso8601String(),
      });

      expect(message.type, MessageType.text);
      expect(message.content, 'hello');
    });
  });

  test('the sticker set is non-empty and free of duplicates', () {
    // These render on the recipient's device with no download and no unlock
    // state, so the set has to be small, fixed and self-contained.
    expect(MessageStickers.all, isNotEmpty);
    expect(MessageStickers.all.toSet().length, MessageStickers.all.length);
  });
}
