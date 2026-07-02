import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:bms/core/services/ble_manager.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(TelemetryTaskHandler());
}

class TelemetryTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground Service started at $timestamp by $starter');
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    debugPrint('Foreground Service monitoring loop: $timestamp');
    
    final ble = BleManager();
    if (ble.isConnected && ble.telemetry != null) {
      final data = {
        'batteryPercent': ble.telemetry!.batteryPercent,
        'chargingState': ble.telemetry!.chargingState,
        'latitude': ble.telemetry!.latitude,
        'longitude': ble.telemetry!.longitude,
      };
      FlutterForegroundTask.sendDataToMain(data);
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('Foreground Service destroyed at $timestamp (timeout: $isTimeout)');
  }
}

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  ReceivePort? _receivePort;

  void initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'voltvault_monitor',
        channelName: 'VoltVault Active Monitor',
        channelDescription: 'Keeps connection alive and checks for security anomalies.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000), // 15 seconds
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      _registerPort();
      return true;
    }

    final hasPermissions = await FlutterForegroundTask.canDrawOverlays;
    if (!hasPermissions) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'VoltVault Active Protection',
      notificationText: 'BLE telemetry monitoring is running',
      callback: startCallback,
    );

    if (result is ServiceRequestSuccess) {
      _registerPort();
      return true;
    }
    return false;
  }

  Future<bool> stopService() async {
    final result = await FlutterForegroundTask.stopService();
    _receivePort?.close();
    _receivePort = null;
    return result is ServiceRequestSuccess;
  }

  void _registerPort() {
    _receivePort = FlutterForegroundTask.receivePort;
    _receivePort?.listen((data) {
      if (data is Map) {
        debugPrint('Received background telemetry update: $data');
      }
    });
  }
}
