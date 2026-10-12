import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/data/repository.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// Every change to a field the cloud copy carries is pushed for a
/// classroom-linked learner, not only saved on the tablet.
///
/// Found on the tablet (12 October 2026): stars from daily rewards and the
/// daily challenge, words, category progress and shop spending were saved
/// locally and waited for the next finished game. A learner who earned only
/// that way stayed weeks behind in the cloud (35 stars on the tablet, 25 in
/// the cloud), which is what a teacher's dashboard shows and what a profile
/// restored onto a new tablet starts from.

class _Recorder implements DataRepository {
  final pushes = <LearningProgress>[];

  @override
  Future<void> saveProgress(LearningProgress progress) async =>
      pushes.add(progress);

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class _Learner extends ProfileNotifier {
  _Learner(this.id, this.classroomId);
  final String id;
  final String? classroomId;

  @override
  UserProfile? build() => UserProfile(
        id: id,
        name: 'Learner',
        role: UserRole.student,
        classroomId: classroomId,
        createdAt: DateTime(2026),
      );
}

void main() {
  setUpAll(() async {
    final dir = Directory('./build/test_cache/progress_cloud_push');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Hive.init(dir.path);
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
  });

  tearDownAll(() async {
    try {
      await Hive.deleteFromDisk().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  ({ProgressNotifier notifier, _Recorder repo}) learner(
    String id, {
    String? classroomId = 'class-1',
  }) {
    final repo = _Recorder();
    final container = ProviderContainer(
      overrides: [
        profileProvider.overrideWith(() => _Learner(id, classroomId)),
        repositoryProvider.overrideWithValue(repo),
        progressRemoteChangesProvider.overrideWith(
          (ref) => const Stream<String>.empty(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (notifier: container.read(progressProvider.notifier), repo: repo);
  }

  test('a reward, a word and a category reach the cloud', () {
    final (:notifier, :repo) = learner('push-1');

    notifier.addStars(5);
    expect(repo.pushes.last.totalStars, 5);
    notifier.addWordsLearned(1);
    expect(repo.pushes.last.wordsLearned, 1);
    notifier.updateCategoryProgress('Animals', 0.4);
    expect(repo.pushes.last.categoryProgress['Animals'], 0.4);
    expect(repo.pushes, hasLength(3));
  });

  test('spending in the shop reaches the cloud', () {
    final (:notifier, :repo) = learner('push-2');

    notifier.addStars(10);
    expect(notifier.spendStars(4), isTrue);
    expect(repo.pushes.last.spentStars, 4);
  });

  test('a learner in no class stays on the tablet, as before', () {
    final (:notifier, :repo) = learner('push-3', classroomId: null);

    notifier.addStars(5);
    expect(repo.pushes, isEmpty);
  });
}
