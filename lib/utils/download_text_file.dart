export 'download_text_file_stub.dart'
    if (dart.library.html) 'download_text_file_web.dart'
    if (dart.library.io) 'download_text_file_io.dart';
