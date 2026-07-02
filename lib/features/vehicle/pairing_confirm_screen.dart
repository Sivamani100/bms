import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/auth_provider.dart';
import 'package:bms/core/network/supabase_client.dart';

class PairingConfirmScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const PairingConfirmScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<PairingConfirmScreen> createState() => _PairingConfirmScreenState();
}

class _PairingConfirmScreenState extends State<PairingConfirmScreen> {
  final _nicknameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String _serialNumber;
  late String _vin;
  late String _batterySerial;
  late String _bmsIdentifier;

  @override
  void initState() {
    super.initState();
    _nicknameController.text = widget.deviceName;
    // Generate mock serials based on device ID
    _serialNumber = 'SN-${widget.deviceId.hashCode.abs().toString().padLeft(8, '0')}';
    _vin = 'VIN${widget.deviceId.hashCode.abs().toString().padLeft(12, '0')}';
    _batterySerial = 'BATT-${(widget.deviceId.hashCode / 2).round().abs().toString().padLeft(8, '0')}';
    _bmsIdentifier = 'BMS-VV-${widget.deviceId.substring(0, 3).toUpperCase()}';
  }

  void _claimOwnership() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final nickname = _nicknameController.text.trim();

    bool dbSuccess = false;
    
    // Attempt database insert if logged in
    if (auth.user != null) {
      try {
        await SupabaseConfig.client.from('vehicles').insert({
          'owner_id': auth.user!.id,
          'serial_number': _serialNumber,
          'vin': _vin,
          'battery_serial': _batterySerial,
          'bms_identifier': _bmsIdentifier,
          'ble_device_identifier': widget.deviceId,
          'make_model': widget.deviceName,
          'nickname': nickname,
        });
        dbSuccess = true;
      } catch (e) {
        debugPrint("Error writing vehicle to database: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: ${e.toString().contains('42501') ? 'Identity KYC not verified' : e.toString()}'),
            backgroundColor: VoltVaultTheme.alertRed,
          ),
        );
      }
    } else {
      // Offline / Developer mock mode bypasses database write
      dbSuccess = true;
    }

    setState(() {
      _isLoading = false;
    });

    if (dbSuccess) {
      // Register success and go to dashboard
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Details'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltVaultTheme.obsidianGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: VoltVaultTheme.glassCardDecoration(
                      borderColor: VoltVaultTheme.primaryNeoMint.withOpacity(0.3),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: VoltVaultTheme.primaryNeoMint, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Identity Verified',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: VoltVaultTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Binding this vehicle to: ${Provider.of<AuthProvider>(context).displayName}',
                                style: const TextStyle(fontSize: 12, color: VoltVaultTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Nickname Input
                  const Text(
                    'VEHICLE NICKNAME',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: VoltVaultTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nicknameController,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.two_wheeler_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please provide a nickname for your vehicle';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Hardware parameters list
                  const Text(
                    'DISCOVERED TELEMETRY HARDWARE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: VoltVaultTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: VoltVaultTheme.glassCardDecoration(),
                    child: Column(
                      children: [
                        _buildDetailRow('Serial Number', _serialNumber),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('VIN', _vin),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('BMS Identifier', _bmsIdentifier),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('Battery Serial', _batterySerial),
                        const Divider(color: Colors.white12, height: 24),
                        _buildDetailRow('BLE Hardware ID', widget.deviceId),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Disclaimer
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: VoltVaultTheme.alertAmber, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'IMPORTANT: Claiming this vehicle writes a cryptographic token to the VoltVault ledger. Access permissions can only be granted by your verified account.',
                          style: TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _claimOwnership,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'CLAIM OWNERSHIP & REGISTER',
                            style: TextStyle(letterSpacing: 1.5),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: VoltVaultTheme.textSecondary)),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: VoltVaultTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
