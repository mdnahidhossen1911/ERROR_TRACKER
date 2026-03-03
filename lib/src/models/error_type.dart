/// Origin type of the captured error.
enum ErrorType {
  flutter,
  async,
  platform,
  api,
  manual;

  String get label {
    switch (this) {
      case ErrorType.flutter:
        return 'FlutterError';
      case ErrorType.async:
        return 'AsyncError';
      case ErrorType.platform:
        return 'PlatformError';
      case ErrorType.api:
        return 'ApiError';
      case ErrorType.manual:
        return 'ManualLog';
    }
  }
}
