/// Severity level of the captured error.
enum ErrorLevel {
  info,
  warning,
  error,
  critical;

  String get label => name.toUpperCase();
}
