import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<void> downloadTextFile(String filename, String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export words',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    bytes: bytes,
  );

  // Some desktop platforms return a path and expect the app to write.
  if (path != null && path.isNotEmpty) {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      await file.writeAsBytes(bytes, flush: true);
    }
  }
}
