import 'dart:collection';
import '../models/breadcrumb.dart';

/// Records up to [maxBreadcrumbs] recent events before a crash.
/// Uses a fixed-size circular buffer — oldest entries are dropped.
/// Thread-safe via synchronous operations (no async needed).
class BreadcrumbManager {
  BreadcrumbManager({this.maxBreadcrumbs = 50});

  final int maxBreadcrumbs;
  final Queue<Breadcrumb> _buffer = Queue();

  /// Add a breadcrumb. Oldest is dropped if buffer is full.
  void add(Breadcrumb breadcrumb) {
    if (_buffer.length >= maxBreadcrumbs) {
      _buffer.removeFirst();
    }
    _buffer.addLast(breadcrumb);
  }

  /// Convenience: record a navigation event.
  void navigation(String route, {Map<String, dynamic>? params}) => add(
        Breadcrumb(
          message: 'Navigate → $route',
          type: BreadcrumbType.navigation,
          timestamp: DateTime.now(),
          data: params,
        ),
      );

  /// Convenience: record a user action (button tap, gesture, etc.)
  void userAction(String action, {Map<String, dynamic>? data}) => add(
        Breadcrumb(
          message: action,
          type: BreadcrumbType.userAction,
          timestamp: DateTime.now(),
          data: data,
        ),
      );

  /// Convenience: record a network request.
  void network(String method, String url, {int? statusCode}) => add(
        Breadcrumb(
          message: '$method $url',
          type: BreadcrumbType.network,
          timestamp: DateTime.now(),
          data: {
            'method': method,
            'url': url,
            if (statusCode != null) 'status': statusCode,
          },
        ),
      );

  /// Convenience: record a state change.
  void stateChange(String description, {Map<String, dynamic>? data}) => add(
        Breadcrumb(
          message: description,
          type: BreadcrumbType.state,
          timestamp: DateTime.now(),
          data: data,
        ),
      );

  /// Returns a snapshot of all breadcrumbs, oldest first.
  List<Breadcrumb> get snapshot => List.unmodifiable(_buffer.toList());

  /// Clear all breadcrumbs (e.g. after a report is sent).
  void clear() => _buffer.clear();
}
