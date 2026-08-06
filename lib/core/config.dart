/// Supabase connection config.
///
/// The anon key is public by design — it's not a secret. RLS on the
/// Supabase tables is the real security boundary. Never put the service
/// role key here.
class SupabaseConfig {
  static const String url = 'https://iyjrpsunhnnminfmurih.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5anJwc3VuaG5ubWluZm11cmloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzExNTYsImV4cCI6MjEwMTYwNzE1Nn0.Ka5hUZLATGFbBB2WthYoM-t60p8HDPK-e0P9RUCmHSg';
}
