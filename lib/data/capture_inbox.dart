import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/upi_parser.dart';
import 'transaction_repository.dart';

/// Path of the Kotlin-written inbox (matches UpiNotificationListener.kt).
/// Must be `getCacheDir()` on Android — the Kotlin side writes to
/// `context.cacheDir` (`cache/`), while `getApplicationCacheDirectory()` is
/// `code_cache/` (a different dir). A mismatch silently killed all capture.
Future<File> captureInboxFile() async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/upi_inbox.jsonl');
}

/// Drains the Kotlin-written UPI inbox: parses each line, dedupes, inserts.
/// Returns how many expenses were newly added.
Future<int> drainCaptureInbox({required File inbox, required TransactionRepository repo}) async {
  if (!inbox.existsSync()) return 0;

  var added = 0;
  for (final line in inbox.readAsLinesSync()) {
    final lineTrim = line.trim();
    if (lineTrim.isEmpty) continue;

    final ParsedUpiPayment? parsed;
    try {
      final map = jsonDecode(lineTrim) as Map<String, dynamic>;
      parsed = parseUpiNotification((map['text'] ?? '') as String);
    } catch (_) {
      // A corrupt/partial line is not worth crashing over — skip it.
      continue;
    }
    if (parsed == null) continue;

    try {
      final inserted = await repo.insertCaptured(
        amount: parsed.amount,
        merchant: parsed.merchant,
        upiRef: parsed.upiRef,
        txnDate: DateTime.now(),
        isIncome: parsed.isIncome,
      );
      if (inserted != null) added++;
    } catch (_) {
      // A single insert failure (e.g. constraint) must not abort the drain —
      // that would replay every earlier line as a duplicate on the next open.
      continue;
    }
  }

  // Consumed the whole file — truncate so a notification is never replayed.
  inbox.writeAsStringSync('');
  return added;
}
