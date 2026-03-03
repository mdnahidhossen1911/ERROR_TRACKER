import 'dart:developer' as developer;

import '../models/error_record.dart';

/// Formats an [ErrorRecord] into a structured console block and emits it
/// via [developer.log] so it surfaces correctly in both debug consoles
/// and Flutter DevTools.
///
/// This class is intentionally decoupled from the tracker so that:
/// 1. Alternative loggers (file, remote) can be plugged in without
///    touching capture logic.
/// 2. Unit tests can verify formatting in isolation.
class ConsoleLogger {
  const ConsoleLogger();

  static const _divider = '===============================================';
  static const _header = '================ ERROR TRACKER ================';

  /// Formats and prints [record] to the console.
  void log(ErrorRecord record) {
    final d = record.deviceInfo;
    final buffer = StringBuffer();

    buffer.writeln(_header);
    buffer.writeln(
        'App: ${d.appName} v${d.appVersion} (build ${d.buildNumber})');
    buffer.writeln(
        'Device: ${d.deviceBrand} ${d.deviceModel} (${d.osVersion})');
    buffer.writeln(_networkLine(d.networkType, d.networkSpeedMbps));
    buffer.writeln(_batteryLine(d.batteryPercentage));
    buffer.writeln(
        'RAM: ${d.totalRamDisplay} (Free: ${d.freeRamDisplay})');
    buffer.writeln(
        'Storage: ${_formatStorage(d.totalStorageGB)} '
        '(Free: ${_formatStorage(d.freeStorageGB)})');
    buffer.writeln('CPU Cores: ${d.cpuCores}');
    buffer.writeln('Performance: ${d.devicePerformanceLevel}');
    if (d.appMemoryUsageMB > 0) {
      buffer.writeln(
          'App Memory: ${d.appMemoryUsageMB.toStringAsFixed(1)} MB');
    }
    buffer.writeln('Physical Device: ${d.isPhysicalDevice}');
    buffer.writeln('---');
    buffer.writeln('Type: ${record.type.label}');
    buffer.writeln('Severity: ${record.level.label}');

    // API-specific fields
    if (record.endpoint != null) {
      buffer.writeln('Endpoint: ${record.endpoint}');
    }
    if (record.statusCode != null) {
      buffer.writeln('Status Code: ${record.statusCode}');
    }

    buffer.writeln('Message: ${record.message}');

    if (record.stackTrace != null) {
      buffer.writeln('StackTrace:');
      buffer.writeln(_formatStackTrace(record.stackTrace!));
    }

    buffer.writeln('Time: ${_formatTimestamp(d.timestamp)}');
    buffer.write(_divider);

    // developer.log keeps output intact in Flutter DevTools.
    developer.log(
      buffer.toString(),
      name: 'ErrorTracker',
      level: _levelValue(record),
      time: d.timestamp,
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  String _networkLine(String type, double speedMbps) {
    if (speedMbps > 0) {
      return 'Network: $type (${speedMbps.toStringAsFixed(0)} Mbps)';
    }
    return 'Network: $type';
  }

  String _batteryLine(int pct) {
    if (pct < 0) return 'Battery: N/A';
    return 'Battery: $pct%';
  }

  String _formatStorage(double gb) {
    if (gb <= 0) return 'N/A';
    return '${gb.toStringAsFixed(0)}GB';
  }

  String _formatStackTrace(StackTrace st) {
    // Limit to first 20 frames to keep output readable.
    final lines = st.toString().split('\n');
    final capped = lines.take(20).join('\n');
    final suffix = lines.length > 20
        ? '\n  ... ${lines.length - 20} more frames'
        : '';
    return '$capped$suffix';
  }

  String _formatTimestamp(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  /// Maps error level to dart:developer severity integer.
  int _levelValue(ErrorRecord record) {
    switch (record.level) {
      case _ when record.level.index == 0: // info
        return 800;
      case _ when record.level.index == 1: // warning
        return 900;
      case _ when record.level.index == 2: // error
        return 1000;
      default: // critical
        return 1200;
    }
  }
}
