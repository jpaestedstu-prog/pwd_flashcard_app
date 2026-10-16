import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pwdpwdpwd/core/services/fsl_clip_quality.dart';
import 'package:pwdpwdpwd/core/services/sync_queue/sync_queue_storage.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/settings/screens/settings_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

import 'support/readability.dart';

/// The WHOLE Settings list on a phone, top to bottom, at the large text
/// sizes. The device matrices lay out only the first screenful of Settings;
/// the rows further down (reminders, language, data, sign videos) were never
/// laid out at 2.0x on a phone, which is where a value control beside a
/// row's name ("Change", the language menu, a slider) squeezed the name
/// until its words broke, or pushed the row past the screen's edge.

class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._role);
  final UserRole _role;

  @override
  UserProfile? build() => UserProfile(
        id: 'test-profile',
        name: 'Test User',
        role: _role,
        createdAt: DateTime(2026),
      );
}

/// Keeps the Sign videos choice in memory: no Hive write from a widget test.
class _MemoryChoice extends FslQualityChoiceNotifier {
  @override
  FslQualityChoice build() => FslQualityChoice.auto;

  @override
  Future<void> set(FslQualityChoice choice) async => state = choice;
}

/// The text inside [flex], for naming a row that does not fit.
String _texts(RenderObject flex) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) out.add(o.text.toPlainText());
    o.visitChildren(visit);
  }

  visit(flex);
  return out.join(' | ');
}

/// Horizontal rows whose children are wider than the row itself.
Iterable<String> _overflowingRows(WidgetTester tester) sync* {
  final found = <RenderFlex>[];
  void walk(RenderObject o) {
    if (o is RenderFlex && o.direction == Axis.horizontal && o.hasSize) {
      var total = 0.0;
      o.visitChildren((c) {
        if (c is RenderBox && c.hasSize) total += c.size.width;
      });
      if (total > o.size.width + 0.5) found.add(o);
    }
    o.visitChildren(walk);
  }

  for (final view in tester.binding.renderViews) {
    walk(view);
  }
  for (final flex in found) {
    yield 'row overflows: ${_texts(flex)}';
  }
}

void main() {
  setUpAll(() async {
    Hive.init('./build/test_cache/settings_phone_text');
    for (final name in const <String>[
      'profiles',
      'settings',
      'progress',
      'custom_cards',
      'sessions',
    ]) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox(name, compactionStrategy: (_, _) => false);
      }
    }
    // The Settings screen's Cloud Sync tile reads the sync-queue box.
    await SyncQueueStorage.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk()
        .timeout(const Duration(seconds: 15), onTimeout: () => <void>[]);
  });

  for (final role in const [UserRole.student, UserRole.teacher]) {
    for (final locale in const [Locale('en'), Locale('fil')]) {
      for (final scale in const [1.0, 1.4, 2.0]) {
        testWidgets(
            'Settings (${role.name}) reads whole on a phone at ${scale}x '
            '(${locale.languageCode})', (tester) async {
          tester.view.physicalSize = const Size(360, 640) * 2.0;
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = ProviderContainer(overrides: [
            profileProvider.overrideWith(() => _StubProfileNotifier(role)),
            fslQualityChoiceProvider.overrideWith(_MemoryChoice.new),
          ]);
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: locale,
                localizationsDelegates:
                    AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const SettingsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final problems = <String>{};
          void collect() {
            final error = tester.takeException();
            if (error != null) {
              problems.add(error.toString().split('\n').first);
            }
            problems.addAll(_overflowingRows(tester));
            for (final issue in findReadabilityIssues(tester)) {
              problems.add('$issue');
            }
          }

          // Top to bottom, a part of a screen at a time, looking at every
          // row as it comes into view.
          final list = find.byType(Scrollable).first;
          final position =
              tester.state<ScrollableState>(list).position;
          collect();
          for (var i = 0; i < 400 && position.extentAfter > 0; i++) {
            await tester.drag(list, const Offset(0, -250));
            await tester.pump();
            collect();
          }
          await tester.pumpAndSettle();
          collect();
          expect(position.extentAfter, 0, reason: 'reached the end');

          expect(problems, isEmpty,
              reason: '${role.name}, ${scale}x, ${locale.languageCode}:\n  '
                  '${problems.join('\n  ')}');
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
