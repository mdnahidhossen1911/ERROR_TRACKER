import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

import '../models/device_info.dart';

/// Isolates all device and environment data collection.
///
/// All operations are async to avoid blocking the UI thread.
/// Designed for future caching / periodic refresh without
/// touching the tracker or logger layers.
class DeviceInfoService {
  DeviceInfoService({
    Battery? battery,
    Connectivity? connectivity,
    DeviceInfoPlugin? deviceInfoPlugin,
  })  : _battery = battery ?? Battery(),
        _connectivity = connectivity ?? Connectivity(),
        _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  final Battery _battery;
  final Connectivity _connectivity;
  final DeviceInfoPlugin _deviceInfoPlugin;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Collects all device info concurrently and returns an immutable snapshot.
  Future<DeviceInfo> collect({
    required String appName,
    required String appVersion,
    required String buildNumber,
  }) async {
    // Run independent lookups in parallel for minimum latency.
    final results = await Future.wait([
      _getPlatformInfo(),         // index 0
      _getBatteryLevel(),         // index 1
      _getNetworkInfo(),          // index 2
      _getMemoryInfo(),           // index 3
      _getStorageInfo(),          // index 4
    ]);

    final platformData = results[0] as _PlatformData;
    final battery = results[1] as int;
    final networkData = results[2] as _NetworkData;
    final memoryData = results[3] as _MemoryData;
    final storageData = results[4] as _StorageData;

    final performance = _computePerformanceLevel(
      ramMB: memoryData.totalRamMB,
      cpuCores: platformData.cpuCores,
    );

    return DeviceInfo(
      appName: appName,
      appVersion: appVersion,
      buildNumber: buildNumber,
      deviceModel: platformData.model,
      deviceBrand: platformData.brand,
      osVersion: platformData.osVersion,
      sdkVersion: platformData.sdkVersion,
      batteryPercentage: battery,
      networkType: networkData.type,
      networkSpeedMbps: networkData.speedMbps,
      totalRamMB: memoryData.totalRamMB,
      freeRamMB: memoryData.freeRamMB,
      totalStorageGB: storageData.totalGB,
      freeStorageGB: storageData.freeGB,
      cpuCores: platformData.cpuCores,
      appMemoryUsageMB: memoryData.appUsageMB,
      devicePerformanceLevel: performance,
      isPhysicalDevice: platformData.isPhysicalDevice,
      timestamp: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<_PlatformData> _getPlatformInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfoPlugin.androidInfo;
        return _PlatformData(
          model: info.model,
          brand: info.brand,
          osVersion: 'Android ${info.version.release}',
          sdkVersion: info.version.sdkInt.toString(),
          cpuCores: Platform.numberOfProcessors,
          isPhysicalDevice: info.isPhysicalDevice,
        );
      } else if (Platform.isIOS) {
        final info = await _deviceInfoPlugin.iosInfo;
        return _PlatformData(
          model: info.model,
          brand: 'Apple',
          osVersion: '${info.systemName} ${info.systemVersion}',
          sdkVersion: info.systemVersion,
          cpuCores: Platform.numberOfProcessors,
          isPhysicalDevice: info.isPhysicalDevice,
        );
      } else if (Platform.isLinux) {
        final info = await _deviceInfoPlugin.linuxInfo;
        return _PlatformData(
          model: info.prettyName,
          brand: 'Linux',
          osVersion: info.version ?? info.versionId ?? 'Unknown',
          sdkVersion: info.buildId ?? 'Unknown',
          cpuCores: Platform.numberOfProcessors,
          isPhysicalDevice: true,
        );
      } else if (Platform.isMacOS) {
        final info = await _deviceInfoPlugin.macOsInfo;
        return _PlatformData(
          model: info.model,
          brand: 'Apple',
          osVersion: 'macOS ${info.osRelease}',
          sdkVersion: info.kernelVersion,
          cpuCores: Platform.numberOfProcessors,
          isPhysicalDevice: true,
        );
      } else if (Platform.isWindows) {
        final info = await _deviceInfoPlugin.windowsInfo;
        return _PlatformData(
          model: info.computerName,
          brand: 'Windows',
          osVersion:
              'Windows ${info.majorVersion}.${info.minorVersion}',
          sdkVersion: info.buildNumber.toString(),
          cpuCores: Platform.numberOfProcessors,
          isPhysicalDevice: true,
        );
      }
    } catch (_) {
      // Fall through to default.
    }
    return _PlatformData(
      model: 'Unknown',
      brand: 'Unknown',
      osVersion: Platform.operatingSystem,
      sdkVersion: Platform.operatingSystemVersion,
      cpuCores: Platform.numberOfProcessors,
      isPhysicalDevice: true,
    );
  }

  Future<int> _getBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } on PlatformException {
      return -1;
    } catch (_) {
      return -1;
    }
  }

  Future<_NetworkData> _getNetworkInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      // connectivity_plus v6 returns List<ConnectivityResult>
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      String type;
      switch (result) {
        case ConnectivityResult.wifi:
          type = 'WiFi';
          break;
        case ConnectivityResult.mobile:
          type = 'Mobile';
          break;
        case ConnectivityResult.ethernet:
          type = 'Ethernet';
          break;
        case ConnectivityResult.none:
          type = 'None';
          break;
        default:
          type = 'Unknown';
      }

      // Speed estimation is intentionally lightweight — a real measurement
      // would require a network call which is inappropriate in an error
      // capture path. We surface the type only; callers can extend this.
      return _NetworkData(type: type, speedMbps: 0.0);
    } catch (_) {
      return _NetworkData(type: 'Unknown', speedMbps: 0.0);
    }
  }

  Future<_MemoryData> _getMemoryInfo() async {
    int totalRamMB = 0;
    int freeRamMB = 0;
    double appUsageMB = 0.0;

    try {
      if (Platform.isLinux || Platform.isAndroid) {
        final meminfo = File('/proc/meminfo');
        if (await meminfo.exists()) {
          final lines = await meminfo.readAsLines();
          for (final line in lines) {
            if (line.startsWith('MemTotal:')) {
              totalRamMB = _parseKbLine(line);
            } else if (line.startsWith('MemAvailable:') ||
                line.startsWith('MemFree:')) {
              if (freeRamMB == 0) freeRamMB = _parseKbLine(line);
            }
          }
        }
      }

      // App-level memory via dart:io ProcessInfo (available on all platforms).
      final rss = ProcessInfo.currentRss;
      appUsageMB = rss / (1024 * 1024);
    } catch (_) {
      // Memory info unavailable on this platform; values remain 0.
    }

    return _MemoryData(
      totalRamMB: totalRamMB,
      freeRamMB: freeRamMB,
      appUsageMB: appUsageMB,
    );
  }

  Future<_StorageData> _getStorageInfo() async {
    try {
      if (Platform.isAndroid || Platform.isLinux) {
        final result = await Process.run('df', ['-BG', '/data']);
        if (result.exitCode == 0) {
          final lines = (result.stdout as String).trim().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].split(RegExp(r'\s+'));
            if (parts.length >= 4) {
              final total = double.tryParse(
                      parts[1].replaceAll('G', '')) ??
                  0.0;
              final used = double.tryParse(
                      parts[2].replaceAll('G', '')) ??
                  0.0;
              return _StorageData(totalGB: total, freeGB: total - used);
            }
          }
        }
      }
    } catch (_) {
      // Storage info unavailable.
    }
    return _StorageData(totalGB: 0.0, freeGB: 0.0);
  }

  int _parseKbLine(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final kb = int.tryParse(parts[1]) ?? 0;
      return kb ~/ 1024;
    }
    return 0;
  }

  /// Derives a performance tier from RAM and CPU core count.
  ///
  /// Thresholds:
  /// - HIGH   : RAM >= 6 GB AND cores >= 6
  /// - MEDIUM : RAM >= 3 GB AND cores >= 4
  /// - LOW    : everything else
  String _computePerformanceLevel({
    required int ramMB,
    required int cpuCores,
  }) {
    if (ramMB >= 6144 && cpuCores >= 6) return 'HIGH';
    if (ramMB >= 3072 && cpuCores >= 4) return 'MEDIUM';
    return 'LOW';
  }
}

// ---------------------------------------------------------------------------
// Private value types (not exported)
// ---------------------------------------------------------------------------

class _PlatformData {
  const _PlatformData({
    required this.model,
    required this.brand,
    required this.osVersion,
    required this.sdkVersion,
    required this.cpuCores,
    required this.isPhysicalDevice,
  });
  final String model;
  final String brand;
  final String osVersion;
  final String sdkVersion;
  final int cpuCores;
  final bool isPhysicalDevice;
}

class _NetworkData {
  const _NetworkData({required this.type, required this.speedMbps});
  final String type;
  final double speedMbps;
}

class _MemoryData {
  const _MemoryData({
    required this.totalRamMB,
    required this.freeRamMB,
    required this.appUsageMB,
  });
  final int totalRamMB;
  final int freeRamMB;
  final double appUsageMB;
}

class _StorageData {
  const _StorageData({required this.totalGB, required this.freeGB});
  final double totalGB;
  final double freeGB;
}
