import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';
import 'package:pwdpwdpwd/features/tv_cast/services/tv_cast_server.dart';

/// Restores the real `dart:io` HttpClient inside a zone. `TestWidgetsFlutter
/// Binding` installs an override that fails every request with a 400 (to stop
/// tests hitting the network) — but here we deliberately talk to our own
/// loopback server, so we opt back into the real client for that call.
class _RealHttpOverrides extends HttpOverrides {}

/// End-to-end check of the TV Cast HTTP server's `/api/state` contract for the
/// Stories cartoon ⇄ real-life flip picture: the per-page `story.image` block
/// (with its `/api/story-image/...` URLs) the TV-side `app.js` reads to paint
/// both pictures, and the `storyImageFlipped` flag the phone's "Tap to Flip
/// Animation (Cartoon ↔ Picture)" button toggles. Hermetic — `/api/state` only
/// reads the bundled seed data (no picture download happens here), mirroring the
/// flashcard photo-flip contract in `tv_cast_server_test.dart`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TvCastServer? server;

  tearDown(() async {
    await server?.stop();
    server = null;
  });

  Future<Map<String, dynamic>> fetchState(TvCastSession session) async {
    final s = TvCastServer(getSession: () => session);
    server = s;
    final port = await s.start();
    return HttpOverrides.runWithHttpOverrides(() async {
      final client = HttpClient();
      try {
        // Every route is behind the per-cast session code — see the gate tests
        // in tv_cast_server_test.dart. The URLs *inside* the payload stay
        // root-relative; the TV prefixes them itself (app.js `scopeMediaUrls`).
        final req = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port${s.basePath}/api/state'),
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

  /// First (story, page) that ships a cartoon ⇄ real flip picture.
  ({String id, int page}) storyWithImage() {
    for (final s in SeedStories.all) {
      for (var p = 0; p < s.sentencesEn.length; p++) {
        if (s.imageForSentence(p) != null) return (id: s.id, page: p);
      }
    }
    fail('expected at least one story page with a flip picture');
  }

  test('A Day at the Farm is the canary page that ships a flip picture', () {
    final target = storyWithImage();
    expect(target.id, 's_a01');
    expect(target.page, 0);
  });

  test('story state carries the image block + storyImageFlipped flag', () async {
    final target = storyWithImage();
    final state = await fetchState(
      TvCastSession(
        mode: CastMode.story,
        storyId: target.id,
        storyPageIndex: target.page,
        isServerRunning: true,
      ),
    );

    // Cartoon shown first → flag defaults off.
    expect(state['storyImageFlipped'], isFalse);

    final story = state['story'] as Map<String, dynamic>;
    final image = story['image'] as Map<String, dynamic>;
    expect(image['available'], isTrue);
    expect(
      image['cartoonUrl'],
      '/api/story-image/${target.id}/${target.page}/cartoon',
    );
    expect(
      image['realUrl'],
      '/api/story-image/${target.id}/${target.page}/real',
    );
  });

  test('storyImageFlipped:true flows through to the payload', () async {
    final target = storyWithImage();
    final state = await fetchState(
      TvCastSession(
        mode: CastMode.story,
        storyId: target.id,
        storyPageIndex: target.page,
        storyImageFlipped: true,
        isServerRunning: true,
      ),
    );
    expect(state['storyImageFlipped'], isTrue);
    // The image block is unchanged by the flip — only which face the TV shows.
    final story = state['story'] as Map<String, dynamic>;
    expect((story['image'] as Map)['available'], isTrue);
  });

  test('a page without a picture omits the image block (emoji fallback)',
      () async {
    // A story whose first page has no flip picture → no `image` block, emoji
    // page on the TV, flag still present but off.
    String? withoutImage;
    for (final s in SeedStories.all) {
      if (s.imageForSentence(0) == null) {
        withoutImage = s.id;
        break;
      }
    }
    expect(
      withoutImage,
      isNotNull,
      reason: 'expected a story without a page-0 flip picture',
    );

    final state = await fetchState(
      TvCastSession(
        mode: CastMode.story,
        storyId: withoutImage,
        isServerRunning: true,
      ),
    );
    expect(state['storyImageFlipped'], isFalse);
    final story = state['story'] as Map<String, dynamic>;
    expect(story.containsKey('image'), isFalse);
    // The emoji is still carried for the classic emoji story page.
    expect((story['emoji'] as String).isNotEmpty, isTrue);
  });
}
