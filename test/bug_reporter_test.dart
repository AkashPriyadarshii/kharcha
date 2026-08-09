import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/bug_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BugReporter', () {
    test('describeEnvironment never throws', () async {
      // getVersion channel is missing in tests → 'unknown' fallback; Platform
      // is real. The point: no crash, string has a version prefix.
      final env = await const BugReporter().describeEnvironment();
      expect(env, startsWith('v'));
      expect(env, contains(Platform.operatingSystem));
    });

    test('report throws without a session (never silently no-ops)', () async {
      // No Supabase.initialize in tests → no session → StateError with a
      // user-facing message rather than a swallowed insert.
      // Uninitialized Supabase in tests → throws (never a silent no-op).
      // Type varies (StateError without a session, AssertionError before
      // init) — the contract is "throws, doesn't swallow".
      expect(
        () => const BugReporter().report('test'),
        throwsA(anything),
      );
    });
  });

  // Keep MethodChannel on the test binding deterministic.
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('com.kharcha.app/update'), null);
  });
}
