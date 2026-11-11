import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pwdpwdpwd/core/utils/slow_motion.dart';
import 'package:pwdpwdpwd/core/widgets/page_frame.dart';
import 'package:pwdpwdpwd/data/models/enums.dart';
import 'package:pwdpwdpwd/data/models/models.dart';
import 'package:pwdpwdpwd/features/flashcards/screens/deck_list_screen.dart';
import 'package:pwdpwdpwd/navigation/app_router.dart';
import 'package:pwdpwdpwd/providers/app_providers.dart';

/// A link whose category is not a number opens the deck list.
///
/// The two category routes read the number with `int.parse`, so a link such
/// as `/flashcards/viewer/abc` (typed into the web app's address bar, or left
/// over in a bookmark) threw a FormatException while the page was built.
/// A number out of range already opened the deck list; anything that is not
/// a number now does the same (the audit, 9 Nov).
class _StubProfile extends ProfileNotifier {
  @override
  UserProfile? build() => UserProfile(
        id: 'route-bad-category',
        name: 'Ana',
        role: UserRole.student,
        createdAt: DateTime(2026),
      );
}

/// Every route with the full path it is reached by.
Map<String, GoRoute> _routes(List<RouteBase> routes, String prefix) {
  final out = <String, GoRoute>{};
  for (final route in routes) {
    var here = prefix;
    if (route is GoRoute) {
      here = route.path.startsWith('/') ? route.path : '$prefix/${route.path}';
      out[here] = route;
    }
    out.addAll(_routes(route.routes, here));
  }
  return out;
}

void main() {
  late GoRouter router;
  late Map<String, GoRoute> routes;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final container = ProviderContainer(
      overrides: [profileProvider.overrideWith(_StubProfile.new)],
    );
    addTearDown(container.dispose);
    router = container.read(routerProvider);
    routes = _routes(router.configuration.routes, '');
  });

  Widget pageFor(BuildContext context, String fullPath, String category) {
    final route = routes[fullPath];
    expect(route, isNotNull, reason: '$fullPath is a route');
    final location = fullPath.replaceFirst(':category', category);
    final page = route!.pageBuilder!(
      context,
      GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: location,
        fullPath: fullPath,
        pathParameters: {'category': category},
        pageKey: ValueKey<String>(location),
      ),
    );
    var child = switch (page) {
      CupertinoPage<void>(:final child) => child,
      CustomTransitionPage<void>(:final child) => child,
      MaterialPage<void>(:final child) => child,
      _ => throw StateError('a ${page.runtimeType} for $location'),
    };
    // The frames every page is drawn in.
    while (true) {
      if (child is PageFrame) {
        child = child.child;
      } else if (child is SlowMotionScope) {
        child = child.child;
      } else {
        return child;
      }
    }
  }

  for (final path in const [
    '/flashcards/viewer/:category',
    '/learning-path-viewer/:category',
  ]) {
    testWidgets('$path: not a number opens the deck list', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final context = tester.element(find.byType(SizedBox));

      for (final bad in const ['abc', '', '2x', '99']) {
        expect(pageFor(context, path, bad), isA<DeckListScreen>(),
            reason: '"$bad" is not a category: the deck list');
      }
      expect(pageFor(context, path, '${FlashcardCategory.animals.index}'),
          isNot(isA<DeckListScreen>()),
          reason: 'a real category opens its cards');
    });
  }
}
