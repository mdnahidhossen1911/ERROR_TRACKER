import 'package:uuid/uuid.dart';

/// Tracks the current app session.
///
/// A new session starts every time [SessionManager] is instantiated
/// (i.e. every cold app launch). The session ID is attached to every
/// crash report for grouping all crashes from a single user session.
class SessionManager {
  SessionManager()
      : sessionId = const Uuid().v4(),
        launchTime = DateTime.now();

  /// Unique ID for the current app launch.
  final String sessionId;

  /// When the app was launched (used to compute session age).
  final DateTime launchTime;

  /// How long the app has been running.
  Duration get sessionAge => DateTime.now().difference(launchTime);

  @override
  String toString() =>
      'Session($sessionId, age: ${sessionAge.inSeconds}s)';
}
