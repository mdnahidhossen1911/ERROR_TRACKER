import 'package:uuid/uuid.dart';
import '../models/breadcrumb.dart';
import '../models/device_info.dart';
import '../models/error_level.dart';
import '../models/error_type.dart';
import '../models/user_info.dart';

/// Full crash report sent to Firebase / remote backend.
/// Contains everything Crashlytics would capture.
class CrashReport {
  CrashReport({
    String? id,
    required this.message,
    required this.type,
    required this.level,
    required this.isFatal,
    required this.deviceInfo,
    required this.sessionId,
    required this.appLaunchTime,
    required this.breadcrumbs,
    this.stackTrace,
    this.fingerprint,
    this.endpoint,
    this.statusCode,
    this.userInfo,
    this.customKeys,
  }) : id = id ?? const Uuid().v4();

  /// Unique ID for this crash report (UUID v4).
  final String id;
  final String message;
  final ErrorType type;
  final ErrorLevel level;

  /// Fatal = app would crash. Non-fatal = caught and logged.
  final bool isFatal;

  final DeviceInfo deviceInfo;
  final String sessionId;
  final DateTime appLaunchTime;
  final List<Breadcrumb> breadcrumbs;
  final StackTrace? stackTrace;

  /// SHA-256 fingerprint for issue grouping (same error = same fingerprint).
  final String? fingerprint;

  // API error fields
  final String? endpoint;
  final int? statusCode;

  // Optional user context
  final UserInfo? userInfo;

  // Developer-set custom key-value pairs
  final Map<String, dynamic>? customKeys;

  /// Milliseconds the app was alive before this crash.
  Duration get sessionAge =>
      deviceInfo.timestamp.difference(appLaunchTime);

  Map<String, dynamic> toMap() => {
        'id': id,
        'message': message,
        'type': type.label,
        'level': level.label,
        'isFatal': isFatal,
        'sessionId': sessionId,
        'sessionAgeSec': sessionAge.inSeconds,
        'appLaunchTime': appLaunchTime.toIso8601String(),
        'fingerprint': fingerprint,
        'stackTrace': stackTrace?.toString(),
        'breadcrumbs': breadcrumbs.map((b) => b.toMap()).toList(),
        'device': deviceInfo.toMap(),
        if (endpoint != null) 'endpoint': endpoint,
        if (statusCode != null) 'statusCode': statusCode,
        if (userInfo != null) 'user': userInfo!.toMap(),
        if (customKeys != null) 'customKeys': customKeys,
        'createdAt': deviceInfo.timestamp.toIso8601String(),
      };
}
