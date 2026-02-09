import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> readPlatformFileBytes(PlatformFile file) async {
  // Fallback (should be overridden by conditional imports).
  return file.bytes;
}
