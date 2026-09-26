import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pwdpwdpwd/core/theme/app_theme.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';

import 'support/contrast.dart';

/// Every theme the app can show, and every standard control in it, must be
/// readable: 4.5:1 for text, 3:1 for large text (WCAG AA).
///
/// Found on a tablet: selected chips, the chosen segment of a toggle, and
/// white labels on the pastel buttons were all near-unreadable, in the
/// themes every learner and educator sees. A theme sets these once for the
/// whole app, so they are checked here once, for all of them.

/// Every theme the app can show, by name. Built lazily: the themes load
/// fonts, which needs the test binding.
Map<String, ThemeData Function()> allThemes() {
  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
    'high contrast': () => AppTheme.highContrast,
    'dyslexia': () => AppTheme.dyslexia,
  };
  for (final type in DisabilityType.values) {
    themes['high contrast ${type.name}'] = () => AppTheme.highContrastFor(type);
    for (final role in const [UserRole.student, UserRole.child]) {
      themes['learner ${type.name} ${role.name}'] =
          () => AppTheme.learnerTheme(type, role)!;
    }
    themes['learner dark ${type.name}'] = () => AppTheme.learnerThemeDark(type)!;
  }
  for (final role in const [UserRole.teacher, UserRole.parent]) {
    themes['group ${role.name}'] = () => AppTheme.groupTheme(role)!;
  }
  for (final id in const [
    'theme_ocean',
    'theme_sunset',
    'theme_forest',
    'theme_galaxy',
  ]) {
    themes['shop $id'] = () => AppTheme.shopTheme(id)!;
    themes['shop dark $id'] = () => AppTheme.shopThemeDark(id)!;
  }
  return themes;
}

/// The controls every screen is built from, each with a unique label.
class _Panel extends StatelessWidget {
  const _Panel();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AppBar title'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Tab on'), Tab(text: 'Tab off')],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Body text'),
            Text('Small text', style: Theme.of(context).textTheme.bodySmall),
            Text('Label text', style: Theme.of(context).textTheme.labelMedium),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text button')),
            FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            Wrap(
              children: [
                ChoiceChip(
                  label: const Text('Chip on'),
                  selected: true,
                  onSelected: (_) {},
                ),
                ChoiceChip(
                  label: const Text('Chip off'),
                  selected: false,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Filter on'),
                  selected: true,
                  onSelected: (_) {},
                ),
                FilterChip(
                  label: const Text('Filter off'),
                  onSelected: (_) {},
                ),
                const Chip(label: Text('Plain chip')),
                ActionChip(label: const Text('Action chip'), onPressed: () {}),
              ],
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('Segment on')),
                ButtonSegment(value: 2, label: Text('Segment off')),
              ],
              selected: const {1},
              onSelectionChanged: (_) {},
            ),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Field label',
                hintText: 'Field hint',
              ),
            ),
            const Card(
              child: ListTile(
                title: Text('Tile title'),
                subtitle: Text('Tile subtitle'),
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home), label: 'Nav on'),
            NavigationDestination(icon: Icon(Icons.star), label: 'Nav off'),
          ],
        ),
      ),
    );
  }
}

const _labels = [
  'AppBar title',
  'Tab on',
  'Tab off',
  'Body text',
  'Small text',
  'Label text',
  'Filled',
  'Elevated',
  'Outlined',
  'Text button',
  'Tonal',
  'Chip on',
  'Chip off',
  'Filter on',
  'Filter off',
  'Plain chip',
  'Action chip',
  'Segment on',
  'Segment off',
  'Field label',
  'Tile title',
  'Tile subtitle',
  'Nav on',
  'Nav off',
];

void main() {
  final themes = allThemes();

  test('every theme is covered', () {
    // 4 modes, 6 HC accents, 12 learner light, 6 learner dark, groups, shops.
    expect(themes.length, greaterThan(35));
  });

  for (final entry in themes.entries) {
    testWidgets('${entry.key}: every control is readable', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: entry.value(),
          home: const _Panel(),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final failures = <String>[];
      for (final label in _labels) {
        final reading = readLabel(tester, label);
        if (!reading.passes) failures.add(reading.toString());
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}
