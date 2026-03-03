import '../models/crash_report.dart';
import '../models/error_level.dart';
import '../models/error_record.dart';

/// Configuration for [ErrorTracker.runApp] / [ErrorTracker.init].
///
/// Minimal setup (console-only):
/// ```dart
/// ErrorTrackerConfig(
///   appName: 'MyApp', appVersion: '1.0.0', buildNumber: '1',
/// )
/// ```
///
/// With remote reporting:
/// ```dart
/// ErrorTrackerConfig(
///   appName: 'MyApp', appVersion: '1.0.0', buildNumber: '1',
///   apiConfig: ErrorTrackerApiConfig(
///     endpoint: 'https://api.yourserver.com/v1/crashes',
///     apiKey: 'your-secret-key',
///   ),
/// )
/// ```
class ErrorTrackerConfig {
  const ErrorTrackerConfig({
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    this.minimumLevel = ErrorLevel.info,
    this.apiConfig,
    this.enableFlutterErrors = true,
    this.enableAsyncErrors = true,
    this.enablePlatformErrors = true,
    this.onReport,
    this.onError,
  });

  final String appName;
  final String appVersion;
  final String buildNumber;

  /// Errors below this severity are silently dropped.
  final ErrorLevel minimumLevel;

  /// When set, crash reports are sent to your REST API.
  /// Leave null for console-only mode.
  final ErrorTrackerApiConfig? apiConfig;

  final bool enableFlutterErrors;
  final bool enableAsyncErrors;
  final bool enablePlatformErrors;

  /// Called after every crash report is built (before sending).
  /// Use for custom sinks, analytics pipelines, or UI alerts.
  final void Function(CrashReport report)? onReport;

  /// Legacy callback — kept for backward compatibility.
  final void Function(ErrorRecord record)? onError;

  /// Whether remote reporting is active.
  bool get enableRemoteReporting => apiConfig != null;
}

/// HTTP transport configuration for the REST API reporter.
class ErrorTrackerApiConfig {
  const ErrorTrackerApiConfig({
    required this.endpoint,
    this.apiKey,
    this.headers,
    this.timeoutSeconds = 10,
    this.maxRetries = 3,
  });

  /// Full URL that accepts POST requests with a JSON body.
  /// Example: 'https://api.example.com/v1/crash-reports'
  final String endpoint;

  /// Sent as the `X-Api-Key` header. Optional if your server
  /// uses a different auth scheme — use [headers] instead.
  final String? apiKey;

  /// Additional HTTP headers merged into every request.
  final Map<String, String>? headers;

  /// Request timeout in seconds (default 10).
  final int timeoutSeconds;

  /// How many times to retry a failed request before queuing (default 3).
  final int maxRetries;

  /// Builds the resolved header map for an HTTP request.
  Map<String, String> get resolvedHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (apiKey != null) 'X-Api-Key': apiKey!,
        ...?headers,
      };
}
