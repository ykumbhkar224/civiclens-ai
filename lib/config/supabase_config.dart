import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url =
      String.fromEnvironment('SUPABASE_URL');
  static const String publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  static SupabaseClient get client => Supabase.instance.client;
}
