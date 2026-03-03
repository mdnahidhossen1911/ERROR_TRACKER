import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/crash_report.dart';
import '../queue/offline_queue.dart';
import '../tracker/error_tracker_config.dart';

/// Sends crash reports to your Custom REST API endpoint.
///
/// ── Request format ──────────────────────────────────────────────────────────
///
///   POST {your_endpoint}
///   Content-Type: application/json
///   X-Api-Key: {your_api_key}            ← if configured
///   X-Error-Tracker-Version: 2.0.0
///
///   Body: CrashReport.toMap() as JSON
///
/// ── Expected server response ────────────────────────────────────────────────
///
///   2xx  → report accepted, removed from offline queue
///   4xx  → report rejected (bad data), removed to avoid infinite retry
///   5xx  → server error, kept in offline queue for next flush
///   timeout / network error → kept in offline queue
///
/// ── Offline behaviour ───────────────────────────────────────────────────────
///
///   If the device has no internet, the report is saved to SharedPreferences.
///   On next app launch (or manual [flushOfflineQueue] call), all pending
///   reports are replayed in order. Max queue size: 100 reports (FIFO eviction).
///
/// ── Architecture note ───────────────────────────────────────────────────────
///
///   [RemoteReporter] is a pure strategy class. Swapping backends requires
///   only replacing this file — no other layer is touched.
class RemoteReporter {
  RemoteReporter({
    required ErrorTrackerApiConfig apiConfig,
    Connectivity? connectivity,
    OfflineQueue? offlineQueue,
    HttpClient? httpClient,
  })  : _config = apiConfig,
        _connectivity = connectivity ?? Connectivity(),
        _queue = offlineQueue ?? OfflineQueue(),
        _http = httpClient ?? HttpClient();

  final ErrorTrackerApiConfig _config;
  final Connectivity _connectivity;
  final OfflineQueue _queue;
  final HttpClient _http;

  static const String _trackerVersion = '2.0.0';

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Send a report. Queues locally if offline.
  Future<void> send(CrashReport report) async {
    final online = await _isOnline();
    if (!online) {
      await _queue.enqueue(report.id, report.toMap());
      return;
    }

    final sent = await _sendWithRetry(report.id, report.toMap());
    if (!sent) {
      // All retries exhausted — persist for next flush.
      await _queue.enqueue(report.id, report.toMap());
      return;
    }

    // Successful — try to drain any previously queued reports.
    await _flushQueue();
  }

  /// Flush the offline queue. Call on app resume or connectivity-restored events.
  Future<void> flushOfflineQueue() async {
    if (!await _isOnline()) return;
    await _flushQueue();
  }

  /// How many reports are waiting to be sent.
  Future<int> get pendingCount => _queue.pendingCount;

  // ---------------------------------------------------------------------------
  // Private — HTTP
  // ---------------------------------------------------------------------------

  /// Returns true if the report was accepted by the server.
  Future<bool> _sendWithRetry(
    String reportId,
    Map<String, dynamic> payload,
  ) async {
    for (int attempt = 1; attempt <= _config.maxRetries; attempt++) {
      try {
        final statusCode = await _post(payload);

        if (statusCode >= 200 && statusCode < 300) return true;

        // 4xx = bad request — no point retrying, discard silently.
        if (statusCode >= 400 && statusCode < 500) return true;

        // 5xx — wait before retry (exponential back-off: 1s, 2s, 4s).
        if (attempt < _config.maxRetries) {
          await Future.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      } on SocketException {
        // Network gone mid-flight — queue and stop.
        break;
      } on HandshakeException {
        // TLS error — queue and stop.
        break;
      } catch (_) {
        if (attempt < _config.maxRetries) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }
    }
    return false;
  }

  Future<int> _post(Map<String, dynamic> payload) async {
    _http.connectionTimeout =
        Duration(seconds: _config.timeoutSeconds);

    final uri = Uri.parse(_config.endpoint);
    final request = await _http.postUrl(uri);

    // Set headers
    _config.resolvedHeaders.forEach(request.headers.set);
    request.headers.set('X-Error-Tracker-Version', _trackerVersion);

    // Write body
    final body = jsonEncode(payload);
    request.headers.set('Content-Length', body.length.toString());
    request.write(body);

    final response = await request.close();
    // Drain body to release the connection.
    await response.drain<void>();
    return response.statusCode;
  }

  // ---------------------------------------------------------------------------
  // Private — Queue flush
  // ---------------------------------------------------------------------------

  Future<void> _flushQueue() async {
    final pending = await _queue.pendingReports();
    for (final entry in pending) {
      // Stop flushing if we go offline mid-flush.
      if (!await _isOnline()) break;

      final sent = await _sendWithRetry(entry.id, entry.payload);
      if (sent) {
        await _queue.remove(entry.id);
      } else {
        // Keep remaining reports in queue; try again next time.
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private — Connectivity
  // ---------------------------------------------------------------------------

  Future<bool> _isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          !results.contains(ConnectivityResult.none);
    } catch (_) {
      return true; // Assume online if check fails — let the HTTP call decide.
    }
  }
}
