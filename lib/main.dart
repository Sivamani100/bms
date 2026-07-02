import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/network/supabase_client.dart';
import 'package:bms/core/services/auth_provider.dart';
import 'package:bms/core/services/ble_manager.dart';
import 'package:bms/core/services/background_service.dart';

// Authentication Screens
import 'package:bms/features/auth/splash_screen.dart';
import 'package:bms/features/auth/welcome_screen.dart';
import 'package:bms/features/auth/profile_setup_screen.dart';

// KYC Screens
import 'package:bms/features/kyc/kyc_intro_screen.dart';
import 'package:bms/features/kyc/kyc_capture_screen.dart';
import 'package:bms/features/kyc/kyc_result_screen.dart';

// Vehicle Pairing Screens
import 'package:bms/features/vehicle/pairing_scan_screen.dart';
import 'package:bms/features/vehicle/pairing_confirm_screen.dart';

// Dashboard & Services Screens
import 'package:bms/features/dashboard/dashboard_screen.dart';
import 'package:bms/features/permissions/permissions_screen.dart';
import 'package:bms/features/alerts/emergency_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase Client
  await SupabaseConfig.initialize();

  // Initialize Foreground monitoring service
  final bg = BackgroundService();
  bg.initService();

  // Initialize auth state
  final auth = AuthProvider();
  auth.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => BleManager()),
      ],
      child: const VoltVaultApp(),
    ),
  );
}

class VoltVaultApp extends StatelessWidget {
  const VoltVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VoltVault',
      theme: VoltVaultTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}

// Router configuration
final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/kyc-intro',
      builder: (context, state) => const KycIntroScreen(),
    ),
    GoRoute(
      path: '/kyc-capture',
      builder: (context, state) {
        final docType = state.uri.queryParameters['docType'] ?? 'aadhaar';
        return KycCaptureScreen(docType: docType);
      },
    ),
    GoRoute(
      path: '/kyc-result',
      builder: (context, state) {
        final docType = state.uri.queryParameters['docType'] ?? 'aadhaar';
        return KycResultScreen(docType: docType);
      },
    ),
    GoRoute(
      path: '/pair',
      builder: (context, state) => const PairingScanScreen(),
    ),
    GoRoute(
      path: '/pair-confirm',
      builder: (context, state) {
        final deviceId = state.uri.queryParameters['deviceId'] ?? '';
        final deviceName = Uri.decodeComponent(state.uri.queryParameters['name'] ?? 'BMS Unit');
        return PairingConfirmScreen(deviceId: deviceId, deviceName: deviceName);
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/devices',
      builder: (context, state) => const PermissionsScreen(),
    ),
    GoRoute(
      path: '/emergency',
      builder: (context, state) => const EmergencyScreen(),
    ),
  ],
);
