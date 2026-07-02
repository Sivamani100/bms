import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/ble_manager.dart';

class PairingScanScreen extends StatefulWidget {
  const PairingScanScreen({super.key});

  @override
  State<PairingScanScreen> createState() => _PairingScanScreenState();
}

class _PairingScanScreenState extends State<PairingScanScreen> {
  bool _isConnecting = false;
  String? _connectingDeviceName;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request BLE scan, BLE connect, and Location permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.location]?.isGranted == true) {
      Provider.of<BleManager>(context, listen: false).startScan();
    } else {
      // Permission denied - fallback to mock mode allowed anyway for simulator testing
      Provider.of<BleManager>(context, listen: false).startScan();
    }
  }

  void _connect(BleScanResultWrapper device) async {
    setState(() {
      _isConnecting = true;
      _connectingDeviceName = device.name;
    });

    final ble = Provider.of<BleManager>(context, listen: false);
    final success = await ble.connect(device.id);

    if (mounted) {
      setState(() {
        _isConnecting = false;
      });
      if (success) {
        // Connected! Navigate to confirmation screen
        context.push('/pair-confirm?deviceId=${device.id}&name=${Uri.encodeComponent(device.name)}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${device.name}. Please try again.'),
            backgroundColor: VoltVaultTheme.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Your Vehicle'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            ble.stopScan();
            context.pop();
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltVaultTheme.obsidianGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isConnecting) ...[
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: VoltVaultTheme.primaryNeoMint),
                        const SizedBox(height: 32),
                        Text(
                          'CONNECTING TO',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: VoltVaultTheme.primaryNeoMint.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _connectingDeviceName ?? 'BMS Device',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: VoltVaultTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Performing GATT handshake & service discovery...',
                          style: TextStyle(fontSize: 13, color: VoltVaultTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Checklist/Status
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: VoltVaultTheme.glassCardDecoration(),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: VoltVaultTheme.primaryNeoMint),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ble.isScanning
                                ? 'Scanning for nearby EV Bluetooth modules...'
                                : 'Scan completed. Select your vehicle to pair.',
                            style: const TextStyle(fontSize: 13, color: VoltVaultTheme.textPrimary),
                          ),
                        ),
                        if (ble.isScanning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: VoltVaultTheme.primaryNeoMint),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Scan results list
                  Expanded(
                    child: ble.scanResults.isEmpty
                        ? const Center(
                            child: Text(
                              'No compatible BMS devices found in range.',
                              style: TextStyle(color: VoltVaultTheme.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            itemCount: ble.scanResults.length,
                            separatorBuilder: (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = ble.scanResults[index];
                              return _buildDeviceTile(item);
                            },
                          ),
                  ),
                  const SizedBox(height: 24),
                  
                  OutlinedButton(
                    onPressed: ble.isScanning ? null : () => ble.startScan(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: VoltVaultTheme.primaryNeoMint),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'RESCAN FOR VEHICLES',
                      style: TextStyle(color: VoltVaultTheme.primaryNeoMint, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTile(BleScanResultWrapper item) {
    // Determine RSSI strength icon
    IconData rssiIcon = Icons.signal_cellular_alt_1_bar_rounded;
    if (item.rssi > -60) {
      rssiIcon = Icons.signal_cellular_alt_rounded;
    } else if (item.rssi > -80) {
      rssiIcon = Icons.signal_cellular_alt_2_bar_rounded;
    }

    return GestureDetector(
      onTap: () => _connect(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: VoltVaultTheme.glassCardDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VoltVaultTheme.primaryNeoMint.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.two_wheeler_rounded, color: VoltVaultTheme.primaryNeoMint),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: VoltVaultTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Device ID: ${item.id}',
                    style: const TextStyle(fontSize: 12, color: VoltVaultTheme.textSecondary),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Icon(rssiIcon, color: VoltVaultTheme.primaryNeoMint, size: 20),
                const SizedBox(width: 4),
                Text(
                  '${item.rssi} dBm',
                  style: const TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
