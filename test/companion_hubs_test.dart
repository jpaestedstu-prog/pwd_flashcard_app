import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/features/companion/widgets/companion_overlay.dart';

/// The floating AI buddy appears over the five hubs only. A prefix match
/// floated it over every game, the card viewer and the story reader, where
/// on a phone it covered jigsaw pieces, answer cards and page controls.
void main() {
  test('shown on the five hubs', () {
    for (final hub in ['/home', '/flashcards', '/games', '/stories', '/progress']) {
      expect(companionShownOn(hub), isTrue, reason: hub);
      expect(companionShownOn('$hub/'), isTrue, reason: '$hub/');
    }
  });

  test('never over a game, the viewer, a story, or a full-screen page', () {
    for (final loc in [
      '/games/word-match',
      '/games/jigsaw-puzzle',
      '/games/fsl-practice/sign-it',
      '/flashcards/viewer/0',
      '/stories/read/s_a01',
      '/ai-tutor',
      '/settings',
      '/profile-switcher',
      '/welcome',
      '/',
      '',
    ]) {
      expect(companionShownOn(loc), isFalse, reason: loc);
    }
  });

  test('a look-alike path is not a hub', () {
    expect(companionShownOn('/homework'), isFalse);
    expect(companionShownOn('/games-hub'), isFalse);
  });
}
