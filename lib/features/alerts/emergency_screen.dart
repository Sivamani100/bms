import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/ble_manager.dart';
import 'package:bms/core/services/auth_provider.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _emergencyTriggered = false;
  final List<String> _emergencyContacts = ['+91 99000 11000 (Spouse)', '+91 98888 22222 (Father)'];
  final _newContactController = TextEditingController();

  void _triggerEmergencyBroadcast() {
    setState(() {
      _emergencyTriggered = !_emergencyTriggered;
    });

    final ble = Provider.of<BleManager>(context, listen: false);
    final telemetry = ble.telemetry;
    final lat = telemetry?.latitude ?? 12.971598;
    final lng = telemetry?.longitude ?? 77.594566;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_emergencyTriggered
            ? 'Emergency mode active! Broadcasting location: $lat, $lng'
            : 'Emergency mode deactivated.'),
        backgroundColor: _emergencyTriggered ? VoltVaultTheme.alertRed : VoltVaultTheme.alertGreen,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _addContact() {
    final text = _newContactController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _emergencyContacts.add(text);
      _newContactController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleManager>(context);
    final telemetry = ble.telemetry;
    final lat = telemetry?.latitude ?? 12.971598;
    final lng = telemetry?.longitude ?? 77.594566;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltVaultTheme.obsidianGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Big Red Emergency Trigger Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: VoltVaultTheme.glassCardDecoration(
                    borderColor: _emergencyTriggered ? VoltVaultTheme.alertRed : Colors.white12,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _emergencyTriggered
                              ? VoltVaultTheme.alertRed.withOpacity(0.2)
                              : VoltVaultTheme.alertRed.withOpacity(0.08),
                          shape: BoxShape.circle,
                          boxShadow: _emergencyTriggered
                              ? [
                                  BoxShadow(
                                    color: VoltVaultTheme.alertRed.withOpacity(0.4),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                        child: IconButton(
                          iconSize: 64,
                          icon: Icon(
                            _emergencyTriggered ? Icons.gpp_bad_rounded : Icons.lock_rounded,
                            color: VoltVaultTheme.alertRed,
                          ),
                          onPressed: _triggerEmergencyBroadcast,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _emergencyTriggered ? 'EMERGENCY BROADCAST ACTIVE' : 'EMERGENCY SHIELD IDLE',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: _emergencyTriggered ? VoltVaultTheme.alertRed : VoltVaultTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emergencyTriggered
                            ? 'Broadcasting coordinates to contacts and authorities every 30 seconds.'
                            : 'Tap lock icon to lock the vehicle record and start instant emergency broadcast.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: VoltVaultTheme.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Last Known Coordinates Card
                _buildSectionHeader('LAST KNOWN VEHICLE POSITION'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: VoltVaultTheme.glassCardDecoration(),
                  child: Column(
                    children: [
                      _buildPositionRow('Latitude', lat.toStringAsFixed(6)),
                      const Divider(color: Colors.white10, height: 16),
                      _buildPositionRow('Longitude', lng.toStringAsFixed(6)),
                      const Divider(color: Colors.white10, height: 16),
                      _buildPositionRow('Status', ble.isConnected ? 'LIVE FEED' : 'CACHED FEED'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Emergency Contacts Manager
                _buildSectionHeader('EMERGENCY BROADCAST CONTACTS'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: VoltVaultTheme.glassCardDecoration(),
                  child: Column(
                    children: [
                      ..._emergencyContacts.map((c) => _buildContactRow(c)),
                      const Divider(color: Colors.white10, height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _newContactController,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(fontSize: 14),
                              decoration: const InputDecoration(
                                hintText: 'Enter name & phone...',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addContact,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Icon(Icons.add, size: 20),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: VoltVaultTheme.primaryNeoMint,
      ),
    );
  }

  Widget _buildPositionRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: VoltVaultTheme.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: VoltVaultTheme.textPrimary)),
      ],
    );
  }

  Widget _buildContactRow(String contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(contact, style: const TextStyle(fontSize: 13, color: VoltVaultTheme.textPrimary)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: VoltVaultTheme.alertRed, size: 18),
            onPressed: () {
              setState(() {
                _emergencyContacts.remove(contact);
              });
            },
          ),
        ],
      ),
    );
  }
}
