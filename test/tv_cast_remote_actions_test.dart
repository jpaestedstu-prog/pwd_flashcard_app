import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';
import 'package:pwdpwdpwd/features/tv_cast/providers/tv_cast_provider.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_asset_bridge.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
    id: 'remote-educator',
    name: 'Test Teacher',
    role: UserRole.teacher,
    createdAt: DateTime(2026),
  );
}

/// The real notifier, seeded with a running cast.
class _RunningCast extends TvCastSessionNotifier {
  _RunningCast(this.seed);

  final TvCastSession seed;

  @override
  TvCastSession build() {
    super.build();
    return seed;
  }
}

/// What each key on a TV remote does to the cast, through the same notifier
/// methods the phone's own buttons call. The server side (which keys are
/// accepted, the educator's on/off switch) is in tv_cast_server_test.dart and
/// the TV side (which key sends what) in tools/tv_cast_render_check.js.
void main() {
  // The photo / clip manifests load from the asset bundle, which needs the
  // binding even in a plain test().
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./build/test_cache/tv_cast_remote_actions');
    for (final name in const <String>[
      'classroom_members', 'classrooms', 'error_logs', 'home_group_members',
      'home_groups', 'profiles', 'progress', 'sessions', 'settings',
      'sync_queue',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    await FlashcardPhotoService.load();
    await ActionClipService.load();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  (ProviderContainer, TvCastSessionNotifier) cast(TvCastSession seed) {
    final container = ProviderContainer(overrides: [
      profileProvider.overrideWith(_StubProfile.new),
      tvCastSessionProvider.overrideWith(() => _RunningCast(seed)),
    ]);
    addTearDown(container.dispose);
    return (container, container.read(tvCastSessionProvider.notifier));
  }

  /// The first card (category, index) whose media satisfies [test].
  (FlashcardCategory, int) cardWhere(bool Function(Flashcard) test) {
    for (final cat in FlashcardCategory.values) {
      final cards = SeedData.getByCategory(cat);
      for (var i = 0; i < cards.length; i++) {
        if (test(cards[i])) return (cat, i);
      }
    }
    fail('no seeded card matches');
  }

  TvCastSession onCard(FlashcardCategory cat, int index) => TvCastSession(
    mode: CastMode.flashcards,
    category: cat,
    slideIndex: index,
    isServerRunning: true,
  );

  test('◀ ▶ step through the deck', () {
    final (cat, i) = cardWhere((_) => true);
    final (c, n) = cast(onCard(cat, i));
    n.handleRemoteAction('next');
    expect(c.read(tvCastSessionProvider).slideIndex, i + 1);
    n.handleRemoteAction('prev');
    expect(c.read(tvCastSessionProvider).slideIndex, i);
  });

  test('OK flips a card to its photo, and Back flips it back', () {
    final (cat, i) = cardWhere(TvCastAssetBridge.hasPhoto);
    final (c, n) = cast(onCard(cat, i));
    n.handleRemoteAction('flip');
    expect(c.read(tvCastSessionProvider).cardFlipped, isTrue);
    n.handleRemoteAction('back');
    expect(c.read(tvCastSessionProvider).cardFlipped, isFalse);
  });

  test('OK does nothing on a card with no photo to flip to', () {
    final (cat, i) = cardWhere((card) => !TvCastAssetBridge.hasPhoto(card));
    final (c, n) = cast(onCard(cat, i));
    final before = c.read(tvCastSessionProvider).revision;
    n.handleRemoteAction('flip');
    expect(c.read(tvCastSessionProvider).cardFlipped, isFalse);
    expect(c.read(tvCastSessionProvider).revision, before);
  });

  test('▼ plays the card\'s "Show Me" clip; Back closes it', () {
    final (cat, i) = cardWhere(TvCastAssetBridge.hasActionClip);
    final (c, n) = cast(onCard(cat, i));
    n.handleRemoteAction('showme');
    expect(c.read(tvCastSessionProvider).showMeActive, isTrue);
    expect(
      c.read(tvCastSessionProvider).isPaused,
      isTrue,
      reason: 'the slideshow holds while the clip plays, as from the phone',
    );
    n.handleRemoteAction('back');
    expect(c.read(tvCastSessionProvider).showMeActive, isFalse);
  });

  test('play and pause keys only ever play or pause', () {
    final (cat, i) = cardWhere((_) => true);
    final (c, n) = cast(onCard(cat, i));
    n.handleRemoteAction('pause');
    expect(c.read(tvCastSessionProvider).isPaused, isTrue);
    n.handleRemoteAction('pause');
    expect(c.read(tvCastSessionProvider).isPaused, isTrue);
    n.handleRemoteAction('play');
    expect(c.read(tvCastSessionProvider).isPaused, isFalse);
    n.handleRemoteAction('play');
    expect(c.read(tvCastSessionProvider).isPaused, isFalse);
    n.handleRemoteAction('playpause');
    expect(c.read(tvCastSessionProvider).isPaused, isTrue);
  });

  test('▲ asks the TV to say the word again (both languages)', () {
    final (cat, i) = cardWhere((_) => true);
    final (c, n) = cast(onCard(cat, i));
    final before = c.read(tvCastSessionProvider).ttsReplayNonce;
    n.handleRemoteAction('replay');
    final s = c.read(tvCastSessionProvider);
    expect(s.ttsReplayNonce, before + 1);
    expect(s.ttsReplayLang, 'both');
  });

  test('in a story OK flips the picture and ▼ opens the page in FSL', () {
    for (final story in SeedStories.all) {
      for (var p = 0; p < story.sentencesEn.length; p++) {
        if (TvCastAssetBridge.storyImagePair(story, p) == null) continue;
        final (c, n) = cast(TvCastSession(
          mode: CastMode.story,
          storyId: story.id,
          storyPageIndex: p,
          isServerRunning: true,
        ));
        n.handleRemoteAction('flip');
        expect(c.read(tvCastSessionProvider).storyImageFlipped, isTrue);
        n.handleRemoteAction('back');
        expect(c.read(tvCastSessionProvider).storyImageFlipped, isFalse);
        if (TvCastAssetBridge.storyFslUrl(story, p) != null) {
          n.handleRemoteAction('showme');
          expect(c.read(tvCastSessionProvider).storyFslActive, isTrue);
          n.handleRemoteAction('back');
          expect(c.read(tvCastSessionProvider).storyFslActive, isFalse);
        }
        return;
      }
    }
    fail('no story page with a picture pair');
  });

  test('unknown or out-of-mode keys change nothing', () {
    final (c, n) = cast(const TvCastSession(
      mode: CastMode.progress,
      isServerRunning: true,
    ));
    final before = c.read(tvCastSessionProvider).revision;
    for (final a in ['flip', 'showme', 'back', 'nonsense']) {
      n.handleRemoteAction(a);
    }
    expect(c.read(tvCastSessionProvider).revision, before);
  });
}
