/// error_tracker — Custom REST API crash tracking for Flutter.
///
/// Zero Firebase dependency. Ships your crash reports to any HTTP server.
///
/// Features:
///   • Automatic capture (Flutter + async + platform) — 3 layers
///   • Custom REST API reporting (POST JSON)
///   • Issue grouping by fingerprint
///   • Fatal vs non-fatal classification
///   • Breadcrumb trail (50 events before crash)
///   • User session tracking (ID + age)
///   • User context (id, email, name)
///   • Custom key-value pairs
///   • Offline queue with auto-retry (SharedPreferences)
///   • Structured console logging (always on)
library error_tracker;

export 'src/models/breadcrumb.dart';
export 'src/models/crash_report.dart';
export 'src/models/device_info.dart';
export 'src/models/error_level.dart';
export 'src/models/error_record.dart';
export 'src/models/error_type.dart';
export 'src/models/user_info.dart';
export 'src/tracker/error_tracker.dart';
export 'src/tracker/error_tracker_config.dart';
