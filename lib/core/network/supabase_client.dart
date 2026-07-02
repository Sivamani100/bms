import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://yhkwfcreooqqhxqdgdme.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inloa3dmY3Jlb29xcWh4cWRnZG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI5NzYxNTMsImV4cCI6MjA5ODU1MjE1M30.oKYXkDz8r8gHJKt0RyI4tCy5pFYL9ndlO5TofX8_dkg';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    try {
      await client.storage.createBucket('kyc_documents');
    } catch (_) {
      // Silently ignore if already exists or if anonymous creation is restricted
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
