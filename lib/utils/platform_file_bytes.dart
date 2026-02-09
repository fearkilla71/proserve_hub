import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'platform_file_bytes_stub.dart'
    if (dart.library.io) 'platform_file_bytes_io.dart'
    if (dart.library.html) 'platform_file_bytes_web.dart'
    as impl;

/// Returns bytes for a [PlatformFile] across platforms.
///
/// - On web: uses [PlatformFile.bytes]
/// - On IO platforms: uses [PlatformFile.bytes] if present, otherwise reads from [PlatformFile.path]
Future<Uint8List?> readPlatformFileBytes(PlatformFile file) =>
    impl.readPlatformFileBytes(file);
