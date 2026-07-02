import 'package:flutter_test/flutter_test.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/ble_manager.dart';

void main() {
  test('VoltVault Theme Colors test', () {
    expect(VoltVaultTheme.primaryNeoMint, isNotNull);
    expect(VoltVaultTheme.bgObsidianDark, isNotNull);
  });

  test('BleManager initial state test', () {
    final ble = BleManager();
    expect(ble.isMockMode, true);
    expect(ble.isConnected, false);
    expect(ble.isScanning, false);
  });
}
