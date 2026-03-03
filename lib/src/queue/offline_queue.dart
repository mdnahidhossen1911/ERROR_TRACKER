import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists crash reports locally when the device is offline.
/// Replays them automatically when connectivity is restored.
///
/// Reports are stored as JSON strings under a prefixed key in
/// SharedPreferences. Each report gets its own key so partial
/// failures during flush don't corrupt the queue.
class OfflineQueue {
  static const String _prefix = 'et_queue_';
  static const int _maxQueueSize = 100;

  /// Persists a serialized crash report.
  /// If the queue is full, the oldest entry is evicted.
  Future<void> enqueue(String reportId, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _queueKeys(prefs);

    if (keys.length >= _maxQueueSize) {
      // Evict oldest
      await prefs.remove(keys.first);
    }

    await prefs.setString(
      '$_prefix$reportId',
      jsonEncode(payload),
    );
  }

  /// Returns all pending reports, ordered by insertion (oldest first).
  Future<List<({String id, Map<String, dynamic> payload})>>
      pendingReports() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _queueKeys(prefs);

    final result = <({String id, Map<String, dynamic> payload})>[];
    for (final key in keys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final id = key.substring(_prefix.length);
        final payload = jsonDecode(raw) as Map<String, dynamic>;
        result.add((id: id, payload: payload));
      } catch (_) {
        // Corrupted entry — remove it.
        await prefs.remove(key);
      }
    }
    return result;
  }

  /// Removes a successfully sent report from the queue.
  Future<void> remove(String reportId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$reportId');
  }

  /// Clears all queued reports.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _queueKeys(prefs);
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  /// Returns the number of pending reports.
  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return _queueKeys(prefs).length;
  }

  List<String> _queueKeys(SharedPreferences prefs) => prefs
      .getKeys()
      .where((k) => k.startsWith(_prefix))
      .toList()
    ..sort();
}
