import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/auth_provider.dart';

class KycResultScreen extends StatefulWidget {
  final String docType;
  const KycResultScreen({super.key, required this.docType});

  @override
  State<KycResultScreen> createState() => _KycResultScreenState();
}

class _KycResultScreenState extends State<KycResultScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final status = auth.kycStatus ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification Outcome'),
        automaticallyImplyLeading: false,
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
                const Spacer(flex: 1),
                
                // Outcome card
                _buildOutcomeCard(status),

                const Spacer(flex: 2),
                
                // Primary action routing
                ElevatedButton(
                  onPressed: () {
                    if (status == 'verified') {
                      context.go('/pair'); // move to pairing vehicles
                    } else if (status == 'failed') {
                      context.go('/kyc-intro'); // try again
                    } else {
                      context.go('/dashboard'); // dashboard in pending mode
                    }
                  },
                  child: Text(
                    status == 'verified'
                        ? 'ADD VEHICLE'
                        : status == 'failed'
                            ? 'TRY AGAIN'
                            : 'GO TO DASHBOARD',
                    style: const TextStyle(letterSpacing: 1.5),
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

  Widget _buildOutcomeCard(String status) {
    switch (status) {
      case 'verified':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: VoltVaultTheme.alertGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded, size: 80, color: VoltVaultTheme.alertGreen),
            ),
            const SizedBox(height: 24),
            const Text(
              'Identity Verified!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Congratulations, your account has been successfully verified. You can now register and pair electric vehicles.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: VoltVaultTheme.textSecondary, height: 1.5),
            ),
          ],
        );
      case 'failed':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: VoltVaultTheme.alertRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 80, color: VoltVaultTheme.alertRed),
            ),
            const SizedBox(height: 24),
            const Text(
              'Verification Failed',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'The document image captured was unreadable or the liveness check failed. Please ensure adequate lighting and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: VoltVaultTheme.textSecondary, height: 1.5),
            ),
          ],
        );
      case 'in_review':
      default:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: VoltVaultTheme.alertAmber.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pending_actions_rounded, size: 80, color: VoltVaultTheme.alertAmber),
            ),
            const SizedBox(height: 24),
            const Text(
              'Under Manual Review',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: VoltVaultTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your document capture quality was borderline. A reviewer is verifying your credentials now. We\'ll notify you once complete.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: VoltVaultTheme.textSecondary, height: 1.5),
            ),
          ],
        );
    }
  }
}
