import 'dart:typed_data';

/// Not a browser: a device shares files through the share sheet instead.
Future<void> downloadFile(
  Uint8List bytes, {
  required String name,
  required String mimeType,
}) =>
    throw UnsupportedError('Downloads are for the browser version.');

/// Not a browser: a device plays its own files.
String objectUrlFor(Uint8List bytes, {required String mimeType}) =>
    throw UnsupportedError('Object URLs are for the browser version.');

void revokeObjectUrl(String url) {}
