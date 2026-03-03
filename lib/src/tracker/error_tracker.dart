import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../breadcrumbs/breadcrumb_manager.dart';
import '../logger/console_logger.dart';
import '../models/breadcrumb.dart';
import '../models/crash_report.dart';
import '../models/device_info.dart';
import '../models/error_level.dart';
import '../models/error_record.dart';
import '../models/error_type.dart';
import '../models/user_info.dart';
import '../reporter/fingerprint_generator.dart';
import '../reporter/remote_reporter.dart';
import '../services/device_info_service.dart';
import '../session/session_manager.dart';
import 'error_tracker_config.dart';

/// Production-ready global error tracker.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// SETUP — one line replaces your existing main():
///
///   void main() => ErrorTracker.runApp(
///     config: ErrorTrackerConfig(
///       appName: 'MyApp',
///       appVersion: '1.0.0',
///       buildNumber: '1',
///       // Optional: send to your own API
///       apiConfig: ErrorTrackerApiConfig(
///         endpoint: 'https://api.yourserver.com/v1/crashes',
///         apiKey: 'your-secret-key',
///       ),
///     ),
///     app: const MyApp(),
///   );
///
/// ─────────────────────────────────────────────────────────────────────────────
/// AUTOMATIC CAPTURE LAYERS:
///
///   Layer 1 — FlutterError.onError
///     Widget build, layout, rendering, setState-on-disposed errors
///
///   Layer 2 — runZonedGuarded (zone guard)
///     All unhandled Future, async/await, Stream errors
///
///   Layer 3 — PlatformDispatcher.instance.onError
///     Native/platform errors that escape layers 1 & 2
///
/// ─────────────────────────────────────────────────────────────────────────────
/// CRASHLYTICS-EQUIVALENT FEATURES:
///   • Remote reporting  — POST JSON to your REST API
///   • Issue grouping    — fingerprint-based (same crash = same group)
///   • Fatal / Non-fatal — classified per capture layer
///   • Breadcrumbs       — 50-event circular trail before every crash
///   • Session tracking  — session ID + age attached to every report
///   • User context      — id, email, name via setUser()
///   • Custom keys       — arbitrary k/v pairs via setCustomKey()
///   • Offline queue     — persisted locally, auto-flushed on reconnect
///   • Structured logs   — always printed to console regardless of API
class ErrorTracker {
  ErrorTracker._({
    required ErrorTrackerConfig config,
    required DeviceInfoService deviceInfoService,
    required ConsoleLogger logger,
    required BreadcrumbManager breadcrumbs,
    required SessionManager session,
    RemoteReporter? reporter,
  })  : _config = config,
        _deviceInfoService = deviceInfoService,
        _logger = logger,
        _breadcrumbs = breadcrumbs,
        _session = session,
        _reporter = reporter;

  final ErrorTrackerConfig _config;
  final DeviceInfoService _deviceInfoService;
  final ConsoleLogger _logger;
  final BreadcrumbManager _breadcrumbs;
  final SessionManager _session;
  final RemoteReporter? _reporter;  // null = console-only mode

  UserInfo? _userInfo;
  final Map<String, dynamic> _customKeys = {};

  static ErrorTracker? _instance;

  // ===========================================================================
  // PRIMARY ENTRY POINT
  // ===========================================================================

  /// Drop-in replacement for Flutter's runApp().
  ///
  /// Registers all capture layers, wires the API reporter (if configured),
  /// then starts the app. Nothing else is needed anywhere in the project.
  static void runApp({
    required ErrorTrackerConfig config,
    required Widget app,
    DeviceInfoService? deviceInfoService,
    ConsoleLogger? logger,
    BreadcrumbManager? breadcrumbs,
    SessionManager? session,
    RemoteReporter? reporter,
  }) {
    runZonedGuarded(
      () async {
        WidgetsFlutterBinding.ensureInitialized();

        _instance = ErrorTracker._(
          config: config,
          deviceInfoService: deviceInfoService ?? DeviceInfoService(),
          logger: logger ?? const ConsoleLogger(),
          breadcrumbs: breadcrumbs ?? BreadcrumbManager(),
          session: session ?? SessionManager(),
          // Build reporter only when API config is provided.
          reporter: reporter ??
              (config.apiConfig != null
                  ? RemoteReporter(apiConfig: config.apiConfig!)
                  : null),
        );

        _instance!._registerFlutterErrorHandler();
        _instance!._registerPlatformErrorHandler();

        _runApp(app);
      },
      // Layer 2 — zone guard for all async errors
      (Object error, StackTrace stack) {
        _instance?._capture(
          message: error.toString(),
          type: ErrorType.async,
          level: ErrorLevel.error,
          isFatal: false,
          stackTrace: stack,
        );
      },
    );
  }

  // ===========================================================================
  // ADVANCED INIT
  // ===========================================================================

  /// For custom setups / testing. Prefer [runApp] for production.
  static Future<void> init(
    ErrorTrackerConfig config, {
    DeviceInfoService? deviceInfoService,
    ConsoleLogger? logger,
    BreadcrumbManager? breadcrumbs,
    SessionManager? session,
    RemoteReporter? reporter,
  }) async {
    _instance = ErrorTracker._(
      config: config,
      deviceInfoService: deviceInfoService ?? DeviceInfoService(),
      logger: logger ?? const ConsoleLogger(),
      breadcrumbs: breadcrumbs ?? BreadcrumbManager(),
      session: session ?? SessionManager(),
      reporter: reporter ??
          (config.apiConfig != null
              ? RemoteReporter(apiConfig: config.apiConfig!)
              : null),
    );
    _instance!._registerFlutterErrorHandler();
    _instance!._registerPlatformErrorHandler();
  }

  static void handleZoneError(Object error, StackTrace stack) {
    _instance?._capture(
      message: error.toString(),
      type: ErrorType.async,
      level: ErrorLevel.error,
      isFatal: false,
      stackTrace: stack,
    );
  }

  // ===========================================================================
  // USER CONTEXT
  // ===========================================================================

  /// Set user info attached to all subsequent reports.
  /// Call after login. Pass null to clear on logout.
  ///
  /// ```dart
  /// ErrorTracker.setUser(UserInfo(id: '42', email: 'user@app.com'));
  /// ```
  static void setUser(UserInfo? user) => _instance?._userInfo = user;

  // ===========================================================================
  // CUSTOM KEYS
  // ===========================================================================

  /// Attach a key-value pair to all subsequent reports.
  ///
  /// ```dart
  /// ErrorTracker.setCustomKey('plan', 'premium');
  /// ErrorTracker.setCustomKey('cart_items', 3);
  /// ```
  static void setCustomKey(String key, dynamic value) =>
      _instance?._customKeys[key] = value;

  static void removeCustomKey(String key) =>
      _instance?._customKeys.remove(key);

  // ===========================================================================
  // BREADCRUMBS
  // ===========================================================================

  /// Record a screen/route navigation.
  /// ```dart
  /// ErrorTracker.navigation('/checkout');
  /// ```
  static void navigation(String route, {Map<String, dynamic>? params}) =>
      _instance?._breadcrumbs.navigation(route, params: params);

  /// Record a user action (button tap, gesture, form submit, etc).
  /// ```dart
  /// ErrorTracker.action('tapped_pay_button');
  /// ```
  static void action(String description, {Map<String, dynamic>? data}) =>
      _instance?._breadcrumbs.userAction(description, data: data);

  /// Record an outgoing HTTP request.
  /// ```dart
  /// ErrorTracker.networkCall('POST', '/api/v1/orders', statusCode: 201);
  /// ```
  static void networkCall(String method, String url, {int? statusCode}) =>
      _instance?._breadcrumbs.network(method, url, statusCode: statusCode);

  /// Record an app state change.
  /// ```dart
  /// ErrorTracker.stateChange('cart_cleared');
  /// ```
  static void stateChange(String description, {Map<String, dynamic>? data}) =>
      _instance?._breadcrumbs.stateChange(description, data: data);

  /// Add a raw [Breadcrumb] directly.
  static void addBreadcrumb(Breadcrumb breadcrumb) =>
      _instance?._breadcrumbs.add(breadcrumb);

  // ===========================================================================
  // OPTIONAL MANUAL LOGGING
  // ===========================================================================

  /// Log a message manually with optional stack trace and severity.
  ///
  /// ```dart
  /// ErrorTracker.log('Payment timeout', level: ErrorLevel.warning);
  /// ```
  static void log(
    String message, {
    StackTrace? stackTrace,
    ErrorLevel level = ErrorLevel.info,
  }) {
    _instance?._capture(
      message: message,
      type: ErrorType.manual,
      level: level,
      isFatal: false,
      stackTrace: stackTrace,
    );
  }

  /// Log an HTTP API error with endpoint + status context.
  ///
  /// ```dart
  /// ErrorTracker.logApiError('/api/orders', statusCode: 503, message: 'Service down');
  /// ```
  static void logApiError(
    String endpoint, {
    required int statusCode,
    required String message,
    StackTrace? stackTrace,
  }) {
    _instance?._capture(
      message: message,
      type: ErrorType.api,
      level: statusCode >= 500
          ? ErrorLevel.critical
          : statusCode >= 400
              ? ErrorLevel.error
              : ErrorLevel.warning,
      isFatal: false,
      stackTrace: stackTrace,
      endpoint: endpoint,
      statusCode: statusCode,
    );
  }

  // ===========================================================================
  // OFFLINE QUEUE
  // ===========================================================================

  /// Manually flush the offline queue.
  /// Call this when your app detects connectivity restored.
  ///
  /// ```dart
  /// connectivity.onConnectivityChanged.listen((_) {
  ///   ErrorTracker.flushOfflineQueue();
  /// });
  /// ```
  static Future<void> flushOfflineQueue() async =>
      _instance?._reporter?.flushOfflineQueue();

  /// Number of reports waiting to be sent.
  static Future<int> get pendingQueueCount async =>
      await _instance?._reporter?.pendingCount ?? 0;

  // ===========================================================================
  // PRIVATE — LAYER REGISTRATIONS
  // ===========================================================================

  /// Layer 1 — Flutter framework errors.
  void _registerFlutterErrorHandler() {
    final previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _capture(
        message: details.exceptionAsString(),
        type: ErrorType.flutter,
        level: details.silent ? ErrorLevel.warning : ErrorLevel.error,
        isFatal: false,
        stackTrace: details.stack,
        extra: {
          'library': details.library ?? 'unknown',
          'context': details.context?.toString() ?? '',
        },
      );
      previous?.call(details);
    };
  }

  /// Layer 3 — Platform dispatcher errors.
  void _registerPlatformErrorHandler() {
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _capture(
        message: error.toString(),
        type: ErrorType.platform,
        level: ErrorLevel.critical,
        isFatal: true,
        stackTrace: stack,
      );
      return previous?.call(error, stack) ?? true;
    };
  }

  // ===========================================================================
  // PRIVATE — CAPTURE PIPELINE
  // ===========================================================================

  void _capture({
    required String message,
    required ErrorType type,
    required ErrorLevel level,
    required bool isFatal,
    StackTrace? stackTrace,
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? extra,
  }) {
    if (level.index < _config.minimumLevel.index) return;
    _processCapture(
      message: message,
      type: type,
      level: level,
      isFatal: isFatal,
      stackTrace: stackTrace,
      endpoint: endpoint,
      statusCode: statusCode,
      extra: extra,
    ).ignore(); // fire-and-forget — never blocks UI thread
  }

  Future<void> _processCapture({
    required String message,
    required ErrorType type,
    required ErrorLevel level,
    required bool isFatal,
    StackTrace? stackTrace,
    String? endpoint,
    int? statusCode,
    Map<String, dynamic>? extra,
  }) async {
    try {
      // 1. Collect device snapshot (runs in parallel internally)
      final DeviceInfo deviceInfo = await _deviceInfoService.collect(
        appName: _config.appName,
        appVersion: _config.appVersion,
        buildNumber: _config.buildNumber,
      );

      // 2. Always log to console first (instant, no network dependency)
      final record = ErrorRecord(
        message: message,
        type: type,
        level: level,
        deviceInfo: deviceInfo,
        stackTrace: stackTrace,
        endpoint: endpoint,
        statusCode: statusCode,
        extra: extra,
      );
      _logger.log(record);

      // 3. Build full report (includes breadcrumbs, session, fingerprint, user)
      final fingerprint = FingerprintGenerator.generate(
        message: message,
        stackTrace: stackTrace,
      );

      final report = CrashReport(
        message: message,
        type: type,
        level: level,
        isFatal: isFatal,
        deviceInfo: deviceInfo,
        sessionId: _session.sessionId,
        appLaunchTime: _session.launchTime,
        breadcrumbs: _breadcrumbs.snapshot,
        stackTrace: stackTrace,
        fingerprint: fingerprint,
        endpoint: endpoint,
        statusCode: statusCode,
        userInfo: _userInfo,
        customKeys: _customKeys.isEmpty ? null : Map.of(_customKeys),
      );

      // 4. Send to REST API (or queue if offline) — only if configured
      if (_reporter != null) {
        await _reporter!.send(report);
      }

      // 5. Developer callback hook (optional custom sink)
      _config.onReport?.call(report);
      _config.onError?.call(record); // legacy compat
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ErrorTracker] Internal capture error: $e');
      }
    }
  }
}

void _runApp(Widget app) => runApp(app);
