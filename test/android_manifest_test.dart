import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fixes that live in the Android manifest, where no Dart test would notice
/// them go.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the app keeps running when an overlay changes, rather than starting '
      'over at "Choose your profile"', () {
    // On the Honor, turning TalkBack on or off swaps the navigation-bar
    // overlay. The activity, and Flutter with it, was rebuilt five times, and
    // the learner was back at the profile list mid-lesson.
    final declared = RegExp(r'android:configChanges="([^"]*)"')
        .allMatches(manifest)
        .map((m) => m.group(1)!.split('|'))
        .toList();
    expect(declared, hasLength(1), reason: 'the one activity');
    expect(declared.single, contains('assetsPaths'));
    // A game controller with a D-pad, connecting or going, is a navigation
    // change: the same restart.
    expect(declared.single, contains('navigation'));
    // Flutter reads Bold text only when the activity starts: handled in
    // place, it would go stale.
    expect(declared.single, isNot(contains('fontWeightAdjustment')));
  });

  test('speech engines are declared, so Android 11+ shows them to the app', () {
    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
  });
}
