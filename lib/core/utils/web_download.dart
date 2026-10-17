/// The browser version's files: saving bytes as a download (exports, see
/// `ShareFile`), and an address for bytes held in memory (shared media, see
/// `WebMedia`). Only the web build has them; elsewhere they throw.
library;

export 'web_download_stub.dart'
    if (dart.library.js_interop) 'web_download_web.dart';
