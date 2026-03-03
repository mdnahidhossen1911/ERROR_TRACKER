# error_tracker

A production-ready Flutter package that captures all runtime errors — Flutter framework errors, unhandled async exceptions, and platform-level crashes — and prints structured, richly-contextualised logs to the console.

Designed with clean architecture so that remote API integration can be added in the future with zero refactoring.

---

## Features

| Capture mode | API |
|---|---|
| Flutter framework errors | `FlutterError.onError` |
| Unhandled async / zone errors | `runZonedGuarded` |
| Platform dispatcher errors | `PlatformDispatcher.instance.onError` |
| Manual log | `ErrorTracker.log(message, {stackTrace, level})` |
| API error log | `ErrorTracker.logApiError(endpoint, statusCode, message)` |

### Console output format

```
================ ERROR TRACKER ================
App: MyApp v1.0.0 (build 12)
Device: Google Pixel 8 (Android 14)
Network: WiFi
Battery: 76%
RAM: 8GB (Free: 3.2GB)
Storage: 128GB (Free: 45GB)
CPU Cores: 8
Performance: HIGH
App Memory: 118.4 MB
Physical Device: true
---
Type: FlutterError
Severity: ERROR
Message: Null check operator used on a null value
StackTrace:
#0  main.<anonymous closure> (package:example/main.dart:42:7)
  ... 4 more frames
Time: 2026-03-03 10:32:22
===============================================
```

---

## Getting started

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  error_tracker: ^1.0.0
```

Install:

```sh
flutter pub get
```

### Required permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.BATTERY_STATS"/>
```

**iOS** (`ios/Runner/Info.plist`) — no additional permissions needed for the
default feature set.

---

## Usage

### Setup — one line replaces your entire main()

```dart
import 'package:error_tracker/error_tracker.dart';

// BEFORE:
// void main() => runApp(const MyApp());

// AFTER — that's it, nothing else needed:
void main() => ErrorTracker.runApp(
  config: ErrorTrackerConfig(
    appName: 'MyApp',
    appVersion: '1.0.0',
    buildNumber: '12',
  ),
  app: const MyApp(),
);
```

Every error in your app is now captured automatically:

| What happens in your app | Auto-captured? |
|---|---|
| Widget throws in `build()` | ✅ Layer 1 — FlutterError |
| Null check crash (`!`) | ✅ Layer 1 — FlutterError |
| `Future` throws and nobody catches it | ✅ Layer 2 — Zone guard |
| `async/await` function throws | ✅ Layer 2 — Zone guard |
| Stream emits error with no handler | ✅ Layer 2 — Zone guard |
| Native/platform thread error | ✅ Layer 3 — PlatformDispatcher |
| Stack overflow | ✅ Layer 3 — PlatformDispatcher |

### Optional manual helpers (never required)

```dart
// If you want to log something specific manually:
ErrorTracker.log('User signed out', level: ErrorLevel.info);

// API errors:
ErrorTracker.logApiError(
  '/api/v1/orders',
  statusCode: response.statusCode,
  message: 'Failed to fetch orders',
);
```

---

## Configuration

| Option | Type | Default | Description |
|---|---|---|---|
| `appName` | `String` | required | App name shown in log header |
| `appVersion` | `String` | required | Semantic version string |
| `buildNumber` | `String` | required | Build number |
| `minimumLevel` | `ErrorLevel` | `info` | Minimum severity to log |
| `onError` | `void Function(ErrorRecord)?` | `null` | Hook for future API integration |
| `enableFlutterErrors` | `bool` | `true` | Register `FlutterError.onError` |
| `enableAsyncErrors` | `bool` | `true` | Expect `runZonedGuarded` in main |
| `enablePlatformErrors` | `bool` | `true` | Register `PlatformDispatcher.onError` |

---

## Architecture

```
error_tracker/
├── lib/
│   ├── error_tracker.dart          # Public barrel export
│   └── src/
│       ├── models/
│       │   ├── device_info.dart    # Immutable device snapshot
│       │   ├── error_record.dart   # Single error event
│       │   ├── error_level.dart    # Severity enum
│       │   └── error_type.dart     # Origin type enum
│       ├── services/
│       │   └── device_info_service.dart  # All device I/O isolated here
│       ├── logger/
│       │   └── console_logger.dart       # Formatting + output
│       └── tracker/
│           ├── error_tracker.dart        # Singleton + capture pipeline
│           └── error_tracker_config.dart # Configuration value object
├── test/
│   └── error_tracker_test.dart
└── example/
    └── lib/main.dart
```

### Adding remote API integration (future)

1. Create `lib/src/services/remote_reporter.dart` with your HTTP client.
2. Pass a callback to `ErrorTrackerConfig.onError`:

```dart
ErrorTrackerConfig(
  // ...
  onError: (record) => RemoteReporter.instance.send(record.toMap()),
)
```

No changes to tracker, logger, or device service required.

---

## Supported platforms

| Platform | Tested |
|---|---|
| Android | ✅ |
| iOS | ✅ |
| macOS | ✅ |
| Linux | ✅ |
| Windows | ✅ |
| Web | ⚠️ Partial (device info limited) |

---

## Dependencies

| Package | Purpose |
|---|---|
| [`device_info_plus`](https://pub.dev/packages/device_info_plus) | Device model, OS, SDK info |
| [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) | Network type detection |
| [`battery_plus`](https://pub.dev/packages/battery_plus) | Battery level |
| `dart:io` | CPU cores, memory, storage |

---

## License

MIT
