import 'dart:developer' as developer;

import 'package:error_tracker/error_tracker.dart';
import 'package:error_tracker/src/logger/console_logger.dart';
import 'package:error_tracker/src/services/device_info_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DeviceInfo _fakeDevice({
  int battery = 75,
  String network = 'WiFi',
  double speed = 85.0,
  int totalRam = 8192,
  int freeRam = 3200,
  double totalStorage = 128.0,
  double freeStorage = 45.0,
  int cores = 8,
  double appMem = 120.0,
}) =>
    DeviceInfo(
      appName: 'TestApp',
      appVersion: '1.0.0',
      buildNumber: '12',
      deviceModel: 'Pixel 8',
      deviceBrand: 'Google',
      osVersion: 'Android 14',
      sdkVersion: '34',
      batteryPercentage: battery,
      networkType: network,
      networkSpeedMbps: speed,
      totalRamMB: totalRam,
      freeRamMB: freeRam,
      totalStorageGB: totalStorage,
      freeStorageGB: freeStorage,
      cpuCores: cores,
      appMemoryUsageMB: appMem,
      devicePerformanceLevel: 'HIGH',
      isPhysicalDevice: true,
      timestamp: DateTime(2026, 3, 3, 10, 32, 22),
    );

ErrorRecord _fakeRecord({
  String message = 'Null check operator used on a null value',
  ErrorType type = ErrorType.flutter,
  ErrorLevel level = ErrorLevel.error,
  StackTrace? stack,
  String? endpoint,
  int? statusCode,
}) =>
    ErrorRecord(
      message: message,
      type: type,
      level: level,
      deviceInfo: _fakeDevice(),
      stackTrace: stack,
      endpoint: endpoint,
      statusCode: statusCode,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DeviceInfo model', () {
    test('totalRamDisplay returns GB when >= 1024 MB', () {
      final info = _fakeDevice(totalRam: 8192);
      expect(info.totalRamDisplay, '8GB');
    });

    test('totalRamDisplay returns MB when < 1024 MB', () {
      final info = _fakeDevice(totalRam: 512);
      expect(info.totalRamDisplay, '512MB');
    });

    test('freeRamDisplay returns decimal GB', () {
      final info = _fakeDevice(freeRam: 3276); // ~3.2 GB
      expect(info.freeRamDisplay, contains('GB'));
    });

    test('toMap contains all required keys', () {
      final map = _fakeDevice().toMap();
      for (final key in [
        'appName', 'appVersion', 'buildNumber', 'deviceModel',
        'deviceBrand', 'osVersion', 'batteryPercentage', 'networkType',
        'totalRamMB', 'freeRamMB', 'cpuCores', 'isPhysicalDevice',
        'timestamp',
      ]) {
        expect(map.containsKey(key), isTrue, reason: 'Missing key: $key');
      }
    });
  });

  group('ErrorRecord model', () {
    test('toMap includes message, type and level', () {
      final record = _fakeRecord();
      final map = record.toMap();
      expect(map['message'], 'Null check operator used on a null value');
      expect(map['type'], 'FlutterError');
      expect(map['level'], 'ERROR');
    });

    test('API record toMap includes endpoint and statusCode', () {
      final record = _fakeRecord(
        type: ErrorType.api,
        level: ErrorLevel.critical,
        endpoint: '/api/v1/users',
        statusCode: 503,
      );
      final map = record.toMap();
      expect(map['endpoint'], '/api/v1/users');
      expect(map['statusCode'], 503);
    });
  });

  group('ErrorLevel', () {
    test('label returns uppercase name', () {
      expect(ErrorLevel.info.label, 'INFO');
      expect(ErrorLevel.warning.label, 'WARNING');
      expect(ErrorLevel.error.label, 'ERROR');
      expect(ErrorLevel.critical.label, 'CRITICAL');
    });
  });

  group('ErrorType', () {
    test('labels are correctly mapped', () {
      expect(ErrorType.flutter.label, 'FlutterError');
      expect(ErrorType.async.label, 'AsyncError');
      expect(ErrorType.platform.label, 'PlatformError');
      expect(ErrorType.api.label, 'ApiError');
      expect(ErrorType.manual.label, 'ManualLog');
    });
  });

  group('ConsoleLogger formatting', () {
    test('log() does not throw for a basic record', () {
      final logger = const ConsoleLogger();
      expect(() => logger.log(_fakeRecord()), returnsNormally);
    });

    test('log() does not throw for API record with endpoint', () {
      final logger = const ConsoleLogger();
      expect(
        () => logger.log(_fakeRecord(
          type: ErrorType.api,
          level: ErrorLevel.critical,
          endpoint: '/api/v1/orders',
          statusCode: 500,
        )),
        returnsNormally,
      );
    });

    test('log() does not throw when stackTrace is provided', () {
      final logger = const ConsoleLogger();
      expect(
        () => logger.log(_fakeRecord(stack: StackTrace.current)),
        returnsNormally,
      );
    });

    test('log() handles battery = -1 gracefully', () {
      final logger = const ConsoleLogger();
      final record = ErrorRecord(
        message: 'test',
        type: ErrorType.manual,
        level: ErrorLevel.info,
        deviceInfo: _fakeDevice(battery: -1),
      );
      expect(() => logger.log(record), returnsNormally);
    });
  });

  group('ErrorTrackerConfig', () {
    test('default values are sensible', () {
      const config = ErrorTrackerConfig(
        appName: 'App',
        appVersion: '1.0.0',
        buildNumber: '1',
      );
      expect(config.minimumLevel, ErrorLevel.info);
      expect(config.enableFlutterErrors, isTrue);
      expect(config.enableAsyncErrors, isTrue);
      expect(config.enablePlatformErrors, isTrue);
      expect(config.onError, isNull);
    });

    test('minimumLevel can be overridden', () {
      const config = ErrorTrackerConfig(
        appName: 'App',
        appVersion: '1.0.0',
        buildNumber: '1',
        minimumLevel: ErrorLevel.critical,
      );
      expect(config.minimumLevel, ErrorLevel.critical);
    });
  });
}
