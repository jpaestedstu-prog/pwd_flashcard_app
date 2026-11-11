import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/messaging/models/messaging_models.dart';
import 'package:pwdpwdpwd/features/messaging/providers/messaging_providers.dart';
import 'package:pwdpwdpwd/features/messaging/services/cloud_message_repository.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// A guest has no inbox in the cloud, and asking for one is refused.
///
/// The messages listener outlives the screen that started it, so it followed
/// a switch from a learner (Jules, on the Villaon) to a guest, asked the cloud
/// for the guest's messages, was refused, and "Something went wrong" covered
/// the guest's home (9 Nov).
UserProfile _profile(String id, UserRole role, {bool guest = false}) =>
    UserProfile(
      id: id,
      name: id,
      role: role,
      isGuestPlayer: guest,
      createdAt: DateTime(2026),
    );

class _Switchable extends ProfileNotifier {
  _Switchable(this._first);
  final UserProfile _first;

  @override
  UserProfile? build() => _first;

  void switchTo(UserProfile next) => state = next;
}

void main() {
  late List<String> asked;
  setUp(() {
    asked = [];
    watchInbox = (id) {
      asked.add(id);
      return Stream.value(const <LocalMessage>[]);
    };
  });
  tearDown(() => watchInbox = CloudMessageRepository.instance.watchMessagesFor);

  test('a guest has no inbox; every other profile does', () {
    expect(profileHasInbox(_profile('g', UserRole.player, guest: true)), isFalse);
    for (final role in [
      UserRole.student,
      UserRole.child,
      UserRole.player,
      UserRole.teacher,
      UserRole.parent,
    ]) {
      expect(profileHasInbox(_profile('x', role)), isTrue, reason: role.name);
    }
  });

  test('a guest never asks the cloud for messages', () async {
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(
          () => _Switchable(_profile('guest', UserRole.player, guest: true)),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(activeProfileMessagesProvider.future), isEmpty);
    expect(asked, isEmpty);
  });

  test('switching from a learner to a guest stops asking', () async {
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(
          () => _Switchable(_profile('jules', UserRole.player)),
        ),
      ],
    );
    addTearDown(container.dispose);
    // The learner's home keeps the inbox open.
    final sub = container.listen(activeProfileMessagesProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(activeProfileMessagesProvider.future);
    expect(asked, ['jules']);

    (container.read(profileProvider.notifier) as _Switchable).switchTo(
      _profile('guest', UserRole.player, guest: true),
    );
    await container.read(activeProfileMessagesProvider.future);
    expect(asked, ['jules'], reason: 'nothing asked for the guest');
  });
}
