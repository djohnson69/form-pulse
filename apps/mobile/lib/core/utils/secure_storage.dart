// Platform-aware secure storage wrapper. Falls back to an in-memory stub when
// no supported backend is available (e.g., tests or unsupported platforms).
export 'secure_storage_stub.dart'
    if (dart.library.html) 'secure_storage_web.dart'
    if (dart.library.io) 'secure_storage_io.dart';
