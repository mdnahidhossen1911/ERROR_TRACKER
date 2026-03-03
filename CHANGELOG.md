## 1.0.0

- Initial release.
- Capture Flutter framework errors via `FlutterError.onError`.
- Capture unhandled async errors via `runZonedGuarded` + `ErrorTracker.handleZoneError`.
- Capture platform errors via `PlatformDispatcher.instance.onError`.
- Manual logging: `ErrorTracker.log(message, {stackTrace, level})`.
- API error logging: `ErrorTracker.logApiError(endpoint, statusCode, message)`.
- Rich device context: model, brand, OS, SDK, battery, network, RAM, storage,
  CPU cores, app memory, performance tier, physical device flag.
- Structured console output block via `dart:developer`.
- Clean modular architecture with `DeviceInfoService` and `ConsoleLogger`
  isolated from tracker logic.
- `ErrorTrackerConfig.onError` hook for zero-refactor future API integration.
- Minimum severity filter via `ErrorTrackerConfig.minimumLevel`.
- Non-blocking: all device I/O is async and fire-and-forget.
