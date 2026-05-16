import 'app_startup_stub.dart'
    if (dart.library.io) 'app_startup_io.dart'
    as app_startup_impl;

Future<void> initializeDesktopWindow() =>
    app_startup_impl.initializeDesktopWindow();

Future<void> initializePlatformSpecific() =>
    app_startup_impl.initializePlatformSpecific();

Future<void> initDatabaseSafely() => app_startup_impl.initDatabaseSafely();
