import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/local/seed_data.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart'
    show AppSettings, UserProfile;
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;

import '../support/all_screens.dart';
import '../support/drill_down_screens.dart';
import '../support/long_content.dart';

/// Switches the language with each screen open, as the quick sheet does over
/// any screen, and compares it with the same screen opened fresh in the new
/// language. What is still in the old language was kept from before the
/// switch (read in initState, or held in a field). Writes a build/live_lang
/// file with what it found, per screen and direction.
const _me = 'sweep-profile';

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
        id: _me,
        name: 'Test User',
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
        classroomId: role == UserRole.student ? 'long-class' : null,
        homeGroupId: role == UserRole.child ? 'long-group' : null,
      );
}

class _Settings extends SettingsNotifier {
  _Settings(this.initial);
  final String initial;
  @override
  AppSettings build() => AppSettings(locale: initial);
  @override
  void update(AppSettings newSettings) => state = newSettings;
}

final _report = <String, List<String>>{};

Set<String> _visible(WidgetTester tester) {
  final out = <String>{};
  for (final rp in tester.renderObjectList<RenderParagraph>(
    find.byType(RichText),
  )) {
    if (!rp.hasSize) continue;
    final t = rp.text.toPlainText(includeSemanticsLabels: false).trim();
    if (t.isNotEmpty) out.add(t);
  }
  return out;
}

Future<Set<String>> _readAll(WidgetTester tester) async {
  final out = _visible(tester);
  final scrollables = find
      .byWidgetPredicate((w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.vertical)
      .evaluate()
      .toList();
  for (final e in scrollables.take(2)) {
    final state = (e as StatefulElement).state;
    if (state is! ScrollableState) continue;
    final p = state.position;
    if (!p.hasContentDimensions || !p.hasViewportDimension) continue;
    final step = p.viewportDimension * 0.8;
    if (step <= 0) continue;
    for (var i = 1; i <= 15; i++) {
      final target = (step * i).clamp(0.0, p.maxScrollExtent);
      if (!e.mounted) break;
      p.jumpTo(target);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      out.addAll(_visible(tester));
      if (target >= p.maxScrollExtent) break;
    }
    if (e.mounted) {
      p.jumpTo(0);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  return out;
}

void main() {
  if (Platform.environment['FLASHLEARN_SURVEY'] != '1') {
    test('a long survey: runs from tool/run_surveys.sh', () {});
    return;
  }
  late Set<String> vocabulary;

  setUpAll(() async {
    await openMemoryBoxes('live_lang_${Platform.environment['LIVE_SHARD'] ?? 'all'}');
    await seedLongContent(_me);
    vocabulary = {
      for (final c in SeedData.allFlashcards) ...[
        c.wordEnglish,
        c.wordFilipino,
        if (c.exampleSentence != null) c.exampleSentence!,
      ],
    };
  });
  tearDownAll(() {
    File('build/live_lang_${Platform.environment['LIVE_SHARD'] ?? 'all'}.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_report));
  });

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
  };

  for (final (from, to) in const [('en', 'fil'), ('fil', 'en')]) {
    for (final entry in screens.entries) {
      if (entry.key == 'SplashScreen') continue;
      testWidgets('${entry.key} $from>$to', (tester) async {
        final (build, role) = entry.value;
        tester.view.physicalSize = const Size(800, 1280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = FlutterError.onError;
        FlutterError.onError = (_) {};
        final finished = Completer<void>();

        runZonedGuarded(() async {
          Future<ProviderContainer> open(String lang) async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pumpWidget(ProviderScope(
              overrides: [
                profileProvider.overrideWith(() => _Profile(role)),
                settingsProvider.overrideWith(() => _Settings(lang)),
              ],
              child: Consumer(
                builder: (context, ref, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.light,
                  locale: Locale(ref.watch(settingsProvider).locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: build(),
                ),
              ),
            ));
            for (var t = 0; t < 12; t++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            return ProviderScope.containerOf(
              tester.element(find.byType(Consumer).first),
            );
          }

          await open(to);
          final fresh = await _readAll(tester);
          final container = await open(from);
          final before = await _readAll(tester);
          container.read(settingsProvider.notifier).update(
                container.read(settingsProvider).copyWith(locale: to),
              );
          for (var t = 0; t < 12; t++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          final live = await _readAll(tester);
          final stale = live
              .where((t) =>
                  before.contains(t) &&
                  !fresh.contains(t) &&
                  !vocabulary.contains(t))
              .toList();
          if (stale.isNotEmpty) _report['${entry.key} $from>$to'] = stale;
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(minutes: 3));
          FlutterError.onError = old;
          finished.complete();
        }, (error, stack) {});
        await finished.future;
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  }
}
