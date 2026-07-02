import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bms/core/theme/voltvault_theme.dart';

class KycIntroScreen extends StatefulWidget {
  const KycIntroScreen({super.key});

  @override
  State<KycIntroScreen> createState() => _KycIntroScreenState();
}

class _KycIntroScreenState extends State<KycIntroScreen> {
  String? _selectedDoc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Identity Verification'),
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
                const SizedBox(height: 16),
                Center(
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 80,
                    color: VoltVaultTheme.primaryNeoMint.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Verify Your Identity',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: VoltVaultTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To connect to your vehicle\'s BMS and prevent unauthorized access, we need to bind the vehicle to a verified government ID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: VoltVaultTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Document list selection
                const Text(
                  'SELECT CHANNELS FOR VERIFICATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: VoltVaultTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Aadhaar Option
                _buildDocOption(
                  id: 'aadhaar',
                  title: 'Aadhaar Card (India)',
                  subtitle: 'Verify instantly using OTP or document photo',
                  icon: Icons.credit_card_rounded,
                ),
                const SizedBox(height: 12),

                // Driving License Option
                _buildDocOption(
                  id: 'driving_license',
                  title: 'Driving License',
                  subtitle: 'Upload photo of your active driving permit',
                  icon: Icons.drive_eta_rounded,
                ),
                
                const Spacer(),
                
                ElevatedButton(
                  onPressed: _selectedDoc == null
                      ? null
                      : () => context.push('/kyc-capture?docType=$_selectedDoc'),
                  child: const Text(
                    'START VERIFICATION',
                    style: TextStyle(letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedDoc == id;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDoc = id;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? VoltVaultTheme.primaryNeoMint.withOpacity(0.08)
              : const Color(0x0CFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? VoltVaultTheme.primaryNeoMint
                : const Color(0x1FFFFFFF),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? VoltVaultTheme.primaryNeoMint.withOpacity(0.12)
                    : const Color(0x0AFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: VoltVaultTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? VoltVaultTheme.primaryNeoMint : VoltVaultTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
