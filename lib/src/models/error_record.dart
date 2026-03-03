import 'device_info.dart';
import 'error_level.dart';
import 'error_type.dart';

/// Immutable record representing a single captured error event.
class ErrorRecord {
  const ErrorRecord({
    required this.message,
    required this.type,
    required this.level,
    required this.deviceInfo,
    this.stackTrace,
    this.endpoint,
    this.statusCode,
    this.extra,
  });

  final String message;
  final ErrorType type;
  final ErrorLevel level;
  final DeviceInfo deviceInfo;
  final StackTrace? stackTrace;

  /// Only populated for [ErrorType.api] errors.
  final String? endpoint;

  /// Only populated for [ErrorType.api] errors.
  final int? statusCode;

  /// Optional bag for any additional context.
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toMap() => {
        'message': message,
        'type': type.label,
        'level': level.label,
        'stackTrace': stackTrace?.toString(),
        'endpoint': endpoint,
        'statusCode': statusCode,
        'extra': extra,
        'device': deviceInfo.toMap(),
      };
}
