/// A single user action or system event recorded before a crash.
/// Mirrors Firebase Crashlytics breadcrumb concept.
enum BreadcrumbType {
  navigation,
  userAction,
  network,
  state,
  log,
}

class Breadcrumb {
  const Breadcrumb({
    required this.message,
    required this.type,
    required this.timestamp,
    this.data,
  });

  final String message;
  final BreadcrumbType type;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  Map<String, dynamic> toMap() => {
        'message': message,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
        if (data != null) 'data': data,
      };
}
