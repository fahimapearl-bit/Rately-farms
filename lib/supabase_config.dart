import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://buwclqpzihxrcoaotxbw.supabase.co',
  );

  // This is the public publishable/anon key. RLS must remain enabled.
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_7knzZw3vXozW3nJvfXFY9Q_Jq_j07ll',
  );

  static SupabaseClient get client => Supabase.instance.client;
}
