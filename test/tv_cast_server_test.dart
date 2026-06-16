import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_server.dart';

/// Restores the real `dart:io` HttpClient inside a zone. `TestWidgetsFlutter
/// Binding` installs an override that fails every request with a 400 (to stop
/// tests hitting the network) — but here we deliberately talk to our own
/// loopback server, so we opt back into the real client for that call.
class _RealHttpOverrides extends HttpOverrides {}

/// End-to-end check of the TV Cast HTTP server's `/api/state` contract for the
/// updated flashcards feature: the `tapOnly` / `showMe` flags and the per-slide
/// `photo` / `clip` blocks the TV-side `app.js` reads to drive the tap-to-flip
/// photo and the "Show Me" action clip. Hermetic — `/api/state` only reads the
/// bundled manifests (no photo/clip download happens here).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TvCastServer? server;

  setUp(() async {
    FlashcardPhotoService.reset();
    ActionClipService.reset();
    await FlashcardPhotoService.load();
    await ActionClipService.load();
  });

  tearDown(() async {
    await server?.stop();
    server = null;
    FlashcardPhotoService.reset();
    ActionClipService.reset();
  });

  Future<Map<String, dynamic>> fetchState(TvCastSession session) async {
    final s = TvCastServer(getSession: () => session);
    server = s;
    final port = await s.start();
    return HttpOverrides.runWithHttpOverrides(() async {
      final client = HttpClient();
      try {
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/api/state'),
        );
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        expect(resp.statusCode, 200);
        return json.decode(body) as Map<String, dynamic>;
      } finally {
        client.close(force: true);
      }
    }, _RealHttpOverrides());
  }

  int dogIndex() {
    final cards = SeedData.getByCategory(FlashcardCategory.animals);
    final i = cards.indexWhere((c) => c.wordEnglish.toLowerCase() == 'dog');
    expect(i, greaterThanOrEqualTo(0), reason: 'expected a "dog" Animals card');
    return i;
  }

  test('flashcards state carries tapOnly/showMe + slide photo + clip', () async {
    final idx = dogIndex();
    final state = await fetchState(
      TvCastSession(
        mode: CastMode.flashcards,
        category: FlashcardCategory.animals,
        slideIndex: idx,
        isServerRunning: true,
      ),
    );

    // Photo-flip feature on by default; the card starts on the emoji face and
    // Show Me is off until the teacher taps it.
    expect(state['tapOnly'], isTrue);
    expect(state['flipped'], isFalse);
    expect(state['showMe'], isFalse);

    final slide = state['slide'] as Map<String, dynamic>;
    final catIdx = FlashcardCategory.animals.index;

    // Real photo (tap-to-flip source) — same manifest the in-app cards use.
    final photo = slide['photo'] as Map<String, dynamic>;
    expect(photo['available'], isTrue);
    expect(photo['url'], '/api/image/$catIdx/dog');

    // "Show Me" action clip — dog is hosted on Streamable (a video, not a GIF).
    final clip = slide['clip'] as Map<String, dynamic>;
    expect(clip['available'], isTrue);
    expect(clip['url'], '/api/clip/$catIdx/dog');
    expect(clip['isGif'], isFalse);
  });

  test('tapOnly:false + flipped + showMe:true flow through to the payload',
      () async {
    final idx = dogIndex();
    final state = await fetchState(
      TvCastSession(
        mode: CastMode.flashcards,
        category: FlashcardCategory.animals,
        slideIndex: idx,
        flipTapOnly: false,
        cardFlipped: true,
        showMeActive: true,
        isServerRunning: true,
      ),
    );
    expect(state['tapOnly'], isFalse);
    expect(state['flipped'], isTrue);
    expect(state['showMe'], isTrue);
  });

  // Story page with an FSL clip → the state carries the storyVideo block the
  // TV-side renderStoryFsl reads, plus the storyFsl flag the "Watch in FSL"
  // button toggles. Mirrors the flashcard slide.clip / showMe pair above.
  ({String id, int page}) storyWithFsl() {
    for (final s in SeedStories.all) {
      for (var p = 0; p < s.sentencesEn.length; p++) {
        if (s.fslForSentence(p) != null) return (id: s.id, page: p);
      }
    }
    fail('expected at least one story page with an FSL clip');
  }

  test('story state carries storyVideo + storyFsl when the page has a clip',
      () async {
    final target = storyWithFsl();
    final state = await fetchState(
      TvCastSession(
        mode: CastMode.story,
        storyId: target.id,
        storyPageIndex: target.page,
        storyFslActive: true,
        isServerRunning: true,
      ),
    );

    expect(state['storyFsl'], isTrue);
    final storyVideo = state['storyVideo'] as Map<String, dynamic>;
    expect(storyVideo['available'], isTrue);
    expect(
      storyVideo['url'],
      '/api/story-video/${target.id}/${target.page}',
    );
  });

  test('storyFsl defaults off and storyVideo is absent without a clip',
      () async {
    // A story whose first page has no FSL clip → no storyVideo block, flag off.
    String? withoutFsl;
    for (final s in SeedStories.all) {
      if (s.fslForSentence(0) == null) {
        withoutFsl = s.id;
        break;
      }
    }
    expect(withoutFsl, isNotNull,
        reason: 'expected a story without a page-0 FSL clip');

    final state = await fetchState(
      TvCastSession(
        mode: CastMode.story,
        storyId: withoutFsl,
        isServerRunning: true,
      ),
    );
    expect(state['storyFsl'], isFalse);
    expect(state.containsKey('storyVideo'), isFalse);
  });
}
