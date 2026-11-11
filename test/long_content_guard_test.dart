import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart' show AppSettings, UserProfile;
import 'package:pwdpwdpwd/features/parent/screens/child_alarms_screen.dart';
import 'package:pwdpwdpwd/features/parent/screens/educator_dashboard_screen.dart';
import 'package:pwdpwdpwd/features/routine/screens/routine_editor_screen.dart';
import 'package:pwdpwdpwd/l10n/app_localizations.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart'
    show ProfileNotifier, SettingsNotifier, profileProvider, settingsProvider;

import 'support/all_screens.dart';
import 'support/contrast.dart' show appSourceOf;
import 'support/drill_down_screens.dart';
import 'support/long_content.dart';
import 'support/real_fonts.dart';

/// Every screen on a small phone at the largest text size, with the store full
/// of the longest text people may type: no screen runs out of its box, and no
/// name, title or word ends in "…".
///
/// Only two places may: each is a one-line look at something that opens whole.
const _previews = {
  // A conversation's last message, in the list of conversations.
  'lib/features/messaging/screens/messaging_screen.dart',
  // A note's text, in the list of notes.
  'lib/features/notebook/screens/notebook_screen.dart',
};

const _me = 'sweep-profile';

class _Profile extends ProfileNotifier {
  _Profile(this.role);
  final UserRole role;
  @override
  UserProfile? build() => UserProfile(
        id: _me,
        name: longName,
        role: role,
        disabilityType: DisabilityType.visual,
        createdAt: DateTime(2026),
        classroomId: role == UserRole.student ? 'long-class' : null,
        homeGroupId: role == UserRole.child ? 'long-group' : null,
        section: longSection,
      );
}

class _Fil extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings(locale: 'fil');
}

void main() {
  setUpAll(() async {
    await loadRealFonts();
    await openMemoryBoxes('long_guard');
    await seedLongContent(_me);
  });

  final screens = <String, (Widget Function(), UserRole)>{
    ...kAllScreens,
    for (final e in kDrillDownScreens.entries)
      e.key: (e.value, UserRole.student),
    'ChildAlarmsScreen': (
      () => const ChildAlarmsScreen(childProfileId: 'long-1'),
      UserRole.teacher
    ),
    'RoutineEditorScreen': (
      () => const RoutineEditorScreen(childProfileId: 'long-1'),
      UserRole.teacher
    ),
    'EducatorDashboardScreen (teacher)': (
      () => const EducatorDashboardScreen(audience: EducatorAudience.teacher),
      UserRole.teacher
    ),
    'EducatorDashboardScreen (parent)': (
      () => const EducatorDashboardScreen(audience: EducatorAudience.parent),
      UserRole.parent
    ),
    'MessagingScreen (teacher)': (
      kAllScreens['MessagingScreen']!.$1,
      UserRole.teacher
    ),
    'ClassroomDashboardScreen (parent)': (
      kAllScreens['ClassroomDashboardScreen']!.$1,
      UserRole.parent
    ),
    'HomeScreen (child)': (kAllScreens['ChildHomeScreen']!.$1, UserRole.child),
  };

  for (final lang in const ['en', 'fil']) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} $lang', (tester) async {
        final (build, role) = entry.value;
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final old = FlutterError.onError;
        final problems = <String>{};
        FlutterError.onError = (d) {
          final m = d.exceptionAsString();
          if (m.contains('No GoRouter')) return;
          final src = RegExp(r'lib/[\w/.]+\.dart:\d+')
              .firstMatch(d.toString())
              ?.group(0);
          problems.add('${m.split('\n').first} at $src');
        };
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              profileProvider.overrideWith(() => _Profile(role)),
              if (lang == 'fil') settingsProvider.overrideWith(_Fil.new),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              locale: Locale(lang),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: build(),
            ),
          ),
        );
        for (var t = 0; t < (entry.key == 'SplashScreen' ? 20 : 25); t++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final cut = <String>{};
        final previews = <String>{};

        void collect() {
          for (final rp in tester.renderObjectList<RenderParagraph>(
            find.byType(RichText),
          )) {
            if (!rp.hasSize || rp.size.isEmpty || !rp.didExceedMaxLines) {
              continue;
            }
            final creator = rp.debugCreator;
            final where = creator is DebugCreator
                ? appSourceOf(creator.element) ?? '?'
                : '?';
            if (_previews.any(where.startsWith)) {
              previews.add(where);
              continue;
            }
            final plain = rp.text.toPlainText(includeSemanticsLabels: false);
            cut.add('$where | ${plain.length > 60 ? plain.substring(0, 60) : plain}');
          }
        }

        collect();
        if (entry.key != 'SplashScreen') {
          final scrollables = find
              .byWidgetPredicate((w) =>
                  w is Scrollable &&
                  axisDirectionToAxis(w.axisDirection) == Axis.vertical)
              .evaluate()
              .toList();
          for (final e in scrollables.take(3)) {
            final state = (e as StatefulElement).state;
            if (state is! ScrollableState) continue;
            final position = state.position;
            if (!position.hasContentDimensions ||
                !position.hasViewportDimension) {
              continue;
            }
            final step = position.viewportDimension * 0.8;
            if (step <= 0) continue;
            for (var i = 1; i <= 25; i++) {
              final target = (step * i).clamp(0.0, position.maxScrollExtent);
              if (!e.mounted) break;
              position.jumpTo(target);
              await tester.pump(const Duration(milliseconds: 200));
              await tester.pump(const Duration(milliseconds: 200));
              collect();
              if (target >= position.maxScrollExtent) break;
            }
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 6));
        FlutterError.onError = old;
        expect(problems, isEmpty, reason: 'ran out of its box');
        expect(cut, isEmpty, reason: 'cut short');
        // And the check can see a cut at all: these two are always there.
        for (final (screen, file) in const [
          ('NotebookScreen', 'notebook_screen'),
          ('MessagingScreen (teacher)', 'messaging_screen'),
        ]) {
          if (entry.key == screen) {
            expect(previews.any((w) => w.contains(file)), isTrue);
          }
        }
      });
    }
  }
}
