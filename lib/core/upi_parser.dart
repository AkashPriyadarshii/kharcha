import 'dart:convert';

import 'money.dart';

/// A UPI/bank payment parsed from a notification's text. Rule-based, no AI.
/// Covers UPI apps, bank apps, and messaging apps (amount + payment keyword).
class ParsedUpiPayment {
  ParsedUpiPayment({
    required this.amount,
    required this.merchant,
    required this.isIncome,
    this.upiRef,
    this.balance,
  });

  final double amount;
  final String merchant;

  /// True when money came IN (received/credited). False for spending.
  final bool isIncome;
  final String? upiRef;
  
  /// The true bank balance extracted from the message (if available).
  final double? balance;
}

// Amount: ₹ / Rs. / INR, optional space, digits + optional decimals (supports Indian comma system).
final _amountRe = RegExp(
  r'(?:₹|Rs\.?|INR)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
  caseSensitive: false,
);

final _amountTrailingRe = RegExp(
  r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:₹|Rs\.?|INR)',
  caseSensitive: false,
);

// Fallback amount in contextual banking sentences: "debited by 500.00" or "credited with 1000"
final _contextualAmountRe = RegExp(
  r'(?:debited (?:by|for)|credited (?:with|by)|spent|paid|amount of|txn of|transfer of)\s+(?:INR|Rs\.?|₹)?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
  caseSensitive: false,
);

// Spend verbs (outgoing).
final _spendRe = RegExp(
  r'\b(?:debited|paid|transferred|sent|spent|payment|txn|transaction|purchase|withdrawn|charged|deducted)\b',
  caseSensitive: false,
);

// Money-in verbs (incoming).
final _receiveRe = RegExp(
  r'\b(?:received|credited|added to your|added in your|added to|refund|refunded|cashback|paid you|sent you|deposited|credited with|money received|inward)\b',
  caseSensitive: false,
);

// UPI/DR or UPI/CR bank narration format: e.g. "Info: UPI/DR/123456789012/SWIGGY/HDFC"
final _bankNarrationRe = RegExp(
  r'UPI\/(?:DR|CR|P2A|P2M)\/(\d+)\/([A-Za-z0-9 &.\-_]+)',
  caseSensitive: false,
);

// GPay bullet format: "Money sent · ₹200 · Swiggy"
final _gpayMerchantRe = RegExp(
  r'·\s*([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=\s*·|\s+UPI|\s+Ref|$)',
  caseSensitive: false,
);

// High-priority explicit recipient: "to X", "paid to X", "at X", "done at X"
final _recipientMerchantRe = RegExp(
  r'(?:paid to|transferred to|sent to|payment to|spent on .*? at|sent .{0,12}to|done at|\bto\b|\bat\b)\s+'
  r'([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))',
  caseSensitive: false,
);

// Fallback purpose/source: "from X", "towards X", "for X", "debited from X"
final _fallbackMerchantRe = RegExp(
  r'(?:from|towards|for|debited (?:at|from))\s+'
  r'([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))',
  caseSensitive: false,
);

// UPI reference / UTR regexes
final _upiRefRe = RegExp(
  r'(?:upi\s*ref(?:erence)?(?:\s*no)?|\bupi\b|utr(?:\s*no)?|ref(?:erence)?\s*id|ref\s*id|ref(?:\s*no)?|trans(?:action)?\s*id|txn\s*id)\s*[:#-]?\s*([A-Za-z0-9]{8,})',
  caseSensitive: false,
);
final _upiRefBareRe = RegExp(r'\b(\d{12})\b');

String _cleanMerchant(String raw) {
  var name = raw.trim();

  // 1. Handle VPA handles e.g. name@bank
  if (name.contains('@')) {
    final parts = name.split('@');
    final vpaUser = parts[0].trim();
    if (RegExp(r'^paytmqr', caseSensitive: false).hasMatch(vpaUser)) {
      name = 'Paytm Merchant';
    } else if (RegExp(r'^bharatpe', caseSensitive: false).hasMatch(vpaUser)) {
      name = 'BharatPe Merchant';
    } else if (RegExp(r'^(?:gpay|googlepay)', caseSensitive: false).hasMatch(vpaUser)) {
      name = 'Google Pay Merchant';
    } else if (RegExp(r'^phonepe', caseSensitive: false).hasMatch(vpaUser)) {
      name = 'PhonePe Merchant';
    } else {
      final rawHandle = vpaUser.split(RegExp(r'[._\-]')).first;
      final cleanedVpa = rawHandle.replaceAll(RegExp(r'\d+$'), '');
      if (cleanedVpa.length >= 3) {
        name = cleanedVpa[0].toUpperCase() + cleanedVpa.substring(1).toLowerCase();
      } else {
        name = vpaUser;
      }
    }
  }

  // 2. Strip trailing keywords often captured in loose boundary matches
  name = name.replaceAll(
    RegExp(
      r'\s+(?:via|using|on|through|in|UPI|Ref|UTR|Bank|A/c|Account|Pv|Pvt|Ltd|Limited|is|was|successful|successfully)$',
      caseSensitive: false,
    ),
    '',
  );
  // Strip trailing punctuation
  name = name.replaceAll(RegExp(r'[\s.,:;/\-]+$'), '').trim();
  // Filter generic invalid names
  if (RegExp(r'^(?:your|your a/c|your account|account|bank|upi|self|vpa)$', caseSensitive: false).hasMatch(name)) {
    return 'Unknown';
  }
  if (name.isNotEmpty && name == name.toLowerCase()) {
    name = name[0].toUpperCase() + name.substring(1);
  }
  return name.isEmpty ? 'Unknown' : name;
}

// Explicitly reject non-transaction messages: recharge expiry reminders, bill due alerts, OTPs,
// loan promos, payment requests, and failed/declined transactions.
final _nonTransactionRe = RegExp(
  r'\b(?:'
  // 1. Recharge / Plan / Validity ending or reminders
  r'recharge ending|recharge will end|recharge expires|recharge expired|plan expires|plan expiring|'
  r'validity expires|validity expiring|validity ending|pack expires|pack expiring|pack will expire|'
  r'recharge with|recharge now|recharge soon|recharge your|please recharge|plz recharge|'
  r'recharge immediately|to continue services|to enjoy unlimited|plan has expired|'
  // 2. Bill due / Payment due reminders
  r'is due|due date|due on|bill generated|bill due|overdue|payment reminder|reminder:|'
  r'bill of (?:rs|inr|₹)|bill amount of|pay before|pay your bill|outstanding bill|'
  r'outstanding amount|payable amount|amount payable|minimum amount due|total amount due|'
  // 3. OTP & Security verification codes
  r'otp\b|one time password|verification code|security code|secret code|do not share|'
  r'is your code|auth code|use code \d|pin for txn|'
  // 4. Marketing promos & Loan offers
  r'pre-approved|pre approved|loan offer|apply for loan|instant loan|personal loan of|'
  r'win up to|stand a chance to win|congratulations you won|claim your reward|'
  // 5. Payment requests & Collect requests (not completed payments)
  r'requesting payment|requested payment|payment request|has requested|collect request|'
  r'approve request|autopay request|mandate request|request to pay|'
  // 6. Failed & Declined transactions
  r'failed|declined|unsuccessful|cancelled|canceled|could not be processed|timed out|aborted|rejected'
  r')\b',
  caseSensitive: false,
);

/// Parses [text] into a payment, or null if it isn't a payment notification
/// (no amount, or no payment verb — e.g. a casual "send me ₹200" chat).
ParsedUpiPayment? parseUpiNotification(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return null;

  // 0. Explicit rejection of non-transaction messages (recharge alerts, bill due, OTP, promos, requests, failures)
  if (_nonTransactionRe.hasMatch(clean)) return null;

  // 1. Amount extraction
  var amountMatch = _amountRe.firstMatch(clean);
  String? rawAmount = amountMatch?.group(1);
  if (rawAmount == null || rawAmount.isEmpty) {
    rawAmount = _amountTrailingRe.firstMatch(clean)?.group(1);
  }
  if (rawAmount == null || rawAmount.isEmpty) {
    final ctxMatch = _contextualAmountRe.firstMatch(clean);
    rawAmount = ctxMatch?.group(1);
  }
  if (rawAmount == null || rawAmount.isEmpty) return null;

  final amount = parseAmount(rawAmount.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  // 2. Transaction direction (income vs spend)
  final hasReceive = _receiveRe.hasMatch(clean);
  final hasSpend = _spendRe.hasMatch(clean);

  // If text mentions neither verb, it's casual chat or unrelated notification
  if (!hasReceive && !hasSpend) return null;

  // Disambiguation: "debited" / "paid to" / "spent" takes priority over cashback/refund mentions
  // unless only receive keywords are present.
  final isIncome = hasReceive &&
      (!hasSpend ||
          clean.toLowerCase().contains('paid you') ||
          clean.toLowerCase().contains('sent you') ||
          clean.toLowerCase().contains('credited to') ||
          clean.toLowerCase().contains('credited with') ||
          clean.toLowerCase().contains('refund') ||
          clean.toLowerCase().contains('cashback'));

  // 3. Merchant extraction
  String? merchant;
  String? ref;

  // Check for bank narration first: "UPI/DR/123456789012/SWIGGY"
  final bankMatch = _bankNarrationRe.firstMatch(clean);
  if (bankMatch != null) {
    ref = bankMatch.group(1);
    final bankMerchant = bankMatch.group(2);
    if (bankMerchant != null && bankMerchant.isNotEmpty) {
      merchant = _cleanMerchant(bankMerchant);
    }
  }

  if (merchant == null || merchant == 'Unknown') {
    final gpayMatch = _gpayMerchantRe.firstMatch(clean);
    if (gpayMatch != null) {
      final cand = _cleanMerchant(gpayMatch.group(1)!);
      if (cand != 'Unknown') merchant = cand;
    }
  }

  if (merchant == null || merchant == 'Unknown') {
    final recipMatch = _recipientMerchantRe.firstMatch(clean);
    if (recipMatch != null) {
      final cand = _cleanMerchant(recipMatch.group(1)!);
      if (cand != 'Unknown') merchant = cand;
    }
  }

  if (merchant == null || merchant == 'Unknown') {
    final fallbackMatch = _fallbackMerchantRe.firstMatch(clean);
    if (fallbackMatch != null) {
      final cand = _cleanMerchant(fallbackMatch.group(1)!);
      if (cand != 'Unknown') merchant = cand;
    }
  }

  merchant ??= 'Unknown';

  // 4. UPI Ref / UTR extraction
  ref ??= _upiRefRe.firstMatch(clean)?.group(1) ??
      (hasSpend || hasReceive ? _upiRefBareRe.firstMatch(clean)?.group(1) : null);
      
  // 5. Balance extraction (e.g. "Avail Bal: Rs 10000", "Balance is INR 500.00")
  double? balance;
  final balRe = RegExp(r'(?:bal|balance|avl bal|available balance)[^0-9]*?(?:₹|Rs\.?|INR)?\s*([0-9,]+(?:\.[0-9]{1,2})?)', caseSensitive: false);
  final balMatch = balRe.firstMatch(clean);
  if (balMatch != null) {
    final rawBal = balMatch.group(1);
    if (rawBal != null) {
      balance = parseAmount(rawBal.replaceAll(',', ''));
    }
  }

  return ParsedUpiPayment(
    amount: amount,
    merchant: merchant,
    isIncome: isIncome,
    upiRef: ref,
    balance: balance,
  );
}

/// Encodes a raw capture line for the inbox JSONL file.
String encodeInboxLine({required String package, required String text, required String seenAt}) {
  return jsonEncode({'package': package, 'text': text, 'seenAt': seenAt});
}
