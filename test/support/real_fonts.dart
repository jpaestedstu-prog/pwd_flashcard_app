import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads the app's own fonts into a widget test, under the family names the
/// google_fonts package asks for ("Quicksand_700", "Nunito_regular", …), plus
/// the Material icons.
///
/// `flutter test` otherwise draws every glyph a full em wide, almost twice the
/// app's real fonts, so a layout check sees rows overflow that fit on a
/// device, and misses none that do not: it cannot tell the two apart. With
/// these fonts a row that overflows in the test overflows on a phone.
///
/// Call once, from `setUpAll`. Weights the app does not bundle are filled by
/// the nearest file there is.
Future<void> loadRealFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  const weights = {
    'Regular': 'regular',
    'Medium': '500',
    'SemiBold': '600',
    'Bold': '700',
    'ExtraBold': '800',
    'Black': '900',
  };
  final byFamily = <String, Map<String, File>>{};
  for (final f in Directory('google_fonts').listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.endsWith('.ttf')) continue;
    final stem = name.substring(0, name.length - 4);
    final dash = stem.lastIndexOf('-');
    if (dash < 0) continue;
    final weight = weights[stem.substring(dash + 1)];
    if (weight == null) continue;
    (byFamily[stem.substring(0, dash)] ??= {})[weight] = f;
  }
  const order = ['regular', '300', '500', '600', '700', '800', '900'];
  for (final MapEntry(key: family, value: files) in byFamily.entries) {
    for (final w in order) {
      final file = files[w] ??
          files[order.firstWhere(files.containsKey, orElse: () => 'regular')] ??
          files.values.first;
      final loader = FontLoader('${family}_$w')
        ..addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      await loader.load();
    }
  }

  // The Material icons ship with the SDK: <sdk>/bin/cache/artifacts/
  // material_fonts. flutter_tester runs from inside that cache.
  final exe = Platform.resolvedExecutable.replaceAll(r'\', '/');
  final cache = exe.indexOf('/bin/cache/');
  if (cache >= 0) {
    final icons = File('${exe.substring(0, cache)}/bin/cache/artifacts/'
        'material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
    }
  }
}
