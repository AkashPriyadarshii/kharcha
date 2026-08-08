import 'package:flutter/foundation.dart';

/// Supabase connection config.
///
/// The anon key is public by design — it's not a secret. RLS on the
/// Supabase tables is the real security boundary. Never put the service
/// role key here.
class SupabaseConfig {
  static const String url = 'https://iyjrpsunhnnminfmurih.supabase.co';

  /// Web OAuth client for native Google sign-in (serverClientId).
  static const String googleWebClientId =
      '820021611320-j434c209avi6gv13i3bd7iaec87ti3sd.apps.googleusercontent.com';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml5anJwc3VuaG5ubWluZm11cmloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMzExNTYsImV4cCI6MjEwMTYwNzE1Nn0.Ka5hUZLATGFbBB2WthYoM-t60p8HDPK-e0P9RUCmHSg';
}

/// Debug-only Google-auth bypass. Set true to run the app without a session.
/// Only reachable from kDebugMode builds; release builds never set it.
final ValueNotifier<bool> authBypass = ValueNotifier(false);

/// True once first-launch onboarding is done. Loaded from disk in main();
/// gates the home route until the user finishes (or skips) onboarding.
final ValueNotifier<bool> onboardingDone = ValueNotifier(false);
