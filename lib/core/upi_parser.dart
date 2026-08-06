import 'dart:convert';

/// A UPI payment parsed from a notification's text.
class ParsedUpiPayment {
  ParsedUpiPayment({
    required this.amount,
    required this.merchant,
    required this.upiRef,
  });

  final double amount;
  final String merchant;
  final String? upiRef;
}

final _amountRe = RegExp(r'(?:₹|Rs\.?|INR)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);
final _merchantRe = RegExp(
  r'(?:paid to|to|at|towards|for)\s+([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=[,.]|\s+(?:upi|ref|utr|on|via|on\s+)|$)',
  caseSensitive: false,
);
final _upiRefRe = RegExp(r'(?:upi\s*ref(?:erence)?|utr|ref(?:erence)?|ref\s*id)\s*[:#-]?\s*([A-Z0-9]{10,})', caseSensitive: false);
final _receivedRe = RegExp(r'(received|credited|accepted)', caseSensitive: false);

/// Parses UPI notification [text] into a payment, or null if it isn't a UPI
/// payment (or is money in, not out). Rule-based regex only — no AI.
ParsedUpiPayment? parseUpiNotification(String text) {
  if (text.trim().isEmpty) return null;

  // Only spending: skip money-received notifications.
  if (_receivedRe.hasMatch(text)) return null;

  final amountMatch = _amountRe.firstMatch(text);
  if (amountMatch == null) return null;

  final amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
  if (amount <= 0) return null;

  final merchantMatch = _merchantRe.firstMatch(text);
  final merchant = merchantMatch?.group(1)?.trim();

  final ref = _upiRefRe.firstMatch(text);

  return ParsedUpiPayment(
    amount: amount,
    merchant: (merchant == null || merchant.isEmpty) ? 'Unknown' : merchant,
    upiRef: ref?.group(1),
  );
}

/// Encodes a raw capture line for the inbox JSONL file.
String encodeInboxLine({required String package, required String text, required String seenAt}) {
  return jsonEncode({'package': package, 'text': text, 'seenAt': seenAt});
}
