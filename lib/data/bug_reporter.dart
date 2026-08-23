import 'dart:io';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app bug reporting → `bug_reports` table on Supabase. The owner reads
/// them in the dashboard Table Editor. Requires a session (authenticated
/// insert, user_id from the JWT — free attribution, no spam from guests).
/// ponytail: no device model — the OS string is enough to triage; add
/// device_info_plus when a report shows up that needs it.
class BugReporter {
  const BugReporter();

  /// Version + OS that describes this install, e.g.
  /// "v0.2.6 / Android 14 (API 34)".
  Future<String> describeEnvironment() async {
    String version = 'unknown';
    try {
      version = await const MethodChannel('com.kharcha.app/update')
              .invokeMethod<String>('getVersion') ??
          'unknown';
    } catch (_) {
      // channel missing on non-android debug runs — keep 'unknown'.
    }
    return 'v$version / ${Platform.operatingSystem} ${Platform.version}';
  }

  /// Files the report. Throws on failure so the UI can say so.
  Future<void> report(String message, {String? environment}) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Sign in to report a bug.');
    }
    await Supabase.instance.client.from('bug_reports').insert({
      'user_id': session.user.id,
      'message': message,
      'app_version': environment,
    });
  }
}
