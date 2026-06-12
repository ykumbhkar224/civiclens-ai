import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL']!;
  static String get publishableKey => dotenv.env['SUPABASE_PUBLISHABLE_KEY']!;

  static SupabaseClient get client => Supabase.instance.client;
}
