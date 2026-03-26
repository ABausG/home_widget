import 'dart:convert';

/// Minimal valid 1x1 PNG (transparent).
const String kTestPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==';

final kTestPngBytes = base64Decode(kTestPngBase64);
