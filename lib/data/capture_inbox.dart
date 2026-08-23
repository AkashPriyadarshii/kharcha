import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/upi_parser.dart';
import 'notifications.dart';
import 'transaction_repository.dart';

/// Path of the Kotlin-written inbox (matches UpiNotificationListener.kt & SmsReceiver.kt).
/// Must be `getCacheDir()` on Android — the Kotlin side writes to
/// `context.cacheDir` (`cache/`), while `getApplicationCacheDirectory()` is
/// `code_cache/` (a different dir). A mismatch silently killed all capture.
Future<File> captureInboxFile() async {
  final dir = await getTemporaryDirectory();
  return File('${dir.path}/upi_inbox.jsonl');
}

/// File storing recent unrecognized financial messages for diagnostics.
File unrecognizedInboxFile(Directory cacheDir) {
  return File('${cacheDir.path}/unrecognized_inbox.jsonl');
}

void _recordUnrecognized(Directory cacheDir, String jsonLine) {
  try {
    final unrecFile = unrecognizedInboxFile(cacheDir);
    var existing = unrecFile.existsSync()
        ? unrecFile.readAsLinesSync().where((l) => l.trim().isNotEmpty).toList()
        : <String>[];
    if (existing.length >= 50) {
      existing = existing.sublist(existing.length - 49);
    }
    existing.add(jsonLine);
    unrecFile.writeAsStringSync('${existing.join('\n')}\n');
  } catch (_) {
    // Ignore diagnostic logging failure
  }
}

/// Drains the Kotlin-written UPI & SMS inbox: parses each line, dedupes, inserts,
/// and dispatches real-time transaction notification alerts if [notifications] is provided.
/// Returns how many expenses were newly added.
Future<int> drainCaptureInbox({
  required File inbox,
  required TransactionRepository repo,
  Notifications? notifications,
}) async {
  if (!inbox.existsSync()) return 0;

  var added = 0;
  for (final line in inbox.readAsLinesSync()) {
    final lineTrim = line.trim();
    if (lineTrim.isEmpty) continue;

    final ParsedUpiPayment? parsed;
    DateTime txnDate = DateTime.now();
    try {
      final map = jsonDecode(lineTrim) as Map<String, dynamic>;
      final rawText = (map['text'] ?? '') as String;
      
      if (map['seenAt'] != null) {
        try {
          txnDate = DateTime.parse(map['seenAt'] as String).toLocal();
        } catch (_) {}
      }
      
      parsed = parseUpiNotification(rawText);
      if (parsed == null && RegExp(r'(?:₹|Rs\.?|INR|\b\d{2,}\b)', caseSensitive: false).hasMatch(rawText)) {
        _recordUnrecognized(inbox.parent, lineTrim);
      }
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
        txnDate: txnDate,
        isIncome: parsed.isIncome,
        balance: parsed.balance,
      );
      if (inserted != null) {
        added++;
        if (notifications != null) {
          final catName = await repo.categoryNameById(inserted.categoryId);
          await notifications.showTransactionCaptured(
            amount: parsed.amount,
            merchant: parsed.merchant,
            isIncome: parsed.isIncome,
            categoryName: catName,
          );

          if (!inserted.isIncome && inserted.categoryId != null) {
            final status = await repo.checkCategoryBudgetStatus(inserted.categoryId!, inserted.txnDate);
            if (status != null && status.$4 >= 80) {
              final prevSpent = status.$2 - inserted.amount;
              final prevPct = (prevSpent / status.$3 * 100).round();
              
              if ((status.$4 >= 80 && prevPct < 80) || (status.$4 >= 100 && prevPct < 100)) {
                await notifications.showBudgetThresholdAlert(
                  categoryName: status.$1,
                  spent: status.$2,
                  budget: status.$3,
                  pct: status.$4,
                );
              }
            }
          }
        }
      }
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
