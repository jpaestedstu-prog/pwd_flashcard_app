import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/accessibility/tts_service.dart';
import 'package:pwdpwdpwd/core/accessibility/voice_navigation_service.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/parent/models/educator_audience.dart';
import 'package:pwdpwdpwd/navigation/app_page_transitions.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';
import 'package:pwdpwdpwd/widgets/voice_navigation_observer.dart';

/// Screen announcements for Voice-Guided Navigation.
///
/// The observer existed for months without ever being attached to a Navigator,
/// so nothing was announced. Wiring it up surfaced a second problem that only a
/// real router shows: the observer used to identify a screen from the `Route`
/// it was handed, and for an imperative `context.push` that yields a generated
/// key rather than a path. Bottom-nav tabs worked, every drill-down did not.
/// Hence the integration group at the bottom — it drives an actual GoRouter
/// shaped like the app's, with a shell for tabs and a top-level route to push.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this.role);
  final UserRole role;

  @override
  UserProfile? build() => UserProfile(
    id: 'educator-1',
    name: role == UserRole.parent ? 'Mommy' : 'Sir Kevin',
    role: role,
    createdAt: DateTime(2026),
  );
}

class _FixedSettings extends SettingsNotifier {
  _FixedSettings(this._settings);
  final AppSettings _settings;

  @override
  AppSettings build() => _settings;
}

/// Records what would have been spoken instead of speaking it.
class _RecordingVoiceNav extends VoiceNavigationService {
  _RecordingVoiceNav(super.tts);

  final List<String> spoken = <String>[];

  @override
  Future<void> announceScreen(String screenName, {String? description}) async {
    spoken.add(
      description == null || description.isEmpty
          ? screenName
          : '$screenName. $description',
    );
  }
}

/// Hands a container-bound [Ref] to the announcer, which is otherwise only
/// reachable from inside a provider body.
final _refProvider = Provider<Ref>((ref) => ref);

typedef _Harness = ({
  ProviderContainer container,
  VoiceRouteAnnouncer announcer,
  _RecordingVoiceNav voice,
  List<Override> overrides,
});

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (call) async => 1,
        );
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('flutter_tts'), null);
  });

  _Harness harness({
    required bool voiceOn,
    UserRole role = UserRole.teacher,
    String locale = 'en',
  }) {
    final voice = _RecordingVoiceNav(TtsService());
    voice.setEnabled(voiceOn);
    voice.setLocale(locale);
    voice.setAudience(
      role == UserRole.parent
          ? EducatorAudience.parent
          : EducatorAudience.teacher,
    );

    final overrides = <Override>[
      profileProvider.overrideWith(() => _StubProfileNotifier(role)),
      settingsProvider.overrideWith(
        () => _FixedSettings(
          AppSettings(
            reducedMotion: true,
            voiceNavigation: voiceOn,
            locale: locale,
          ),
        ),
      ),
      voiceNavigationProvider.overrideWithValue(voice),
    ];

    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    return (
      container: container,
      announcer: VoiceRouteAnnouncer(container.read(_refProvider)),
      voice: voice,
      overrides: overrides,
    );
  }

  group('voice navigation off', () {
    test('announces nothing', () {
      final h = harness(voiceOn: false);
      h.announcer.announceLocation('/multi-dashboard');
      expect(h.voice.spoken, isEmpty);
    });

    test('never even builds the speech service', () {
      // The strong form of "completely unaffected": `voiceNavigationProvider`
      // constructs a FlutterTts, and nothing else in the app reads it, so an
      // eager read here would spin up the platform speech engine for every
      // user who never turned the feature on.
      final h = harness(voiceOn: false);
      h.announcer.announceLocation('/home');
      h.announcer.announceLocation('/games');
      expect(h.container.exists(voiceNavigationProvider), isFalse);
    });

    test('leaves no state that could swallow a later announcement', () {
      final h = harness(voiceOn: false);
      h.announcer.announceLocation('/home');
      expect(h.announcer.lastAnnounced, isNull);
    });
  });

  group('voice navigation on', () {
    test('announces the screen name and description', () {
      final h = harness(voiceOn: true);
      h.announcer.announceLocation('/multi-dashboard');
      expect(h.voice.spoken, [
        'All Students. View progress for all your students.',
      ]);
    });

    test('a parent hears their children', () {
      final h = harness(voiceOn: true, role: UserRole.parent);
      h.announcer.announceLocation('/multi-dashboard');
      expect(h.voice.spoken, [
        'All Children. View progress for all your children.',
      ]);
    });

    test('Filipino is spoken when the profile is Filipino', () {
      final h = harness(voiceOn: true, role: UserRole.parent, locale: 'fil');
      h.announcer.announceLocation('/multi-dashboard');
      expect(h.voice.spoken.single, startsWith('Lahat ng Anak.'));
      expect(h.voice.spoken.single, contains('mga anak'));
    });

    test('the same screen twice is announced once', () {
      final h = harness(voiceOn: true);
      h.announcer.announceLocation('/home');
      h.announcer.announceLocation('/home');
      expect(h.voice.spoken, hasLength(1));
    });

    test('moving between screens announces each one', () {
      final h = harness(voiceOn: true);
      h.announcer.announceLocation('/home');
      h.announcer.announceLocation('/games');
      h.announcer.announceLocation('/home');
      expect(h.voice.spoken, hasLength(3));
    });

    test('a route with no description is not announced at all', () {
      // Found on device: the Analytics tab and the Parent Dashboard were both
      // announced as "Page." Most of the app's ~130 routes are not in the
      // description map, and a generic word masks the transition rather than
      // describing it.
      final h = harness(voiceOn: true);
      h.announcer.announceLocation('/some/unmapped/screen');
      expect(h.voice.spoken, isEmpty);
    });

    test('the educator screens the device caught are described now', () {
      final h = harness(voiceOn: true, role: UserRole.parent);
      h.announcer.announceLocation('/teacher-analytics');
      h.announcer.announceLocation('/parent-dashboard');

      expect(h.voice.spoken, hasLength(2));
      expect(h.voice.spoken.first, startsWith('Family Analytics.'));
      expect(h.voice.spoken.last, startsWith('Parent Dashboard.'));
    });

    test('a null or empty location is ignored', () {
      final h = harness(voiceOn: true);
      h.announcer.announceLocation(null);
      h.announcer.announceLocation('');
      expect(h.voice.spoken, isEmpty);
    });
  });

  group('through a real router', () {
    // Shaped like the app: a ShellRoute whose children are the bottom-nav tabs
    // (reached with `go`), plus a top-level route reached with `push`. Both
    // navigators get an observer over one announcer, exactly as
    // `routerProvider` wires it.
    Widget app(_Harness h) {
      final router = GoRouter(
        initialLocation: '/home',
        observers: [VoiceNavigationObserver(h.announcer)],
        routes: [
          ShellRoute(
            observers: [VoiceNavigationObserver(h.announcer)],
            builder: (context, state, child) => child,
            routes: [
              for (final path in const ['/home', '/multi-dashboard', '/games'])
                GoRoute(
                  path: path,
                  pageBuilder: (context, state) => AppPageTransitions.fade(
                    key: state.pageKey,
                    child: Scaffold(
                      body: Center(
                        child: ElevatedButton(
                          onPressed: () => context.push('/parent-dashboard'),
                          child: const Text('drill down'),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          GoRoute(
            path: '/parent-dashboard',
            pageBuilder: (context, state) => AppPageTransitions.fade(
              key: state.pageKey,
              child: const Scaffold(body: Center(child: Text('dashboard'))),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      return ProviderScope(
        overrides: h.overrides,
        child: MaterialApp.router(routerConfig: router),
      );
    }

    testWidgets('a tab switch is announced', (tester) async {
      final h = harness(voiceOn: true, role: UserRole.parent);
      await tester.pumpWidget(app(h));
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.text('drill down')),
      ).go('/multi-dashboard');
      await tester.pumpAndSettle();

      expect(h.voice.spoken.last, startsWith('All Children.'));
    });

    testWidgets('a pushed screen is announced', (tester) async {
      // The regression this group exists for: `context.push` gives the page a
      // generated key, so identifying the screen from the Route yielded
      // gibberish and every drill-down went unannounced.
      final h = harness(voiceOn: true, role: UserRole.parent);
      await tester.pumpWidget(app(h));
      await tester.pumpAndSettle();

      await tester.tap(find.text('drill down'));
      await tester.pumpAndSettle();

      expect(h.voice.spoken.last, startsWith('Parent Dashboard.'));
    });

    testWidgets('popping back announces the screen returned to', (
      tester,
    ) async {
      final h = harness(voiceOn: true, role: UserRole.parent);
      await tester.pumpWidget(app(h));
      await tester.pumpAndSettle();

      await tester.tap(find.text('drill down'));
      await tester.pumpAndSettle();

      GoRouter.of(tester.element(find.text('dashboard'))).pop();
      await tester.pumpAndSettle();

      expect(h.voice.spoken.last, startsWith('Home.'));
    });

    testWidgets('navigating with the setting off stays silent', (tester) async {
      final h = harness(voiceOn: false, role: UserRole.parent);
      await tester.pumpWidget(app(h));
      await tester.pumpAndSettle();

      GoRouter.of(
        tester.element(find.text('drill down')),
      ).go('/multi-dashboard');
      await tester.pumpAndSettle();

      await tester.tap(find.text('drill down'));
      await tester.pumpAndSettle();

      expect(h.voice.spoken, isEmpty);
      expect(h.container.exists(voiceNavigationProvider), isFalse);
    });
  });
}
