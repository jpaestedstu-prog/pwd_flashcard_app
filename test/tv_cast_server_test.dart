import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/services/action_clip_service.dart';
import 'package:pwdpwdpwd/core/services/flashcard_photo_service.dart';
import 'package:pwdpwdpwd/core/services/fsl_assets_service.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/local/seed_stories.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
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

  /// GETs [path] (relative to the origin, already including any code prefix)
  /// and returns the status + body, without asserting either.
  Future<({int status, String body})> get(int port, String path) {
    return HttpOverrides.runWithHttpOverrides(() async {
      final client = HttpClient();
      try {
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        return (status: resp.statusCode, body: body);
      } finally {
        client.close(force: true);
      }
    }, _RealHttpOverrides());
  }

  /// Boots a server for [session] and returns it plus its bound port. The
  /// caller reaches content through `s.basePath` — every route is behind the
  /// per-cast session code.
  Future<(TvCastServer, int)> boot(TvCastSession session) async {
    final s = TvCastServer(getSession: () => session);
    server = s;
    return (s, await s.start());
  }

  Future<Map<String, dynamic>> fetchState(TvCastSession session) async {
    final (s, port) = await boot(session);
    final res = await get(port, '${s.basePath}/api/state');
    expect(res.status, 200);
    return json.decode(res.body) as Map<String, dynamic>;
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

    // "Show Me" action clip — dog is hosted as a direct Cloudinary .gif, so the
    // TV renders it as an image and the server serves it as image/gif.
    final clip = slide['clip'] as Map<String, dynamic>;
    expect(clip['available'], isTrue);
    expect(clip['url'], '/api/clip/$catIdx/dog');
    expect(clip['isGif'], isTrue);
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

  // ─── Live activity media ────────────────────────────────
  // A card-backed live question used to reach the TV as a bare emoji. For
  // `fslSign` that made the shared screen useless: the sign *is* the question,
  // so a Deaf learner was asked to identify something nobody could see.

  Flashcard cardWithFsl() {
    for (final c in SeedData.allFlashcards) {
      if (FslAssetsService.hasAnyVideoSource(c)) return c;
    }
    fail('expected at least one seeded card with an FSL clip');
  }

  group('live activity media', () {
    setUp(() async => FslAssetsService.load());

    test('an fslSign question carries the sign clip and a stable id', () async {
      final card = cardWithFsl();
      final activity = LiveActivity.fslSign(
        flashcardId: card.id,
        options: const ['Dog', 'Cat', 'Bird'],
      );
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.live,
          liveActivity: activity,
          isServerRunning: true,
        ),
      );

      final live = state['live'] as Map<String, dynamic>;
      final a = live['activity'] as Map<String, dynamic>;

      // The id is what lets the TV tell "new question" from "one more answer",
      // so it can update the counter without restarting the clip.
      expect(a['id'], activity.id);
      expect(a['type'], 'fslSign');

      final video = a['video'] as Map<String, dynamic>;
      expect(video['available'], isTrue);
      expect(
        video['url'],
        '/api/video/${card.category.index}/'
        '${card.wordEnglish.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}',
      );

      // Resolved words/emoji still ride along for the fallback rendering.
      expect(a['word'], card.wordEnglish);
      expect(a['emoji'], isNotEmpty);
      // The answer is never sent — the TV is a shared screen.
      expect(a.containsKey('correctIndex'), isFalse);
      expect(a.containsKey('correct_index'), isFalse);
    });

    test('a pictureChoice question carries the real photo', () async {
      final cards = SeedData.getByCategory(FlashcardCategory.animals);
      final dog = cards.firstWhere((c) => c.wordEnglish == 'Dog');
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.live,
          liveActivity: LiveActivity.pictureChoice(
            flashcardId: dog.id,
            options: const ['Dog', 'Cat'],
            correctIndex: 0,
          ),
          isServerRunning: true,
        ),
      );
      final a = (state['live'] as Map)['activity'] as Map<String, dynamic>;
      final photo = a['photo'] as Map<String, dynamic>;
      expect(photo['available'], isTrue);
      expect(photo['url'], '/api/image/${FlashcardCategory.animals.index}/dog');
    });

    test('a text-only question carries no media block', () async {
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.live,
          liveActivity: LiveActivity.trueFalse(
            statement: 'A dog says meow.',
            correctValue: false,
          ),
          isServerRunning: true,
        ),
      );
      final a = (state['live'] as Map)['activity'] as Map<String, dynamic>;
      expect(a['isTrueFalse'], isTrue);
      expect(a.containsKey('video'), isFalse);
      expect(a.containsKey('photo'), isFalse);
    });
  });

  // ─── Progress views ─────────────────────────────────────

  group('progress views', () {
    const rows = [
      TvCastProgressRow(
        rank: 1,
        name: 'Ana',
        wordsLearned: 6,
        streakDays: 3,
        stars: 28,
      ),
    ];
    const summary = TvCastClassSummary(
      learnerCount: 2,
      wordsTotal: 9,
      starsTotal: 44,
      activeToday: 1,
      bestStreak: 3,
      rows: [
        TvCastProgressRow(
          rank: 0,
          name: 'Ana',
          wordsLearned: 6,
          streakDays: 3,
          stars: 28,
        ),
        TvCastProgressRow(
          rank: 0,
          name: 'Ben',
          wordsLearned: 3,
          streakDays: 1,
          stars: 16,
        ),
      ],
    );

    test('defaults to the non-competitive class view', () async {
      final state = await fetchState(
        const TvCastSession(mode: CastMode.progress, isServerRunning: true),
      );
      // A wall-sized ranking of children should be an explicit choice.
      expect(state['progressView'], 'classWins');
    });

    test('both datasets ship on every poll so switching is instant', () async {
      final state = await fetchState(
        const TvCastSession(
          mode: CastMode.progress,
          isServerRunning: true,
          progress: rows,
          classSummary: summary,
          castProgressView: CastProgressView.leaderboard,
        ),
      );

      expect(state['progressView'], 'leaderboard');
      expect((state['progress'] as List).length, 1);

      final cs = state['classSummary'] as Map<String, dynamic>;
      expect(cs['learners'], 2);
      expect(cs['words'], 9);
      expect(cs['stars'], 44);
      expect(cs['activeToday'], 1);
      expect(cs['bestStreak'], 3);

      final csRows = cs['rows'] as List;
      expect(csRows.length, 2);
      // Alphabetical and rank-free — nothing in the payload implies an order.
      expect((csRows[0] as Map)['name'], 'Ana');
      expect((csRows[1] as Map)['name'], 'Ben');
      expect(csRows.every((r) => (r as Map)['rank'] == 0), isTrue);
    });
  });

  // ─── Story completion ───────────────────────────────────

  group('story completion', () {
    test('storyDone is false while pages remain', () async {
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.story,
          storyId: SeedStories.all.first.id,
          isServerRunning: true,
        ),
      );
      expect(state['storyDone'], isFalse);
      // The page block is still sent, so Back can return to it.
      expect(state['story'], isNotNull);
    });

    test('storyDone flows through with the page still available', () async {
      final story = SeedStories.all.first;
      final last = story.sentencesEn.length - 1;
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.story,
          storyId: story.id,
          storyPageIndex: last,
          storyFinished: true,
          isServerRunning: true,
        ),
      );
      expect(state['storyDone'], isTrue);
      // The TV needs the title + page count to render the closing screen, and
      // the page itself so stepping Back repaints instantly.
      final s = state['story'] as Map<String, dynamic>;
      expect(s['titleEn'], story.titleEn);
      expect(s['totalPages'], story.sentencesEn.length);
    });
  });

  // ─── Cast session history (stored form) ─────────────────
  // Teacher-facing only: deliberately NOT in the research export, which is
  // scoped to the Student population by design.

  group('cast session summary round-trip', () {
    test('survives a save/load cycle', () {
      final started = DateTime(2026, 8, 7, 11, 36);
      const original = TvCastSessionSummary(
        duration: Duration(minutes: 7, seconds: 30),
        modesUsed: [CastMode.flashcards, CastMode.live],
        cardsShown: 42,
        storyPagesShown: 3,
        liveQuestionsPushed: 8,
        liveAnswers: 47,
        peakViewers: 2,
      );
      final restored = TvCastSessionSummary.fromJson(
        TvCastSessionSummary(
          startedAt: started,
          duration: original.duration,
          modesUsed: original.modesUsed,
          cardsShown: original.cardsShown,
          storyPagesShown: original.storyPagesShown,
          liveQuestionsPushed: original.liveQuestionsPushed,
          liveAnswers: original.liveAnswers,
          peakViewers: original.peakViewers,
        ).toJson(),
      );

      expect(restored.startedAt, started);
      expect(restored.duration, const Duration(minutes: 7, seconds: 30));
      expect(restored.modesUsed, [CastMode.flashcards, CastMode.live]);
      expect(restored.cardsShown, 42);
      expect(restored.storyPagesShown, 3);
      expect(restored.liveQuestionsPushed, 8);
      expect(restored.liveAnswers, 47);
      expect(restored.peakViewers, 2);
    });

    test('modes are stored by name, so the enum can grow', () {
      final json = const TvCastSessionSummary(
        duration: Duration(minutes: 1),
        modesUsed: [CastMode.fslVideo],
      ).toJson();
      expect(json['modes'], ['fslVideo']);
    });

    test('a record from an older build loads instead of throwing', () {
      // Missing keys, a mode this build doesn't know, and a numeric type the
      // encoder wouldn't produce — history must degrade, never crash the list.
      final restored = TvCastSessionSummary.fromJson({
        'startedAt': 'not-a-date',
        'modes': ['flashcards', 'holodeck'],
        'cards': 7.0,
      });
      expect(restored.startedAt, isNull);
      expect(restored.duration, Duration.zero);
      expect(restored.modesUsed, [CastMode.flashcards]);
      expect(restored.cardsShown, 7);
      expect(restored.peakViewers, 0);
    });

    test('hasContent gates the summary dialog on a real lesson', () {
      // Started and immediately stopped — nothing worth showing.
      expect(
        const TvCastSessionSummary(duration: Duration(seconds: 4)).hasContent,
        isFalse,
      );
      // A minute of casting, or anything actually shown, counts.
      expect(
        const TvCastSessionSummary(duration: Duration(minutes: 2)).hasContent,
        isTrue,
      );
      expect(
        const TvCastSessionSummary(
          duration: Duration(seconds: 20),
          cardsShown: 3,
        ).hasContent,
        isTrue,
      );
    });
  });

  // ─── Display accessibility + lesson timer + TV remote ───

  group('display preferences', () {
    test('defaults are normal size, both languages, remote on', () async {
      final state = await fetchState(
        const TvCastSession(isServerRunning: true),
      );
      expect(state['textSize'], 'normal');
      expect(state['lang'], 'both');
      expect(state['remote'], isTrue);
    });

    test('text size and language reach the TV as short wire names', () async {
      final state = await fetchState(
        const TvCastSession(
          mode: CastMode.flashcards,
          isServerRunning: true,
          castTextSize: CastTextSize.extraLarge,
          castLanguage: CastLanguage.filipino,
        ),
      );
      expect(state['textSize'], 'xl');
      expect(state['lang'], 'fil');
    });
  });

  group('lesson timer', () {
    test('absent when no timer is set', () async {
      final state = await fetchState(
        const TvCastSession(isServerRunning: true),
      );
      expect(state['timer'], isNull);
    });

    test('secondsLeft is derived per poll, not stored', () async {
      // The deadline is 90 s out, so the payload must say ~90 without the
      // phone ever having ticked — that is what lets the TV re-sync on every
      // poll while the revision stays put (a bump would rebuild the stage).
      final (s, port) = await boot(
        TvCastSession(
          mode: CastMode.flashcards,
          isServerRunning: true,
          timerEndsAt: DateTime.now().add(const Duration(seconds: 90)),
          timerTotalSeconds: 120,
          timerLabel: 'Clean up',
        ),
      );
      final first = json.decode(
        (await get(port, '${s.basePath}/api/state')).body,
      ) as Map<String, dynamic>;
      final t = first['timer'] as Map<String, dynamic>;
      expect(t['secondsLeft'], inInclusiveRange(88, 90));
      expect(t['total'], 120);
      expect(t['paused'], isFalse);
      expect(t['label'], 'Clean up');
      final rev = first['rev'];

      await Future<void>.delayed(const Duration(seconds: 2));
      final second = json.decode(
        (await get(port, '${s.basePath}/api/state')).body,
      ) as Map<String, dynamic>;
      // Clock moved…
      expect(
        (second['timer'] as Map)['secondsLeft'],
        lessThan(t['secondsLeft'] as int),
      );
      // …but the revision did not, so the TV never rebuilt its stage.
      expect(second['rev'], rev);
    });

    test('a paused timer freezes and reports it', () async {
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.flashcards,
          isServerRunning: true,
          timerEndsAt: DateTime.now().add(const Duration(seconds: 90)),
          timerTotalSeconds: 120,
          timerPausedSecondsLeft: 42,
        ),
      );
      final t = state['timer'] as Map<String, dynamic>;
      expect(t['secondsLeft'], 42, reason: 'paused clock must not drift');
      expect(t['paused'], isTrue);
    });

    test('an expired timer clamps at zero rather than counting up', () async {
      final state = await fetchState(
        TvCastSession(
          mode: CastMode.flashcards,
          isServerRunning: true,
          timerEndsAt: DateTime.now().subtract(const Duration(minutes: 5)),
          timerTotalSeconds: 60,
        ),
      );
      expect((state['timer'] as Map)['secondsLeft'], 0);
    });
  });

  group('TV remote endpoint', () {
    test('a valid action reaches the notifier', () async {
      final actions = <String>[];
      final s = TvCastServer(
        // tvRemoteEnabled defaults to true — the "on" case.
        getSession: () => const TvCastSession(isServerRunning: true),
        onRemoteAction: actions.add,
      );
      server = s;
      final port = await s.start();

      for (final a in ['next', 'prev', 'playpause']) {
        final res = await get(port, '${s.basePath}/api/nudge?a=$a');
        expect(res.status, 200, reason: 'action $a should be accepted');
      }
      expect(actions, ['next', 'prev', 'playpause']);
    });

    test('an unknown action is rejected and never dispatched', () async {
      final actions = <String>[];
      final s = TvCastServer(
        getSession: () => const TvCastSession(isServerRunning: true),
        onRemoteAction: actions.add,
      );
      server = s;
      final port = await s.start();

      for (final a in ['', 'stop', 'setMode', 'next;prev']) {
        final res = await get(port, '${s.basePath}/api/nudge?a=$a');
        expect(res.status, 400, reason: '"$a" should be rejected');
      }
      expect(actions, isEmpty);
    });

    test('the educator switch is enforced on the phone, not the TV', () async {
      final actions = <String>[];
      final s = TvCastServer(
        // Remote turned off in the educator's settings.
        getSession: () => const TvCastSession(
          isServerRunning: true,
          tvRemoteEnabled: false,
        ),
        onRemoteAction: actions.add,
      );
      server = s;
      final port = await s.start();

      final res = await get(port, '${s.basePath}/api/nudge?a=next');
      expect(res.status, 403);
      expect(
        actions,
        isEmpty,
        reason: 'an already-loaded TV page must not keep driving the lesson',
      );
    });

    test('the nudge endpoint is behind the session code like everything else',
        () async {
      final actions = <String>[];
      final s = TvCastServer(
        getSession: () => const TvCastSession(isServerRunning: true),
        onRemoteAction: actions.add,
      );
      server = s;
      final port = await s.start();

      expect((await get(port, '/api/nudge?a=next')).status, 404);
      expect((await get(port, '/c/AAAAA/api/nudge?a=next')).status, 404);
      expect(actions, isEmpty);
    });
  });

  // ─── Session-code gate ──────────────────────────────────
  // The server binds 0.0.0.0, so anything it serves is reachable by every
  // device on the Wi-Fi. /api/state carries learner names + progress, so the
  // whole surface sits behind a per-cast code that the QR/URL carries.

  group('session code gate', () {
    const roster = TvCastSession(
      mode: CastMode.progress,
      isServerRunning: true,
      progress: [
        TvCastProgressRow(
          rank: 1,
          name: 'Deaf Student',
          wordsLearned: 3,
          streakDays: 1,
          stars: 23,
        ),
      ],
    );

    test('mints a fresh unambiguous code per start, exposed as a path prefix',
        () async {
      final (s, _) = await boot(roster);
      final token = s.sessionToken;
      expect(token, isNotNull);
      expect(token!.length, 5);
      // No characters a teacher could misread aloud to someone on a remote.
      expect(RegExp(r'^[ACDEFGHJKLMNPQRTUVWXY34679]+$').hasMatch(token), isTrue);
      expect(s.basePath, '/c/$token');
    });

    test('a second cast gets a different code', () async {
      final (a, _) = await boot(roster);
      final first = a.sessionToken;
      await a.stop();
      expect(a.sessionToken, isNull, reason: 'code must not outlive the cast');

      final (b, _) = await boot(roster);
      expect(b.sessionToken, isNotNull);
      expect(b.sessionToken, isNot(first));
    });

    test('serves content under the right code', () async {
      final (s, port) = await boot(roster);
      for (final path in ['', '/', '/api/state', '/style.css', '/app.js']) {
        final res = await get(port, '${s.basePath}$path');
        expect(res.status, 200, reason: 'expected 200 for ${s.basePath}$path');
      }
    });

    test('leaks no learner data without the code', () async {
      final (s, port) = await boot(roster);
      final wrong = s.sessionToken == 'AAAAA' ? 'CCCCC' : 'AAAAA';

      for (final path in [
        '/',
        '/api/state',
        '/index.html',
        '/style.css',
        '/c/$wrong/api/state',
        '/c//api/state',
        '/api/image/0/dog',
      ]) {
        final res = await get(port, path);
        expect(res.status, 404, reason: 'expected 404 for $path');
        expect(
          res.body,
          isNot(contains('Deaf Student')),
          reason: '$path must not expose the roster',
        );
        expect(res.body, contains('Ask your teacher'));
      }
    });

    test('a wrong code is indistinguishable from the bare origin', () async {
      final (s, port) = await boot(roster);
      final wrong = s.sessionToken == 'AAAAA' ? 'CCCCC' : 'AAAAA';
      final bare = await get(port, '/');
      final bad = await get(port, '/c/$wrong/api/state');
      expect(bad.status, bare.status);
      expect(bad.body, bare.body);
    });

    test('code matching is case-insensitive but not a prefix match', () async {
      final (s, port) = await boot(roster);
      final token = s.sessionToken!;

      // Some TV browsers lowercase a typed URL — that must still connect.
      final lower = await get(port, '/c/${token.toLowerCase()}/api/state');
      expect(lower.status, 200);

      // But a truncated or extended code must not.
      for (final bad in [
        token.substring(0, token.length - 1),
        '${token}X',
      ]) {
        final res = await get(port, '/c/$bad/api/state');
        expect(res.status, 404, reason: '"$bad" must not authenticate');
      }
    });

    test('counts rejected codes so the UI can warn about probing', () async {
      final (s, port) = await boot(roster);
      expect(s.rejectedCodeCount, 0);
      await get(port, '/api/state');
      await get(port, '/c/AAAAA/api/state');
      expect(s.rejectedCodeCount, 2);
    });

    test('healthz stays open and reveals nothing', () async {
      final (_, port) = await boot(roster);
      final res = await get(port, '/healthz');
      expect(res.status, 200);
      expect(res.body, 'ok');
    });

    test('index.html points the TV at the code-scoped assets', () async {
      final (s, port) = await boot(roster);
      final res = await get(port, s.basePath);
      expect(res.status, 200);
      // The TV must load its assets — and build its /api URLs — inside the
      // namespace, or the very first poll 404s.
      expect(res.body, contains('href="${s.basePath}/style.css"'));
      expect(res.body, contains('src="${s.basePath}/app.js"'));
      expect(res.body, contains('window.CAST_BASE="${s.basePath}"'));
      expect(res.body, isNot(contains('href="/style.css"')));
      expect(res.body, isNot(contains('src="/app.js"')));
    });

    test('no wildcard CORS header on any response', () async {
      final (s, port) = await boot(roster);
      await HttpOverrides.runWithHttpOverrides(() async {
        final client = HttpClient();
        try {
          final req = await client.getUrl(
            Uri.parse('http://127.0.0.1:$port${s.basePath}/api/state'),
          );
          final resp = await req.close();
          await resp.drain<void>();
          // A `*` here would let any page on the school Wi-Fi read the roster
          // cross-origin from JavaScript.
          expect(resp.headers.value('access-control-allow-origin'), isNull);
          expect(resp.headers.value('x-content-type-options'), 'nosniff');
        } finally {
          client.close(force: true);
        }
      }, _RealHttpOverrides());
    });
  });
}
