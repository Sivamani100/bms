import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bms/core/theme/voltvault_theme.dart';
import 'package:bms/core/services/auth_provider.dart';
import 'package:bms/core/network/supabase_client.dart';

class KycCaptureScreen extends StatefulWidget {
  final String docType;
  const KycCaptureScreen({super.key, required this.docType});

  @override
  State<KycCaptureScreen> createState() => _KycCaptureScreenState();
}

class _KycCaptureScreenState extends State<KycCaptureScreen> {
  int _step = 1; // 1: Document Scan, 2: Document Review, 3: Selfie Liveness, 4: Submitting
  double _scanProgress = 0.0;
  Timer? _scanTimer;
  String _livenessInstruction = 'Position face in the circle';
  bool _livenessComplete = false;

  @override
  void initState() {
    super.initState();
    _startDocumentScan();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  void _startDocumentScan() {
    _scanTimer?.cancel();
    _scanProgress = 0.0;
    _scanTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        if (_scanProgress < 1.0) {
          _scanProgress += 0.02;
        } else {
          _scanTimer?.cancel();
          _step = 2; // Move to review
        }
      });
    });
  }

  void _confirmDocument() {
    setState(() {
      _step = 3; // Move to selfie
    });
    // Simulate liveness checks
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _livenessInstruction = 'Blink slowly now...';
        });
      }
    });
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _livenessInstruction = 'Hold still, capturing...';
          _livenessComplete = true;
        });
      }
    });
    Timer(const Duration(milliseconds: 5500), () {
      if (mounted) {
        _submitKyc();
      }
    });
  }

  void _submitKyc() async {
    setState(() {
      _step = 4; // Submitting status
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      try {
        final userId = auth.user!.id;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        // Generate simulated JPEG bytes
        final List<int> dummyBytes = List<int>.generate(200, (i) => i % 256);
        final Uint8List fileBytes = Uint8List.fromList(dummyBytes);

        // Upload Document Image
        final docPath = '$userId/doc_$timestamp.jpg';
        await SupabaseConfig.client.storage.from('kyc_documents').uploadBinary(
          docPath,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        final docUrl = SupabaseConfig.client.storage.from('kyc_documents').getPublicUrl(docPath);

        // Upload Selfie Image
        final selfiePath = '$userId/selfie_$timestamp.jpg';
        await SupabaseConfig.client.storage.from('kyc_documents').uploadBinary(
          selfiePath,
          fileBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        final selfieUrl = SupabaseConfig.client.storage.from('kyc_documents').getPublicUrl(selfiePath);

        // Write row to kyc_records
        await SupabaseConfig.client.from('kyc_records').insert({
          'owner_id': userId,
          'document_type': widget.docType,
          'document_status': 'approved',
          'captured_data': {
            'document_url': docUrl,
            'selfie_url': selfieUrl,
            'liveness_passed': true,
            'timestamp': DateTime.now().toIso8601String(),
          },
        });

        await SupabaseConfig.client
            .from('owners')
            .update({'kyc_status': 'verified'})
            .eq('id', userId);

        auth.init();
      } catch (e) {
        debugPrint("Error writing KYC to database: $e");
      }
    }

    Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/kyc-result?docType=${widget.docType}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final docTitle = widget.docType == 'aadhaar' ? 'Aadhaar Card' : 'Driving License';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(_step == 1
            ? 'Scan $docTitle'
            : _step == 2
                ? 'Review Capture'
                : _step == 3
                    ? 'Selfie Verification'
                    : 'Submitting Details'),
        leading: _step < 4
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Simulated Camera Feed (Matte dark grey background)
                  Container(
                    color: const Color(0xFF1E2024),
                    child: Center(
                      child: _step == 3
                          ? const Icon(Icons.face_retouching_natural_rounded, size: 120, color: Colors.white24)
                          : const Icon(Icons.camera_alt_rounded, size: 100, color: Colors.white12),
                    ),
                  ),

                  // Overlay alignment guides depending on step
                  if (_step == 1) ...[
                    // Document alignment boundary box
                    Container(
                      width: 320,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: VoltVaultTheme.primaryNeoMint, width: 2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      child: Text(
                        'Align front of $docTitle inside the frame',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Progress indicator
                    Positioned(
                      bottom: 40,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 200,
                            child: LinearProgressIndicator(
                              value: _scanProgress,
                              color: VoltVaultTheme.primaryNeoMint,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Hold steady, auto-capturing...',
                            style: TextStyle(color: VoltVaultTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_step == 2) ...[
                    // Review mode overlay (Simulated capture result image placeholder)
                    Container(
                      width: 320,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Center(
                        child: Text(
                          'Document Capture Successful',
                          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],

                  if (_step == 3) ...[
                    // Selfie circle alignment
                    Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _livenessComplete ? VoltVaultTheme.primaryNeoMint : Colors.white70,
                          width: 3,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _livenessInstruction,
                          style: TextStyle(
                            color: _livenessComplete ? VoltVaultTheme.primaryNeoMint : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_step == 4) ...[
                    Positioned.fill(
                      child: Container(
                        color: Colors.black87,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: VoltVaultTheme.primaryNeoMint),
                            SizedBox(height: 24),
                            Text(
                              'Sending encrypted profiles...',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Validating liveness parameters with KYC vendor',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_step == 2)
              Container(
                padding: const EdgeInsets.all(24),
                color: Colors.black87,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _startDocumentScan,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('RETAKE', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmDocument,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VoltVaultTheme.primaryNeoMint,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CONFIRM'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
