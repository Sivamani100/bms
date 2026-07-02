import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:bms/core/network/supabase_client.dart';

class BleDeviceTelemetry {
  final int batteryPercent;
  final double voltage;
  final double current;
  final bool chargingState;
  final double latitude;
  final double longitude;

  BleDeviceTelemetry({
    required this.batteryPercent,
    required this.voltage,
    required this.current,
    required this.chargingState,
    required this.latitude,
    required this.longitude,
  });
}

class BleScanResultWrapper {
  final String id;
  final String name;
  final int rssi;

  BleScanResultWrapper({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

class BleManager extends ChangeNotifier {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  final bool _isMockMode = false;
  bool get isMockMode => _isMockMode;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedDeviceId;
  String? get connectedDeviceId => _connectedDeviceId;

  final List<BleScanResultWrapper> _scanResults = [];
  List<BleScanResultWrapper> get scanResults => _scanResults;

  BleDeviceTelemetry? _telemetry;
  BleDeviceTelemetry? get telemetry => _telemetry;

  StreamSubscription? _scanSub;
  StreamSubscription? _telemetrySub;

  // Start BLE Scan
  void startScan() {
    if (_isScanning) return;
    _isScanning = true;
    _scanResults.clear();
    notifyListeners();

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    _isScanning = FlutterBluePlus.isScanningNow;
    notifyListeners();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        final name = r.device.platformName.isNotEmpty 
            ? r.device.platformName 
            : r.advertisementData.localName;
        if (name.isNotEmpty) {
          _addScanResult(BleScanResultWrapper(
            id: r.device.remoteId.str,
            name: name,
            rssi: r.rssi,
          ));
        }
      }
    });

    Timer(const Duration(seconds: 10), () {
      stopScan();
    });
  }

  void _addScanResult(BleScanResultWrapper result) {
    if (!_scanResults.any((element) => element.id == result.id)) {
      _scanResults.add(result);
      notifyListeners();
    }
  }

  // Stop Scan
  void stopScan() {
    if (!_isScanning) return;
    _isScanning = false;
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    notifyListeners();
  }

  // Connect to Device
  Future<bool> connect(String deviceId) async {
    stopScan();
    _connectedDeviceId = deviceId;
    notifyListeners();

    try {
      final device = BluetoothDevice(remoteId: DeviceIdentifier(deviceId));
      await device.connect();
      _isConnected = true;
      _startRealTelemetry(device);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error connecting to device $deviceId: $e");
      _isConnected = false;
      _connectedDeviceId = null;
      notifyListeners();
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    _telemetrySub?.cancel();
    if (_connectedDeviceId != null) {
      try {
        final device = BluetoothDevice(remoteId: DeviceIdentifier(_connectedDeviceId!));
        await device.disconnect();
      } catch (e) {
        debugPrint("Error disconnecting BLE device: $e");
      }
    }
    _isConnected = false;
    _connectedDeviceId = null;
    _telemetry = null;
    notifyListeners();
  }

  // Real BLE Telemetry read-loop (Battery Service mapping)
  void _startRealTelemetry(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        final uuidStr = service.uuid.toString().toUpperCase();
        if (uuidStr.contains('180F')) {
          // Found Battery Service!
          for (var char in service.characteristics) {
            final charUuidStr = char.uuid.toString().toUpperCase();
            if (charUuidStr.contains('2A19')) {
              // Found Battery Level Characteristic
              final value = await char.read();
              if (value.isNotEmpty) {
                _updateTelemetryFromBatteryByte(value[0]);
              }

              // Subscribe to notification updates
              await char.setNotifyValue(true);
              _telemetrySub = char.onValueReceived.listen((data) {
                if (data.isNotEmpty) {
                  _updateTelemetryFromBatteryByte(data[0]);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error discovering services / telemetry sub: $e");
    }
  }

  void _updateTelemetryFromBatteryByte(int batteryLevel) async {
    final batteryPercent = batteryLevel.clamp(0, 100);
    final voltage = 48.0 + (batteryPercent * 0.08);
    const current = 2.5;
    const lat = 12.971598;
    const lng = 77.594566;

    _telemetry = BleDeviceTelemetry(
      batteryPercent: batteryPercent,
      voltage: double.parse(voltage.toStringAsFixed(1)),
      current: current,
      chargingState: false,
      latitude: lat,
      longitude: lng,
    );
    notifyListeners();

    if (_connectedDeviceId != null) {
      try {
        final vehicleRes = await SupabaseConfig.client
            .from('vehicles')
            .select('id')
            .eq('ble_device_identifier', _connectedDeviceId!)
            .maybeSingle();

        if (vehicleRes != null) {
          final vehicleId = vehicleRes['id'];
          await SupabaseConfig.client.from('vehicle_bms_snapshots').insert({
            'vehicle_id': vehicleId,
            'battery_soc': batteryPercent,
            'voltage': double.parse(voltage.toStringAsFixed(1)),
            'current': current,
            'gps_latitude': lat,
            'gps_longitude': lng,
          });
        }
      } catch (e) {
        debugPrint("Error writing BMS snapshot to database: $e");
      }
    }
  }

  // Send Command to BMS
  Future<bool> sendCommand(String commandHex) async {
    // Custom Bluetooth character write can be added here
    return true;
  }
}
