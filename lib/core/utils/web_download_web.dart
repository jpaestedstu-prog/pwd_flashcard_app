import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Downloads [bytes] as a file called [name], the way a link with a
/// `download` name does: into the browser's Downloads, on a computer as on
/// a phone. (The printing package downloads its PDFs the same way.)
Future<void> downloadFile(
  Uint8List bytes, {
  required String name,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  // The browser has the file once the click is handled; the address is
  // let go a little later, so a slow browser still finds it.
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}

/// An address (`blob:…`) a browser's video, audio or image element can
/// open for [bytes]: how the browser version plays a file it fetched into
/// memory (a shared clip). Valid until [revokeObjectUrl] or the page closes.
String objectUrlFor(Uint8List bytes, {required String mimeType}) =>
    web.URL.createObjectURL(
      web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType)),
    );

/// Lets the browser free what [objectUrlFor] made.
void revokeObjectUrl(String url) => web.URL.revokeObjectURL(url);
