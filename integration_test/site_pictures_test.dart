// Takes the app pictures for the companion website's "Features in Action"
// page (website/features.html) from the real app, on an Android EMULATOR:
//
//   WALKTHROUGH_DIR=build/site_pictures flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/site_pictures_test.dart \
//     --dart-define=FLASHLEARN_OFFLINE=true -d <emulator>
//
// then `python tools/site_pictures_build.py build/site_pictures` turns the
// chosen ones into website/assets/features/*.webp.
//
// It makes two sample profiles on the emulator — a learner, "Ana" (Player
// with Progress), and a teacher, "Ms. Cruz" — and photographs the screens the
// website shows: the profile choice, the flashcard with its speaker and FSL
// buttons, Gaze Control and its voice and switch settings, the game controller
// settings, the Talk Board, My Day and its ready-made plans, the break
// reminder, Settings at normal and at the larger, high-contrast and
// dyslexia-friendly looks, and the teacher's tools.
//
// For the website's "For Children" guides it also walks a Child profile,
// "Mia": the join screen, the Child home and its sections, and the screens
// its tiles open. A real Child joins their parent's family group with a code,
// which needs the online service, and this walk stays offline — so Mia is
// added as a Child profile directly (a sample family-group id), at the end of
// the walk. Everything photographed is the app's own Child screens.
// FLASHLEARN_OFFLINE keeps the app off Firebase, so nothing is created online.
//
// NEVER point it at a tablet with real profiles: when `flutter drive`
// finishes it stops AND UNINSTALLS the app, which wipes every profile on the
// device. Emulators only.

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui show ImageByteFormat, ImageDescriptor, ImmutableBuffer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pwdpwdpwd/data/models/enums.dart' show UserRole;
import 'package:pwdpwdpwd/data/models/models.dart' show UserProfile;
import 'package:pwdpwdpwd/features/break_time/widgets/break_reminder_gate.dart'
    show BreakReminderDialog;
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/main.dart' as app;
import 'package:pwdpwdpwd/navigation/app_router.dart' show rootNavigatorKey;
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show profileProvider, settingsProvider;

const _learner = 'Ana';
const _child = 'Mia';
const _teacher = 'Ms. Cruz';
const _maxShotSide = 1280;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'website pictures',
    (tester) async {
      final walk = _Pictures(tester, binding);
      final flutterOnError = FlutterError.onError;
      final errorWidgetBuilder = ErrorWidget.builder;
      try {
        await walk.run();
      } finally {
        FlutterError.onError = flutterOnError;
        ErrorWidget.builder = errorWidgetBuilder;
      }
      // ignore: avoid_print
      print('PICS done: ${walk.shots} pictures, notes: ${walk.notes.join(' | ')}');
    },
    timeout: const Timeout(Duration(minutes: 25)),
  );
}

class _Pictures {
  _Pictures(this.tester, this.binding);

  final WidgetTester tester;
  final IntegrationTestWidgetsFlutterBinding binding;
  final List<String> notes = [];
  int shots = 0;

  GoRouter get _router => GoRouter.of(rootNavigatorKey.currentContext!);
  ProviderContainer get _container =>
      ProviderScope.containerOf(rootNavigatorKey.currentContext!);

  Future<void> run() async {
    app.main();
    await _settle(const Duration(seconds: 2));
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await SystemChrome.setPreferredOrientations(
      const [DeviceOrientation.portraitUp],
    );
    await _settle(const Duration(seconds: 2));

    final first = await _waitForAny({
      'welcome': find.text('Skip'),
      'choose': find.text('Player (with Progress)'),
      'switcher': find.text('Add New Profile'),
    }, const Duration(seconds: 120));
    if (first == 'welcome') await _tap(find.text('Skip'));
    if (first == 'switcher') await _tap(find.text('Add New Profile'));
    // The six kinds of profile, as a new user meets them.
    if (await _waitFor(find.text('Child Profile (PWD)'), const Duration(seconds: 30))) {
      await _settle(const Duration(seconds: 2));
      await _shot('choose_profile');
    }
    await _createLearner();
    await _intoHome(learner: true);
    _ana = _container.read(profileProvider);

    await _learnerPictures();
    await _looks();
    await _teacherPictures();
    // Last: after a switch of profile, a screenshot of a screen the earlier
    // profile also visited could still show that profile's last frame (seen
    // 16 Nov; the app itself had switched — a probe read the right name on
    // screen). With the Child walk at the end, no other picture follows a
    // switch.
    await _childPictures();
  }

  /// The learner, Ana, as created; Mia (the Child) is made from her.
  UserProfile? _ana;

  // ── The child ───────────────────────────────────────────────────────────

  Future<void> _childPictures() async {
    final notifier = _container.read(profileProvider.notifier);
    final ana = _ana;
    if (ana == null) {
      notes.add('no learner to walk as a child');
      return;
    }
    Future<void> become(UserProfile p) async {
      await notifier.setProfile(p);
      await _settle(const Duration(seconds: 3));
    }

    // Mia is a profile of her own on this tablet (her own id, no username):
    // nothing of Ana's — her My Day plan included — goes with her.
    final mia = ana.copyWith(
      id: 'sample-child-mia',
      role: UserRole.child,
      name: _child,
      username: () => null,
    );

    // A new Child has no family yet: the app asks for the parent's code.
    await become(mia.copyWith(homeGroupId: () => null));
    _router.go('/join-home-group');
    await _settle(const Duration(seconds: 3));
    await _shot('kids_join');

    // In the family: the Child home and what its tiles open.
    await become(mia.copyWith(homeGroupId: () => 'sample-family'));
    await _visit('/home', name: 'kids_home', push: false);
    for (final (heading, name) in const [
      ('Play & Learn', 'kids_play'),
      ('Explore & Create', 'kids_explore'),
      ('Friends', 'kids_friends'),
      ('Rewards & Feelings', 'kids_rewards'),
    ]) {
      await _visit('/home', name: '${name}_again', push: false, shoot: false);
      if (await _scrollToTop(find.text(heading))) await _shot(name);
    }
    await _visit('/flashcards', name: 'kids_decks', push: false);
    await _visit('/flashcards/viewer/0', name: 'kids_card');
    await _visit('/games', name: 'kids_games', push: false);
    await _visit('/stories', name: 'kids_stories', push: false);
    await _visit('/progress', name: 'kids_progress', push: false);
    await _visit('/communication-board', name: 'kids_talk_empty', shoot: false);
    for (final word in const ['Hello', 'Good morning']) {
      final tile = find.text(word);
      if (await _has(tile)) {
        await _tap(tile.first);
        await _settle(const Duration(seconds: 2));
      }
    }
    await _shot('kids_talk');
    await _visit('/routine', name: 'kids_my_day');
    await _visit('/mood-check-in', name: 'kids_feelings');
    await _visit('/ai-tutor', name: 'kids_buddy');
    await _visit('/sticker-album', name: 'kids_stickers');
    await _visit('/gamification-dashboard', name: 'kids_player_card');
    await _visit('/smileyometer', name: 'kids_how_was_it');
    await _visit('/messages', name: 'kids_messages');
    await _visit('/word-hunt-collection', name: 'kids_word_hunt');
  }

  // ── The learner ─────────────────────────────────────────────────────────

  Future<void> _createLearner() async {
    if (!await _waitFor(find.text('Player (with Progress)'), const Duration(seconds: 30))) {
      notes.add('no profile choice');
      return;
    }
    await _settle(const Duration(seconds: 1));
    await _tap(find.text('Player (with Progress)'));
    await _fillName(_learner);
    await _tap(find.byIcon(Icons.cake_rounded));
    final ok = find.descendant(of: find.byType(DatePickerDialog), matching: find.text('OK'));
    if (await _waitFor(ok, const Duration(seconds: 10))) {
      await _settle(const Duration(seconds: 1));
      await _tap(ok);
      await _settle(const Duration(seconds: 1));
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(const Duration(seconds: 1));
    await _tap(find.text("Let's Go!"));
    await _settle(const Duration(seconds: 3));
  }

  Future<void> _fillName(String name) async {
    if (!await _waitFor(find.byType(TextFormField), const Duration(seconds: 20))) {
      notes.add('no name field');
      return;
    }
    final field = find.byType(TextFormField).first;
    await _tap(field);
    await _settle(const Duration(seconds: 1));
    await tester.enterText(field, name);
    await _settle(const Duration(milliseconds: 800));
    if (!await _has(find.text(name))) {
      final editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      editable.controller.text = name;
      await _settle(const Duration(milliseconds: 800));
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(const Duration(seconds: 2));
  }

  /// Skips whatever comes between the form and Home, then collects the
  /// Daily Reward so it does not cover the pictures.
  Future<void> _intoHome({required bool learner}) async {
    final homeMark = learner ? find.text('Cards') : find.textContaining(_teacher);
    for (var i = 0; i < 6; i++) {
      if (await _waitFor(homeMark, const Duration(seconds: 4))) break;
      for (final label in const ['Skip', 'Got it', 'OK', 'Continue', 'Done']) {
        if (await _has(find.text(label))) {
          await _tap(find.text(label).last);
          await _settle(const Duration(seconds: 2));
          break;
        }
      }
    }
    await _settle(const Duration(seconds: 2));
    final collect = find.textContaining('Collect');
    if (await _waitFor(collect, const Duration(seconds: 6))) {
      await _tap(collect);
      await _settle(const Duration(seconds: 3));
    }
  }

  Future<void> _learnerPictures() async {
    await _visit('/home', name: 'learner_home', push: false);
    await _visit('/flashcards/viewer/0', name: 'flashcard');
    await _visit('/fsl-dictionary', name: 'fsl_dictionary');
    await _visit('/games', name: 'games', push: false);
    await _visit('/stories', name: 'stories', push: false);
    await _visit('/progress', name: 'progress', push: false);
    await _visit('/word-hunt-collection', name: 'word_hunt');
    await _visit('/multiplayer', name: 'play_together');

    await _visit('/gaze-settings', name: 'gaze_top');
    if (await _scrollToTop(find.text('Voice commands'))) await _shot('gaze_voice');
    await _visit('/gaze-settings', name: 'gaze_again', shoot: false);
    if (await _scrollToTop(find.text('How to choose'))) await _shot('gaze_choose');
    if (await _scrollToTop(find.text('Scanning mode'))) await _shot('gaze_scanning');

    await _visit('/gamepad-settings', name: 'controller');

    await _visit('/settings', name: 'settings_top');
    if (await _scrollToTop(find.text('Text-to-Speech'))) await _shot('settings_speech');
    await _visit('/settings', name: 'settings_again', shoot: false);
    if (await _scrollToTop(find.text('Adaptive Difficulty'))) await _shot('settings_learning');

    // The Talk Board, with a sentence built from two tiles.
    await _visit('/communication-board', name: 'talk_board_empty');
    for (final word in const ['Hello', 'Good morning']) {
      final tile = find.text(word);
      if (await _has(tile)) {
        await _tap(tile.first);
        await _settle(const Duration(seconds: 2));
      }
    }
    await _shot('talk_board');

    // My Day: the plans to start from, then one of them.
    await _visit('/routine', name: 'my_day_start');
    // "Build my routine" opens the routine page; its "Create a routine" opens
    // the "Start from…" sheet of ready-made plans.
    final build = find.text('Build my routine');
    if (await _has(build)) {
      await _tap(build.first);
      await _settle(const Duration(seconds: 3));
      final create = find.text('Create a routine');
      if (await _has(create)) {
        await _tap(create.first);
        await _settle(const Duration(seconds: 3));
      }
      if (await _waitFor(find.text('Start from…'), const Duration(seconds: 8))) {
        await _settle(const Duration(seconds: 1));
        await _shot('my_day_plans');
      } else {
        notes.add('no Start from… sheet');
      }
    }
    final plan = find.textContaining('Morning Routine');
    if (await _has(plan)) {
      await _tap(plan.first);
      await _settle(const Duration(seconds: 3));
      await _shot('my_day_plan');
      for (final label in const ['Use this plan', 'Use plan', 'Add', 'Save', 'Start']) {
        final b = find.text(label);
        if (await _has(b)) {
          await _tap(b.last);
          await _settle(const Duration(seconds: 3));
          await _shot('my_day_steps');
          break;
        }
      }
    }

    // The break reminder, exactly as the learner's tablet shows it.
    await _visit('/flashcards', name: 'decks', push: false);
    final keepLabel = _openBreakReminder();
    await _settle(const Duration(seconds: 2));
    await _shot('break_reminder');
    final keep = find.text(keepLabel);
    if (await _has(keep)) await _tap(keep);
    await _settle(const Duration(seconds: 2));
  }

  /// Opens the reminder with the words BreakReminderGate gives it (20 minutes
  /// learned, 25 left today). Returns the "Keep learning" label.
  String _openBreakReminder() {
    final ctx = rootNavigatorKey.currentContext!;
    final t = AppLocalizations.of(ctx)!;
    // ignore: discarded_futures
    showDialog<bool>(
      context: ctx,
      builder: (_) => BreakReminderDialog(
        title: t.brkTitle,
        body: t.brkBody(20),
        timeLeft: t.brkTimeLeft(25),
        takeBreakLabel: t.brkTakeBreak,
        keepLearningLabel: t.brkKeepLearning,
      ),
    );
    return t.brkKeepLearning;
  }

  /// The same screen at the default look, then bigger with high contrast,
  /// then dark, then dyslexia-friendly — and back to the default.
  Future<void> _looks() async {
    final notifier = _container.read(settingsProvider.notifier);
    final original = _container.read(settingsProvider);
    Future<void> look(String name, {double scale = 1.0, bool contrast = false,
        bool dark = false, bool dyslexia = false}) async {
      notifier.update(original.copyWith(
        fontScale: scale,
        highContrastMode: contrast,
        darkMode: dark,
        dyslexiaMode: dyslexia,
      ));
      await _settle(const Duration(seconds: 2));
      await _visit('/flashcards/viewer/0', name: name);
    }

    await look('look_normal');
    await look('look_large_contrast', scale: 1.4, contrast: true);
    await look('look_dark', dark: true);
    await look('look_dyslexia', dyslexia: true);
    notifier.update(original);
    await _settle(const Duration(seconds: 2));
  }

  // ── The teacher ─────────────────────────────────────────────────────────

  Future<void> _teacherPictures() async {
    final learnerId = _container.read(profileProvider)?.id ?? '';
    _router.go('/role-setup/teacher');
    await _settle(const Duration(seconds: 3));
    await _fillName(_teacher);
    await _tap(find.text("Let's Go!"));
    await _settle(const Duration(seconds: 4));
    // A recovery code is shown once for a backed-up profile.
    for (final label in const ['I saved it', 'I have saved it', 'Done', 'OK']) {
      if (await _has(find.text(label))) {
        await _tap(find.text(label).last);
        await _settle(const Duration(seconds: 2));
      }
    }
    await _intoHome(learner: false);
    await _visit('/home', name: 'teacher_home', push: false);
    await _visit('/teacher-dashboard', name: 'teacher_dashboard');
    await _visit('/classroom-manage', name: 'manage_classes');
    await _visit('/assessment/assign', name: 'assign_tasks');
    await _visit('/assessment/class-report', name: 'class_report');
    await _visit('/tv-cast', name: 'tv_cast');
    if (learnerId.isNotEmpty) {
      await _visit('/child-time-limits/$learnerId?name=$_learner', name: 'time_limits');
      final remind = find.textContaining('Remind them to take a break');
      if (await _scrollToTop(remind)) {
        await _shot('break_settings_off');
        final sw = find.descendant(
          of: find.ancestor(of: remind.first, matching: find.byType(ListTile)),
          matching: find.byType(Switch),
        );
        if (await _has(sw)) {
          await _tap(sw.first);
          await _settle(const Duration(seconds: 2));
        } else {
          await _tap(remind.first);
          await _settle(const Duration(seconds: 2));
        }
        await _shot('break_settings_on');
      }
      await _visit('/routine-manage/$learnerId?name=$_learner', name: 'routine_manage');
      await _visit('/child-alarms/$learnerId?name=$_learner', name: 'alarms');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _visit(String route, {required String name, bool push = true,
      bool shoot = true}) async {
    try {
      _router.go('/home');
      await _settle(const Duration(milliseconds: 900));
      if (route != '/home') {
        if (push) {
          _router.push(route);
        } else {
          _router.go(route);
        }
      }
    } catch (e) {
      notes.add('$route: $e');
      return;
    }
    await _settle(Duration(milliseconds: route.contains('viewer') ? 5000 : 3200));
    final skeleton = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().startsWith('Shimmer'),
    );
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (await _has(skeleton) && DateTime.now().isBefore(end)) {
      await _settle(const Duration(milliseconds: 500));
    }
    await _settle(const Duration(milliseconds: 800));
    if (shoot) await _shot(name);
  }

  /// Scrolls the page's list until [finder] shows, then puts it near the top.
  Future<bool> _scrollToTop(Finder finder) async {
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    if (!await _has(finder)) {
      if (!await _has(lists)) return false;
      for (final delta in const [300.0, -300.0]) {
        try {
          await tester.scrollUntilVisible(finder, delta,
              scrollable: lists.first);
          break;
        } catch (_) {
          if (await _has(finder)) break;
        }
      }
    }
    if (!await _has(finder)) {
      notes.add('not found: $finder');
      return false;
    }
    try {
      await Scrollable.ensureVisible(finder.evaluate().first, alignment: 0.12);
    } catch (_) {}
    await _settle(const Duration(milliseconds: 1500));
    return true;
  }

  Future<void> _settle(Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<bool> _waitFor(Finder finder, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      if (await _has(finder)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return false;
  }

  Future<String?> _waitForAny(Map<String, Finder> finders, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final e in finders.entries) {
        if (await _has(e.value)) return e.key;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return null;
  }

  Future<void> _tap(Finder finder) async {
    if (!await _waitFor(finder, const Duration(seconds: 12))) {
      notes.add('could not tap $finder');
      return;
    }
    final target = finder.first;
    try {
      await tester.ensureVisible(target);
    } catch (_) {}
    await tester.pump(const Duration(milliseconds: 300));
    try {
      await tester.tap(target, warnIfMissed: false);
    } catch (e) {
      notes.add('tap $finder threw $e');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<bool> _has(Finder finder) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return finder.evaluate().isNotEmpty;
      } catch (_) {
        if (attempt == 2) return false;
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  }

  Future<void> _shot(String name) async {
    shots++;
    final file = '${shots.toString().padLeft(2, '0')}_$name';
    try {
      await binding.takeScreenshot(file);
      if (Platform.isAndroid) await _shrinkLastShot();
      // ignore: avoid_print
      print('PICS shot $file');
    } catch (e) {
      notes.add('screenshot $file failed: $e');
    }
  }

  Future<void> _shrinkLastShot() async {
    final shotsData = binding.reportData?['screenshots'] as List<dynamic>?;
    if (shotsData == null || shotsData.isEmpty) return;
    final entry = shotsData.last as Map<String, dynamic>;
    final bytes = Uint8List.fromList(entry['bytes'] as List<int>);
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final longest = math.max(descriptor.width, descriptor.height);
    if (longest <= _maxShotSide) {
      descriptor.dispose();
      buffer.dispose();
      return;
    }
    final scale = _maxShotSide / longest;
    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round(),
      targetHeight: (descriptor.height * scale).round(),
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    codec.dispose();
    descriptor.dispose();
    buffer.dispose();
    if (png != null) entry['bytes'] = png.buffer.asUint8List();
  }
}
