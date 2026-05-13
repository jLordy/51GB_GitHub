/// Platform-conditional PDF save/open helper.
///
/// On web   → triggers a browser file download via dart:html.
/// On iOS/Android/Desktop → saves to the temp directory and opens with OpenFilex.
library;
export 'pdf_saver_stub.dart'
    if (dart.library.html) 'pdf_saver_web.dart'
    if (dart.library.io) 'pdf_saver_io.dart';
