import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bms/core/network/supabase_client.dart';

class AuthProvider extends ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  AuthProvider._internal();

  final _supabase = SupabaseConfig.client;
  final _localAuth = LocalAuthentication();

  User? _user;
  User? get user => _user;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isKycVerified = false;
  bool get isKycVerified => _isKycVerified;

  String? _kycStatus = 'pending';
  String? get kycStatus => _kycStatus;

  bool _biometricsEnabled = false;
  bool get biometricsEnabled => _biometricsEnabled;

  bool _isLocalLocked = false;
  bool get isLocalLocked => _isLocalLocked;

  String? _displayName = 'Rider';
  String? get displayName => _displayName;

  // Initialize Auth State
  void init() {
    _user = _supabase.auth.currentUser;
    _isAuthenticated = _user != null;
    if (_isAuthenticated) {
      _fetchProfile();
    }
    notifyListeners();
  }

  // Email Sign Up
  Future<bool> signUpWithEmail(String email, String password, String name) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      _user = response.user;
      _isAuthenticated = _user != null;
      if (_isAuthenticated) {
        await _createInitialProfile(name, email);
        await _fetchProfile();
      }
      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      debugPrint("Error signing up: $e");
      return false;
    }
  }

  // Email Sign In
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _user = response.user;
      _isAuthenticated = _user != null;
      if (_isAuthenticated) {
        await _fetchProfile();
      }
      notifyListeners();
      return _isAuthenticated;
    } catch (e) {
      debugPrint("Error signing in: $e");
      return false;
    }
  }

  // Create Profile in public.owners if not exists (fallback helper)
  Future<void> _createInitialProfile(String name, String email) async {
    if (_user == null) return;
    try {
      final existing = await _supabase
          .from('owners')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('owners').insert({
          'id': _user!.id,
          'display_name': name,
          'email': email,
          'kyc_status': 'pending',
        });
      }
    } catch (e) {
      debugPrint("Error creating initial profile: $e");
    }
  }

  // Fetch Profile Details from public.owners
  Future<void> _fetchProfile() async {
    if (_user == null) return;
    try {
      final data = await _supabase
          .from('owners')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      
      if (data != null) {
        _displayName = data['display_name'] ?? 'Rider';
        _kycStatus = data['kyc_status'] ?? 'pending';
        _isKycVerified = _kycStatus == 'verified';
      } else {
        // Trigger might still be running or hasn't finished, so we create standard values
        _displayName = _user!.userMetadata?['display_name'] ?? 'Rider';
        _kycStatus = 'pending';
        _isKycVerified = false;
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    }
  }

  // Update Profile Name/Email
  Future<bool> updateProfile(String name, String email) async {
    if (_user == null) return false;

    try {
      await _supabase.from('owners').update({
        'display_name': name,
        'email': email,
      }).eq('id', _user!.id);
      _displayName = name;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Error updating profile: $e");
      return false;
    }
  }

  // Enable/Disable Biometrics
  Future<bool> toggleBiometrics(bool enable) async {
    bool canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    if (!canAuthenticate) return false;

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: enable ? 'Confirm biometrics to secure VoltVault' : 'Confirm biometrics to disable lock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _biometricsEnabled = enable;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error in biometrics auth: $e");
      return false;
    }
  }

  // Authenticate app local lock screen
  Future<bool> authenticateLocalLock() async {
    if (!_biometricsEnabled) {
      _isLocalLocked = false;
      notifyListeners();
      return true;
    }

    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock VoltVault to access dashboard',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _isLocalLocked = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Error unlocking app: $e");
      return false;
    }
  }

  // Trigger Local Lock
  void lockApp() {
    if (_biometricsEnabled) {
      _isLocalLocked = true;
      notifyListeners();
    }
  }

  // Logout Session
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    _user = null;
    _isAuthenticated = false;
    _isKycVerified = false;
    _kycStatus = 'pending';
    _biometricsEnabled = false;
    _isLocalLocked = false;
    _displayName = 'Rider';
    notifyListeners();
  }
}
