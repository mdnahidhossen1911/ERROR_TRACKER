/// Immutable snapshot of device and environment information
/// captured at the moment an error occurs.
class DeviceInfo {
  const DeviceInfo({
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
    required this.deviceModel,
    required this.deviceBrand,
    required this.osVersion,
    required this.sdkVersion,
    required this.batteryPercentage,
    required this.networkType,
    required this.networkSpeedMbps,
    required this.totalRamMB,
    required this.freeRamMB,
    required this.totalStorageGB,
    required this.freeStorageGB,
    required this.cpuCores,
    required this.appMemoryUsageMB,
    required this.devicePerformanceLevel,
    required this.isPhysicalDevice,
    required this.timestamp,
  });

  final String appName;
  final String appVersion;
  final String buildNumber;
  final String deviceModel;
  final String deviceBrand;
  final String osVersion;
  final String sdkVersion;
  final int batteryPercentage;
  final String networkType;
  final double networkSpeedMbps;
  final int totalRamMB;
  final int freeRamMB;
  final double totalStorageGB;
  final double freeStorageGB;
  final int cpuCores;
  final double appMemoryUsageMB;
  final String devicePerformanceLevel;
  final bool isPhysicalDevice;
  final DateTime timestamp;

  /// Formats RAM in human-readable GB string.
  String get totalRamDisplay {
    if (totalRamMB >= 1024) {
      return '${(totalRamMB / 1024).toStringAsFixed(0)}GB';
    }
    return '${totalRamMB}MB';
  }

  /// Formats free RAM in human-readable display string.
  String get freeRamDisplay {
    if (freeRamMB >= 1024) {
      return '${(freeRamMB / 1024).toStringAsFixed(1)}GB';
    }
    return '${freeRamMB}MB';
  }

  Map<String, dynamic> toMap() => {
        'appName': appName,
        'appVersion': appVersion,
        'buildNumber': buildNumber,
        'deviceModel': deviceModel,
        'deviceBrand': deviceBrand,
        'osVersion': osVersion,
        'sdkVersion': sdkVersion,
        'batteryPercentage': batteryPercentage,
        'networkType': networkType,
        'networkSpeedMbps': networkSpeedMbps,
        'totalRamMB': totalRamMB,
        'freeRamMB': freeRamMB,
        'totalStorageGB': totalStorageGB,
        'freeStorageGB': freeStorageGB,
        'cpuCores': cpuCores,
        'appMemoryUsageMB': appMemoryUsageMB,
        'devicePerformanceLevel': devicePerformanceLevel,
        'isPhysicalDevice': isPhysicalDevice,
        'timestamp': timestamp.toIso8601String(),
      };
}
