import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/live_session/models/live_session_models.dart';
import 'package:pwdpwdpwd/features/tv_cast/models/tv_cast_session.dart';

/// Guards the `/api/state` JSON contract that the TV-side `app.js` depends on.
/// The TV maps `theme` → a `body.theme-*` class, so a missing/renamed field
/// silently breaks theming on every connected TV.
void main() {
  group('TvCastSession theme contract', () {
    test('defaults to the dark theme', () {
      const session = TvCastSession();
      expect(session.castTheme, CastTheme.dark);
      expect(session.toApiJson()['theme'], 'dark');
    });

    test('toApiJson emits the enum name for each theme', () {
      for (final theme in CastTheme.values) {
        final json = TvCastSession(castTheme: theme).toApiJson();
        expect(json['theme'], theme.name);
      }
    });

    test('copyWith updates the theme and bumps nothing else', () {
      const base = TvCastSession(mode: CastMode.fslVideo, slideIndex: 3);
      final next = base.copyWith(castTheme: CastTheme.highContrast);
      expect(next.castTheme, CastTheme.highContrast);
      expect(next.mode, CastMode.fslVideo);
      expect(next.slideIndex, 3);
    });

    test('copyWith without castTheme preserves the current theme', () {
      const base = TvCastSession(castTheme: CastTheme.light);
      final next = base.copyWith(slideIndex: 1);
      expect(next.castTheme, CastTheme.light);
    });
  });

  group('TvCastSession API payload shape', () {
    test('always carries the keys the TV renderer reads', () {
      final json = const TvCastSession(
        mode: CastMode.flashcards,
        revision: 7,
      ).toApiJson();
      expect(json['rev'], 7);
      expect(json['mode'], 'flashcards');
      expect(json.containsKey('theme'), isTrue);
      expect(json.containsKey('isPaused'), isTrue);
      expect(json.containsKey('away'), isTrue);
      expect(json.containsKey('slideIndex'), isTrue);
      expect(json.containsKey('videoSound'), isTrue);
    });
  });

  group('TvCastSession away ("teacher is out")', () {
    test('defaults to not away; toApiJson emits away:false', () {
      const session = TvCastSession();
      expect(session.isAway, isFalse);
      expect(session.toApiJson()['away'], isFalse);
    });

    test('away flag flows through toApiJson', () {
      expect(const TvCastSession(isAway: true).toApiJson()['away'], isTrue);
    });

    test('copyWith toggles away without disturbing the selected content', () {
      const base = TvCastSession(mode: CastMode.story, storyPageIndex: 2);
      final away = base.copyWith(isAway: true);
      expect(away.isAway, isTrue);
      expect(away.mode, CastMode.story);
      expect(away.storyPageIndex, 2);
    });

    test('copyWith preserves away when not specified', () {
      const base = TvCastSession(isAway: true);
      expect(base.copyWith(slideIndex: 1).isAway, isTrue);
    });
  });

  group('TvCastSession audio fields', () {
    test('castAudioEnabled defaults on; tvVideoSound defaults off', () {
      const session = TvCastSession();
      expect(session.castAudioEnabled, isTrue);
      expect(session.tvVideoSoundEnabled, isFalse);
    });

    test('videoSound in toApiJson tracks tvVideoSoundEnabled', () {
      expect(const TvCastSession().toApiJson()['videoSound'], isFalse);
      expect(
        const TvCastSession(
          tvVideoSoundEnabled: true,
        ).toApiJson()['videoSound'],
        isTrue,
      );
    });

    test('castAudioEnabled is phone-only — never sent to the TV', () {
      final json = const TvCastSession(castAudioEnabled: false).toApiJson();
      expect(json.containsKey('castAudioEnabled'), isFalse);
    });

    test('copyWith preserves audio fields when not specified', () {
      const base = TvCastSession(
        castAudioEnabled: false,
        tvVideoSoundEnabled: true,
      );
      final next = base.copyWith(slideIndex: 2);
      expect(next.castAudioEnabled, isFalse);
      expect(next.tvVideoSoundEnabled, isTrue);
    });
  });

  group('TvCastSession auto-advance', () {
    test('autoAdvanceEnabled defaults on', () {
      expect(const TvCastSession().autoAdvanceEnabled, isTrue);
    });

    test('copyWith updates autoAdvanceEnabled and leaves other fields alone',
        () {
      const base = TvCastSession(mode: CastMode.story, storyPageIndex: 2);
      final off = base.copyWith(autoAdvanceEnabled: false);
      expect(off.autoAdvanceEnabled, isFalse);
      expect(off.mode, CastMode.story);
      expect(off.storyPageIndex, 2);
    });

    test('copyWith preserves autoAdvanceEnabled when not specified', () {
      const base = TvCastSession(autoAdvanceEnabled: false);
      expect(base.copyWith(slideIndex: 1).autoAdvanceEnabled, isFalse);
    });

    test('autoAdvanceEnabled is phone-only — never sent to the TV', () {
      final json = const TvCastSession(autoAdvanceEnabled: false).toApiJson();
      expect(json.containsKey('autoAdvanceEnabled'), isFalse);
      expect(json.containsKey('autoAdvance'), isFalse);
    });
  });

  group('TvCastSession TV audio status', () {
    test('defaults to unknown', () {
      expect(const TvCastSession().tvAudioStatus, TvAudioStatus.unknown);
    });

    test('copyWith updates tvAudioStatus and leaves other fields alone', () {
      const base = TvCastSession(mode: CastMode.flashcards, slideIndex: 3);
      final next = base.copyWith(tvAudioStatus: TvAudioStatus.needsTap);
      expect(next.tvAudioStatus, TvAudioStatus.needsTap);
      expect(next.mode, CastMode.flashcards);
      expect(next.slideIndex, 3);
    });

    test('copyWith preserves tvAudioStatus when not specified', () {
      const base = TvCastSession(tvAudioStatus: TvAudioStatus.unsupported);
      expect(base.copyWith(slideIndex: 1).tvAudioStatus,
          TvAudioStatus.unsupported);
    });

    test('tvAudioStatus is phone-only — never sent to the TV', () {
      final json =
          const TvCastSession(tvAudioStatus: TvAudioStatus.ready).toApiJson();
      expect(json.containsKey('tvAudioStatus'), isFalse);
      expect(json.containsKey('audio'), isFalse);
    });
  });

  group('TvCastSession TV replay signal', () {
    test('defaults: nonce 0, lang both — emitted in toApiJson for the TV', () {
      final replay = const TvCastSession().toApiJson()['ttsReplay'] as Map;
      expect(replay['n'], 0);
      expect(replay['lang'], 'both');
    });

    test('toApiJson carries the bumped nonce + chosen language', () {
      final replay = const TvCastSession(
        ttsReplayNonce: 4,
        ttsReplayLang: 'fil',
      ).toApiJson()['ttsReplay'] as Map;
      expect(replay['n'], 4);
      expect(replay['lang'], 'fil');
    });

    test('copyWith updates the replay fields and preserves them otherwise', () {
      const base = TvCastSession(ttsReplayNonce: 2, ttsReplayLang: 'en');
      expect(base.copyWith(slideIndex: 1).ttsReplayNonce, 2);
      expect(base.copyWith(slideIndex: 1).ttsReplayLang, 'en');
      expect(base.copyWith(ttsReplayNonce: 3).ttsReplayNonce, 3);
    });
  });

  group('TvCastSession display design', () {
    test('toApiJson emits the enum name for every template', () {
      for (final theme in CastTheme.values) {
        expect(TvCastSession(castTheme: theme).toApiJson()['theme'], theme.name);
      }
    });

    test('every template has a non-empty label + description for the picker',
        () {
      for (final theme in CastTheme.values) {
        expect(theme.label, isNotEmpty);
        expect(theme.description, isNotEmpty);
      }
    });

    test('castTitle: empty by default, trimmed when set', () {
      expect(const TvCastSession().toApiJson()['title'], '');
      expect(
        const TvCastSession(castTitle: '  Ms. Cruz  ').toApiJson()['title'],
        'Ms. Cruz',
      );
      // Whitespace-only title is treated as empty.
      expect(const TvCastSession(castTitle: '   ').toApiJson()['title'], '');
    });

    test('reducedMotion flows through toApiJson', () {
      expect(const TvCastSession().toApiJson()['reducedMotion'], isFalse);
      expect(
        const TvCastSession(reducedMotion: true).toApiJson()['reducedMotion'],
        isTrue,
      );
    });

    test('seasonal block is present only for the seasonal template', () {
      expect(const TvCastSession().toApiJson()['seasonal'], isNull);
      expect(
        const TvCastSession(castTheme: CastTheme.classroom)
            .toApiJson()['seasonal'],
        isNull,
      );
      final seasonal = const TvCastSession(
        castTheme: CastTheme.seasonal,
        seasonalEmoji: '🎃',
        seasonalAccent: '#ff6f00',
      ).toApiJson()['seasonal'] as Map;
      expect(seasonal['emoji'], '🎃');
      expect(seasonal['accent'], '#ff6f00');
    });

    test('copyWith clears title + seasonal via flags and keeps reducedMotion',
        () {
      const base = TvCastSession(
        castTheme: CastTheme.seasonal,
        castTitle: 'Grade 2',
        seasonalEmoji: '🎄',
        seasonalAccent: '#c62828',
        reducedMotion: true,
      );
      final cleared = base.copyWith(clearCastTitle: true, clearSeasonal: true);
      expect(cleared.castTitle, isNull);
      expect(cleared.seasonalEmoji, isNull);
      expect(cleared.seasonalAccent, isNull);
      expect(cleared.reducedMotion, isTrue);
    });
  });

  group('TvCastSession live block', () {
    test('always present (empty) so the hands banner works in any mode', () {
      final live = const TvCastSession().toApiJson()['live'] as Map;
      expect(live['hands'], isEmpty);
      expect(live['responded'], 0);
      expect(live['board'], isEmpty);
      expect(live['activity'], isNull);
    });

    test('raised hands serialize as names in every mode', () {
      final session = TvCastSession(
        mode: CastMode.flashcards,
        raisedHands: [
          RaisedHand(
            profileId: 'p1',
            profileName: 'Ana',
            raisedAt: DateTime.parse('2026-05-31T10:00:00.000'),
          ),
        ],
      );
      final live = session.toApiJson()['live'] as Map;
      expect(live['hands'], ['Ana']);
    });

    test('live mode emits the activity, responders, and board — but never '
        'the correct answer', () {
      final session = TvCastSession(
        mode: CastMode.live,
        liveResponders: 3,
        liveActivity: LiveActivity.multipleChoice(
          prompt: 'Pick the cat',
          options: const ['Cat', 'Dog'],
          correctIndex: 0,
        ),
        liveScoreboard: const [
          LiveScoreRow(profileId: 'p1', name: 'Ana', stars: 5, correct: 2),
        ],
      );
      final live = session.toApiJson()['live'] as Map;
      final activity = live['activity'] as Map;
      expect(activity['type'], 'multipleChoice');
      expect(activity['prompt'], 'Pick the cat');
      expect(activity['options'], ['Cat', 'Dog']);
      expect(activity['isTrueFalse'], isFalse);
      expect(activity.containsKey('correctIndex'), isFalse);
      expect(activity.containsKey('correct_index'), isFalse);
      expect(live['responded'], 3);
      expect((live['board'] as List).first['stars'], 5);
    });

    test('copyWith clears the live activity + session via flags', () {
      final base = TvCastSession(
        mode: CastMode.live,
        liveSessionKey: 'class1',
        liveActivity: LiveActivity.trueFalse(statement: 's', correctValue: true),
      );
      final cleared =
          base.copyWith(clearLiveActivity: true, clearLiveSession: true);
      expect(cleared.liveActivity, isNull);
      expect(cleared.liveSessionKey, isNull);
    });
  });

  group('TvCastSession tap-to-flip ("Tap Only")', () {
    test('flipTapOnly defaults on; toApiJson emits tapOnly:true', () {
      const session = TvCastSession();
      expect(session.flipTapOnly, isTrue);
      expect(session.toApiJson()['tapOnly'], isTrue);
    });

    test('tapOnly:false flows through so the TV shows the emoji only', () {
      expect(
        const TvCastSession(flipTapOnly: false).toApiJson()['tapOnly'],
        isFalse,
      );
    });

    test('copyWith updates flipTapOnly and preserves it otherwise', () {
      const base = TvCastSession(mode: CastMode.flashcards, slideIndex: 3);
      final off = base.copyWith(flipTapOnly: false);
      expect(off.flipTapOnly, isFalse);
      expect(off.mode, CastMode.flashcards);
      expect(off.slideIndex, 3);
      expect(off.copyWith(slideIndex: 4).flipTapOnly, isFalse);
    });

    test('cardFlipped defaults to the emoji face; flows through as flipped', () {
      const session = TvCastSession();
      expect(session.cardFlipped, isFalse);
      expect(session.toApiJson()['flipped'], isFalse);
      expect(
        const TvCastSession(cardFlipped: true).toApiJson()['flipped'],
        isTrue,
      );
    });

    test('copyWith toggles cardFlipped and preserves it across re-renders', () {
      const base = TvCastSession(mode: CastMode.flashcards, slideIndex: 2);
      final flipped = base.copyWith(cardFlipped: true);
      expect(flipped.cardFlipped, isTrue);
      // An unrelated bump (e.g. theme) keeps the current face.
      expect(flipped.copyWith(revision: 9).cardFlipped, isTrue);
    });
  });

  group('TvCastSession "Show Me" action clip', () {
    test('showMeActive defaults off; toApiJson emits showMe:false', () {
      const session = TvCastSession();
      expect(session.showMeActive, isFalse);
      expect(session.toApiJson()['showMe'], isFalse);
    });

    test('showMe flows through toApiJson when active', () {
      expect(
        const TvCastSession(showMeActive: true).toApiJson()['showMe'],
        isTrue,
      );
    });

    test('copyWith toggles showMeActive and preserves the rest', () {
      const base = TvCastSession(mode: CastMode.flashcards, slideIndex: 5);
      final on = base.copyWith(showMeActive: true);
      expect(on.showMeActive, isTrue);
      expect(on.slideIndex, 5);
      // Re-rendering the same card without touching showMeActive keeps it.
      expect(on.copyWith(isPaused: true).showMeActive, isTrue);
    });
  });

  group('TvCastSession story "Watch in FSL" clip', () {
    test('storyFslActive defaults off; toApiJson emits storyFsl:false', () {
      const session = TvCastSession();
      expect(session.storyFslActive, isFalse);
      expect(session.toApiJson()['storyFsl'], isFalse);
    });

    test('storyFsl flows through toApiJson when active', () {
      expect(
        const TvCastSession(storyFslActive: true).toApiJson()['storyFsl'],
        isTrue,
      );
    });

    test('copyWith toggles storyFslActive and preserves the rest', () {
      const base = TvCastSession(mode: CastMode.story, storyPageIndex: 4);
      final on = base.copyWith(storyFslActive: true);
      expect(on.storyFslActive, isTrue);
      expect(on.mode, CastMode.story);
      expect(on.storyPageIndex, 4);
      // Re-rendering the same page without touching storyFslActive keeps it.
      expect(on.copyWith(isPaused: true).storyFslActive, isTrue);
    });
  });

  group('TvCastSession TV-speech routing (ttsOnTv)', () {
    test('defaults: audio on + target TV → ttsOnTv true', () {
      const session = TvCastSession();
      expect(session.castAudioTarget, CastAudioTarget.tv);
      expect(session.toApiJson()['ttsOnTv'], isTrue);
    });

    test('target phone → ttsOnTv false (phone speaks instead)', () {
      const session = TvCastSession(castAudioTarget: CastAudioTarget.phone);
      expect(session.toApiJson()['ttsOnTv'], isFalse);
    });

    test('audio off → ttsOnTv false even when target is TV (default)', () {
      const session = TvCastSession(castAudioEnabled: false);
      expect(session.castAudioTarget, CastAudioTarget.tv);
      expect(session.toApiJson()['ttsOnTv'], isFalse);
    });

    test('copyWith preserves castAudioTarget when not specified', () {
      const base = TvCastSession(castAudioTarget: CastAudioTarget.phone);
      expect(
        base.copyWith(slideIndex: 1).castAudioTarget,
        CastAudioTarget.phone,
      );
    });
  });
}
