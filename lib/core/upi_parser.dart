import 'dart:convert';

/// A UPI/bank payment parsed from a notification's text. Rule-based, no AI.
/// Covers UPI apps, bank apps, and messaging apps (amount + payment keyword).
class ParsedUpiPayment {
  ParsedUpiPayment({
    required this.amount,
    required this.merchant,
    required this.isIncome,
    this.upiRef,
  });

  final double amount;
  final String merchant;

  /// True when money came IN (received/credited). False for spending.
  final bool isIncome;
  final String? upiRef;
}

// Amount: ₹ / Rs. / INR, optional space, digits + optional decimals.
final _amountRe = RegExp(
  r'(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)',
  caseSensitive: false,
);
// Spend verbs (outgoing). "sent" covers bank "sent ₹X to"; "money sent"
// is GPay's header. Never treat "received/credited/added" as outgoing.
final _spendRe = RegExp(
  r'\b(?:debited|paid|transferred|sent|spent)\b',
  caseSensitive: false,
);
// Money-in verbs.
final _receiveRe = RegExp(
  r'\b(?:received|credited|added to your|added in your|refund|money received)\b',
  caseSensitive: false,
);
// Merchant: "paid to X", "to X", "at X", "debited at X", "debited from X",
// "transferred to X", "sent X to Y", GPay "Money sent · ₹X · Y" (keyword ·).
final _merchantRe = RegExp(
  r'(?:paid to|transferred to|sent to|debited (?:at|from)|sent .{0,12}to|to|at|towards|for)\s+'
  r'([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=,|\.|$|\s+(?:upi|ref|utr|on|via|on\s+|bank|a/c|by|from|using|credited|received))'
  r'|·\s*([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=\s*·|\s+UPI|\s+Ref|$)',
  caseSensitive: false,
);
// UPI ref: "UPI Ref 123456789012", "UTR 9876543210", "Ref: ABCDEF123456",
// "Ref ID 1234..." — 10+ chars. Also bare 12-digit (banks).
final _upiRefRe = RegExp(
  r'(?:upi\s*ref(?:erence)?|utr|ref(?:erence)?\s*id|ref\s*id|ref)\s*[:#-]?\s*([A-Za-z0-9]{10,})',
  caseSensitive: false,
);
final _upiRefBareRe = RegExp(r'\b(\d{12})\b');

/// Parses [text] into a payment, or null if it isn't a payment notification
/// (no amount, or no payment verb — e.g. a casual "send me ₹200" chat).
ParsedUpiPayment? parseUpiNotification(String text) {
  if (text.trim().isEmpty) return null;

  final amountMatch = _amountRe.firstMatch(text);
  if (amountMatch == null) return null;
  final amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
  if (amount <= 0) return null;

  final isIncome = _receiveRe.hasMatch(text);
  final isSpend = _spendRe.hasMatch(text);
  // No payment verb → not a transaction (chat, promo, "you owe ₹X").
  if (!isIncome && !isSpend) return null;

  final merchantMatch = _merchantRe.firstMatch(text);
  final merchant = merchantMatch?.group(1) ?? merchantMatch?.group(2);
  final ref = _upiRefRe.firstMatch(text)?.group(1) ??
      (isSpend ? _upiRefBareRe.firstMatch(text)?.group(1) : null);

  return ParsedUpiPayment(
    amount: amount,
    merchant: (merchant == null || merchant.isEmpty) ? 'Unknown' : merchant,
    isIncome: isIncome,
    upiRef: ref,
  );
}

/// Encodes a raw capture line for the inbox JSONL file.
String encodeInboxLine({required String package, required String text, required String seenAt}) {
  return jsonEncode({'package': package, 'text': text, 'seenAt': seenAt});
}
