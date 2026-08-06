import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/upi_parser.dart';
import 'transaction_repository.dart';

/// Path of the Kotlin-written inbox (matches UpiNotificationListener.kt).
Future<File> captureInboxFile() async {
  final dir = await getApplicationCacheDirectory();
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

    final inserted = await repo.insertCaptured(
      amount: parsed.amount,
      merchant: parsed.merchant,
      upiRef: parsed.upiRef,
      txnDate: DateTime.now(),
    );
    if (inserted != null) added++;
  }

  // Consumed the whole file — truncate so a notification is never replayed.
  inbox.writeAsStringSync('');
  return added;
}
