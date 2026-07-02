import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/ble_manager.dart';
import 'package:bms/core/services/auth_provider.dart';
import 'package:bms/core/services/background_service.dart';
import 'package:bms/core/network/supabase_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showHonestyBanner = true;
  String _selectedVehicleName = 'Ather 450X (VoltVault)';
  bool _isBackgroundServiceRunning = false;
  List<Map<String, dynamic>> _alerts = [];
  RealtimeChannel? _alertsChannel;

  @override
  void initState() {
    super.initState();
    _checkServiceStatus();
    _fetchDbAlerts();
    _subscribeToAlerts();
  }

  @override
  void dispose() {
    if (_alertsChannel != null) {
      SupabaseConfig.client.removeChannel(_alertsChannel!);
    }
    super.dispose();
  }

  void _checkServiceStatus() async {
    // Check foreground service status
    final running = await BackgroundService().startService();
    setState(() {
      _isBackgroundServiceRunning = running;
    });
  }

  void _toggleForegroundService() async {
    if (_isBackgroundServiceRunning) {
      await BackgroundService().stopService();
      setState(() {
        _isBackgroundServiceRunning = false;
      });
    } else {
      BackgroundService().initService();
      final running = await BackgroundService().startService();
      setState(() {
        _isBackgroundServiceRunning = running;
      });
    }
  }

  // Fetch alerts from database
  void _fetchDbAlerts() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    try {
      final res = await SupabaseConfig.client
          .from('alerts')
          .select()
          .eq('status', 'unresolved')
          .order('created_at', ascending: false);
      setState(() {
        _alerts = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint("Error fetching alerts: $e");
    }
  }

  // Realtime subscription for alerts
  void _subscribeToAlerts() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) return;

    _alertsChannel = SupabaseConfig.client
        .channel('public:alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          callback: (payload) {
            _fetchDbAlerts();
          },
        );
    _alertsChannel!.subscribe();
  }

  void _triggerSimulatedAlert() async {
    // Generate a mock security alert for testing
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      // Mock local alert
      setState(() {
        _alerts.insert(0, {
          'id': 'sim-alert',
          'type': 'unauthorized_movement',
          'severity': 'high',
          'created_at': DateTime.now().toIso8601String(),
          'status': 'unresolved',
        });
      });
      return;
    }

    try {
      // Retrieve first vehicle to link to the alert
      final vehicles = await SupabaseConfig.client
          .from('vehicles')
          .select('id')
          .limit(1)
          .maybeSingle();

      if (vehicles != null) {
        await SupabaseConfig.client.from('alerts').insert({
          'vehicle_id': vehicles['id'],
          'type': 'unauthorized_movement',
          'severity': 'high',
          'data': {'location': 'Bangalore City Core'},
        });
      }
    } catch (e) {
      debugPrint("Error inserting simulated alert: $e");
    }
  }

  void _resolveSimulatedAlert(String alertId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user == null) {
      setState(() {
        _alerts.removeWhere((element) => element['id'] == alertId);
      });
      return;
    }

    try {
      await SupabaseConfig.client
          .from('alerts')
          .update({'status': 'resolved', 'action_taken': 'Dismissed by Owner'})
          .eq('id', alertId);
      _fetchDbAlerts();
    } catch (e) {
      debugPrint("Error resolving alert: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ble = Provider.of<BleManager>(context);
    final auth = Provider.of<AuthProvider>(context);
    final telemetry = ble.telemetry;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: VoltVaultTheme.obsidianGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar / Profile
              _buildHeader(auth, ble),

              // Active Alert Ribbon
              if (_alerts.isNotEmpty) _buildAlertRibbon(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Honesty Boundary Banner
                      if (_showHonestyBanner) _buildHonestyBanner(),
                      const SizedBox(height: 16),

                      // Vehicle Switcher Row
                      _buildVehicleSwitcher(ble),
                      const SizedBox(height: 16),

                      // Telemetry Hero View
                      _buildHeroTelemetryCard(ble, telemetry),
                      const SizedBox(height: 20),

                      // Quick Actions Row
                      _buildQuickActions(context),
                      const SizedBox(height: 20),

                      // Interactive Map Panel
                      _buildMapPanel(telemetry),
                      const SizedBox(height: 24),

                      // Developer Simulator Trigger Actions
                      _buildDevTriggersPanel(ble, telemetry),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AuthProvider auth, BleManager ble) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: VoltVaultTheme.primaryNeoMint.withOpacity(0.1),
                child: const Icon(Icons.person_rounded, color: VoltVaultTheme.primaryNeoMint),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    auth.displayName ?? 'Rider',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
                  ),
                  Text(
                    auth.isKycVerified ? 'Verified Owner' : 'Pending Verification',
                    style: TextStyle(
                      fontSize: 11,
                      color: auth.isKycVerified ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.alertAmber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: VoltVaultTheme.textSecondary),
            onPressed: () {
              ble.disconnect();
              auth.signOut();
              context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRibbon() {
    final activeAlert = _alerts.first;
    final type = activeAlert['type'] ?? 'security';
    final alertLabel = type == 'unauthorized_movement' ? 'POSSIBLE THEFT DETECTED' : 'BATTERY WARNING';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: VoltVaultTheme.alertRed.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoltVaultTheme.alertRed, width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.gpp_bad_rounded, color: VoltVaultTheme.alertRed, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alertLabel,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: VoltVaultTheme.alertRed, letterSpacing: 1.0),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Vehicle is moving without owner key.',
                  style: TextStyle(fontSize: 11, color: VoltVaultTheme.textPrimary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _resolveSimulatedAlert(activeAlert['id'].toString()),
            style: TextButton.styleFrom(foregroundColor: VoltVaultTheme.textPrimary),
            child: const Text('DISMISS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHonestyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: VoltVaultTheme.glassCardDecoration(
        borderColor: VoltVaultTheme.secondaryCyberBlue.withOpacity(0.3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security_rounded, color: VoltVaultTheme.secondaryCyberBlue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enforcement Honesty Boundary',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'VoltVault monitors and alerts on this vehicle. Remote locking/immobilization requires manufacturer firmware integration, which is currently unavailable.',
                  style: TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: VoltVaultTheme.textSecondary),
            onPressed: () {
              setState(() {
                _showHonestyBanner = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSwitcher(BleManager ble) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.directions_bike_rounded, color: VoltVaultTheme.primaryNeoMint, size: 20),
            const SizedBox(width: 8),
            Text(
              ble.isConnected ? ble.connectedDeviceId ?? _selectedVehicleName : 'No Vehicle Connected',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
            ),
          ],
        ),
        if (!ble.isConnected)
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('PAIR'),
            onPressed: () => context.push('/pair'),
          ),
      ],
    );
  }

  Widget _buildHeroTelemetryCard(BleManager ble, BleDeviceTelemetry? telemetry) {
    final battery = telemetry?.batteryPercent ?? 0;
    final charging = telemetry?.chargingState ?? false;
    final current = telemetry?.current ?? 0.0;
    final voltage = telemetry?.voltage ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: VoltVaultTheme.glassCardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ble.isConnected ? 'ACTIVE GATT BLE SESSION' : 'OFFLINE MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: ble.isConnected ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textMuted,
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ble.isConnected ? VoltVaultTheme.primaryNeoMint : Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Battery percentage ring indicator
          Center(
            child: SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: ble.isConnected ? battery / 100 : 0.0,
                    strokeWidth: 12,
                    color: VoltVaultTheme.primaryNeoMint,
                    backgroundColor: Colors.white10,
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          ble.isConnected ? '$battery%' : '--',
                          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: VoltVaultTheme.textPrimary),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              charging ? Icons.bolt_rounded : Icons.battery_std_rounded,
                              size: 14,
                              color: charging ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              charging ? 'Charging' : 'Ready',
                              style: TextStyle(fontSize: 11, color: charging ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textSecondary, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Secondary Telemetry Metrics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTelemetryMetric('Voltage', ble.isConnected ? '${voltage}V' : '--'),
              Container(width: 1, height: 32, color: Colors.white12),
              _buildTelemetryMetric('Current', ble.isConnected ? '${current}A' : '--'),
              Container(width: 1, height: 32, color: Colors.white12),
              _buildTelemetryMetric('Health', ble.isConnected ? '100%' : '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: VoltVaultTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(Icons.key_rounded, 'Share Key', () => context.push('/devices')),
        _buildActionButton(Icons.gpp_maybe_rounded, 'Emergency', () => context.push('/emergency')),
        _buildActionButton(Icons.history_edu_rounded, 'History', () {}),
        _buildActionButton(
          _isBackgroundServiceRunning ? Icons.verified_rounded : Icons.offline_bolt_outlined,
          _isBackgroundServiceRunning ? 'Active Sec' : 'Sec Alert',
          _toggleForegroundService,
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0x0CFFFFFF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x12FFFFFF)),
            ),
            child: Icon(icon, color: VoltVaultTheme.primaryNeoMint, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: VoltVaultTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildMapPanel(BleDeviceTelemetry? telemetry) {
    final lat = telemetry?.latitude ?? 12.971598;
    final lng = telemetry?.longitude ?? 77.594566;

    return Container(
      height: 200,
      decoration: VoltVaultTheme.glassCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Fallback map view simulation for local developer sandboxes where Google Play Services may not be fully resolved
          Positioned.fill(
            child: Container(
              color: const Color(0xFF1E222A),
              child: CustomPaint(
                painter: MapGridPainter(),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_pin, color: VoltVaultTheme.primaryNeoMint, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white70),
                      ),
                      const Text(
                        'Map Simulator Mode Active',
                        style: TextStyle(fontSize: 10, color: VoltVaultTheme.primaryNeoMint),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevTriggersPanel(BleManager ble, BleDeviceTelemetry? telemetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: VoltVaultTheme.glassCardDecoration(borderColor: VoltVaultTheme.alertAmber.withOpacity(0.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'DEVELOPER SIMULATION CONTROLS',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: VoltVaultTheme.alertAmber,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: ble.isConnected ? () => ble.sendCommand('0xFF') : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VoltVaultTheme.alertAmber.withOpacity(0.15),
                    foregroundColor: VoltVaultTheme.alertAmber,
                    side: const BorderSide(color: VoltVaultTheme.alertAmber, width: 1),
                  ),
                  child: Text(telemetry?.chargingState == true ? 'STOP CHARGING' : 'START CHARGING', style: const TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _triggerSimulatedAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VoltVaultTheme.alertRed.withOpacity(0.15),
                    foregroundColor: VoltVaultTheme.alertRed,
                    side: const BorderSide(color: VoltVaultTheme.alertRed, width: 1),
                  ),
                  child: const Text('TRIGGER THEFT', style: TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw a futuristic cyber grid map simulation
class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    const spacing = 30.0;
    for (double i = 0; i < size.width; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += spacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // Draw simulated routes
    final pathPaint = Paint()
      ..color = VoltVaultTheme.secondaryCyberBlue.withOpacity(0.2)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.8)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.5,
      )
      ..lineTo(size.width * 0.8, size.height * 0.2);

    canvas.drawPath(path, pathPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
