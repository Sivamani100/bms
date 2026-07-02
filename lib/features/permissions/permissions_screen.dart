import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/auth_provider.dart';
import 'package:bms/core/network/supabase_client.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  List<Map<String, dynamic>> _authorizedDevices = [];
  List<Map<String, dynamic>> _temporaryGrants = [];
  bool _isLoading = false;

  // Temporary grant creation form states
  final _phoneController = TextEditingController();
  String _selectedDuration = '15m'; // 15m, 1h, 1d
  bool _readOnly = true;
  bool _diagnostics = false;
  bool _firmware = false;
  bool _batteryWrite = false;

  @override
  void initState() {
    super.initState();
    _fetchAccessRecords();
  }

  void _fetchAccessRecords() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      // Mock local data for dev sandbox if offline
      setState(() {
        _authorizedDevices = [
          {'id': '1', 'device_name': 'My Phone (Owner)', 'access_level': 'full', 'created_at': DateTime.now().toIso8601String()},
          {'id': '2', 'device_name': 'Spouse\'s Pixel 7', 'access_level': 'ride_only', 'created_at': DateTime.now().toIso8601String()},
        ];
        _temporaryGrants = [
          {
            'id': 'temp-1',
            'grantee_phone': '+91 98765 43210',
            'starts_at': DateTime.now().toIso8601String(),
            'expires_at': DateTime.now().add(const Duration(minutes: 45)).toIso8601String(),
            'status': 'active',
            'permissions': {'read_only': true, 'diagnostics': true, 'firmware': false, 'battery_write': false}
          }
        ];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Fetch authorized devices
      final devicesRes = await SupabaseConfig.client
          .from('authorized_devices')
          .select()
          .order('created_at', ascending: false);

      // 2. Fetch temporary grants
      final grantsRes = await SupabaseConfig.client
          .from('access_grants')
          .select('*, access_grant_permissions(*)')
          .eq('status', 'active')
          .order('created_at', ascending: false);

      setState(() {
        _authorizedDevices = List<Map<String, dynamic>>.from(devicesRes);
        _temporaryGrants = List<Map<String, dynamic>>.from(grantsRes);
      });
    } catch (e) {
      debugPrint("Error fetching access records: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createTemporaryGrant() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetPhone = _phoneController.text.trim();
    if (targetPhone.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    // Determine expiry time
    Duration duration = const Duration(minutes: 15);
    if (_selectedDuration == '1h') {
      duration = const Duration(hours: 1);
    } else if (_selectedDuration == '1d') {
      duration = const Duration(days: 1);
    }

    final now = DateTime.now().toUtc();
    final expiresAt = now.add(duration);

    if (auth.user == null) {
      // Simulator local add
      setState(() {
        _temporaryGrants.insert(0, {
          'id': 'temp-new',
          'grantee_phone': targetPhone,
          'starts_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
          'status': 'active',
          'permissions': {
            'read_only': _readOnly,
            'diagnostics': _diagnostics,
            'firmware': _firmware,
            'battery_write': _batteryWrite,
          }
        });
        _isLoading = false;
      });
      Navigator.pop(context);
      return;
    }

    try {
      // Get the vehicle ID
      final vehicle = await SupabaseConfig.client
          .from('vehicles')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (vehicle != null) {
        // Find owner ID of grantee (just use a mock or standard lookup - for demo we map it to owner themselves or a mock uuid)
        final granteeId = auth.user!.id; // Self-grant for demo simulation

        final grantInsert = await SupabaseConfig.client
            .from('access_grants')
            .insert({
              'vehicle_id': vehicle['id'],
              'granted_by': auth.user!.id,
              'grantee_id': granteeId,
              'starts_at': now.toIso8601String(),
              'expires_at': expiresAt.toIso8601String(),
              'status': 'active',
            })
            .select('id')
            .single();

        await SupabaseConfig.client.from('access_grant_permissions').insert({
          'grant_id': grantInsert['id'],
          'read_only': _readOnly,
          'diagnostics': _diagnostics,
          'firmware': _firmware,
          'battery_write': _batteryWrite,
        });

        _phoneController.clear();
        _fetchAccessRecords();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error creating grant: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create grant: $e'), backgroundColor: VoltVaultTheme.alertRed),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _revokeGrant(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      setState(() {
        _temporaryGrants.removeWhere((element) => element['id'] == id);
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseConfig.client
          .from('access_grants')
          .update({'status': 'revoked'})
          .eq('id', id);
      _fetchAccessRecords();
    } catch (e) {
      debugPrint("Error revoking access: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Access & Permissions'),
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
          child: _isLoading && _authorizedDevices.isEmpty
              ? const Center(child: CircularProgressIndicator(color: VoltVaultTheme.primaryNeoMint))
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Standing Access header
                    _buildSectionHeader('STANDING DEVICES / USERS'),
                    const SizedBox(height: 12),
                    ..._authorizedDevices.map((d) => _buildDeviceCard(d)),
                    const SizedBox(height: 28),

                    // Temporary Access Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('TEMPORARY KEYS & GRANTS'),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: VoltVaultTheme.primaryNeoMint),
                          onPressed: _showCreateGrantBottomSheet,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_temporaryGrants.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No temporary access grants active.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: VoltVaultTheme.textSecondary),
                        ),
                      )
                    else
                      ..._temporaryGrants.map((g) => _buildTemporaryGrantCard(g)),
                  ],
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
        letterSpacing: 2.0,
        color: VoltVaultTheme.primaryNeoMint,
      ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
    final access = device['access_level'] ?? 'read_only';
    final name = device['device_name'] ?? 'Authorized Device';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: VoltVaultTheme.glassCardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.smartphone_rounded, color: VoltVaultTheme.textSecondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('Permission: ${access.toString().toUpperCase()}', style: const TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VoltVaultTheme.primaryNeoMint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ACTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: VoltVaultTheme.primaryNeoMint)),
          ),
        ],
      ),
    );
  }

  Widget _buildTemporaryGrantCard(Map<String, dynamic> grant) {
    final grantee = grant['grantee_phone'] ?? 'Temporary User';
    final expires = DateTime.parse(grant['expires_at'].toString()).toLocal();
    final permissions = grant['access_grant_permissions']?[0] ?? grant['permissions'] ?? {};

    // Get list of enabled permission flags
    List<String> scopes = [];
    if (permissions['read_only'] == true) scopes.add('Read');
    if (permissions['diagnostics'] == true) scopes.add('Diag');
    if (permissions['firmware'] == true) scopes.add('Firm');
    if (permissions['battery_write'] == true) scopes.add('Volt');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: VoltVaultTheme.glassCardDecoration(),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: VoltVaultTheme.alertAmber),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(grantee, style: const TextStyle(fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary)),
                const SizedBox(height: 2),
                Text('Scopes: ${scopes.join(" | ")}', style: const TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('Expires: ${expires.hour}:${expires.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 10, color: VoltVaultTheme.alertAmber, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: VoltVaultTheme.alertRed, size: 22),
            onPressed: () => _revokeGrant(grant['id'].toString()),
          ),
        ],
      ),
    );
  }

  void _showCreateGrantBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: VoltVaultTheme.bgObsidianLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Grant Scoped Access',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),

                  // Phone input
                  const Text('RECIPIENT PHONE NUMBER', style: TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 XXXXX XXXXX',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Duration Selector
                  const Text('KEY VALIDITY DURATION', style: TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDurationRadio('15m', '15 Min', setModalState),
                      _buildDurationRadio('1h', '1 Hour', setModalState),
                      _buildDurationRadio('1d', '1 Day', setModalState),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Scopes Toggle Checklist
                  const Text('PERMISSION SCOPES', style: TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _readOnly,
                    title: const Text('Read Only (Live telemetry feeds)', style: TextStyle(fontSize: 13)),
                    activeColor: VoltVaultTheme.primaryNeoMint,
                    onChanged: (val) => setModalState(() => _readOnly = val ?? true),
                  ),
                  CheckboxListTile(
                    value: _diagnostics,
                    title: const Text('Diagnostics (Read error logs)', style: TextStyle(fontSize: 13)),
                    activeColor: VoltVaultTheme.primaryNeoMint,
                    onChanged: (val) => setModalState(() => _diagnostics = val ?? false),
                  ),
                  CheckboxListTile(
                    value: _firmware,
                    title: const Text('Firmware (Allow flash commands)', style: TextStyle(fontSize: 13)),
                    activeColor: VoltVaultTheme.primaryNeoMint,
                    onChanged: (val) => setModalState(() => _firmware = val ?? false),
                  ),
                  CheckboxListTile(
                    value: _batteryWrite,
                    title: const Text('Battery Settings (Write thresholds)', style: TextStyle(fontSize: 13)),
                    activeColor: VoltVaultTheme.primaryNeoMint,
                    onChanged: (val) => setModalState(() => _batteryWrite = val ?? false),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _createTemporaryGrant,
                    child: const Text('GENERATE SECURE KEY'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDurationRadio(String value, String label, StateSetter setModalState) {
    final active = _selectedDuration == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: VoltVaultTheme.primaryNeoMint.withOpacity(0.15),
      checkmarkColor: VoltVaultTheme.primaryNeoMint,
      onSelected: (selected) {
        if (selected) {
          setModalState(() {
            _selectedDuration = value;
          });
        }
      },
    );
  }
}
