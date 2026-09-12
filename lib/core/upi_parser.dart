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
    this.accountMask,
    this.bankName,
    this.needsReview = false,
  });

  final double amount;
  final String merchant;

  /// True when money came IN (received/credited). False for spending.
  final bool isIncome;
  final String? upiRef;
  
  /// The true bank balance extracted from the message (if available).
  final double? balance;

  final String? accountMask;
  final String? bankName;
  final bool needsReview;
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
  r'\b(?:received|credited|added to your|added in your|added to|refund|refunded|cashback|paid you|sent you|(?:sent|paid|transferred|given|credited).{0,20}to you|deposited|credited with|money received|inward)\b',
  caseSensitive: false,
);

// UPI/DR or UPI/CR bank narration format: e.g. "Info: UPI/DR/123456789012/SWIGGY/HDFC"
final _bankNarrationRe = RegExp(
  r'UPI\/(?:DR|CR|P2A|P2M|P2P|REV)\/(\d+)\/([A-Za-z0-9 &.\-_]+)',
  caseSensitive: false,
);

// GPay bullet format: "Money sent · ₹200 · Swiggy"
final _gpayMerchantRe = RegExp(
  r'·\s*([A-Za-z0-9][A-Za-z0-9 &.\-]{1,60}?)(?=\s*·|\s+UPI|\s+Ref|$)',
  caseSensitive: false,
);

// High-priority explicit recipient: "to X", "paid to X", "at X", "done at X"
final _recipientMerchantRe = RegExp(
  r'(?:spent on .*? at|(?:paid|payment|transferred|sent)\s+(?:(?:₹|rs\.?|inr)\s*[0-9,.]+\s+)?(?:to|at|on)|paid to|transferred to|sent to|payment to|sent .{0,12}to|done at|\bto\b|\bat\b)\s+'
  r'(?!(?:you|rs\.?|inr|₹|\d)\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|at\s+\d|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))',
  caseSensitive: false,
);

// Fallback purpose/source: "from X", "towards X", "for X", "debited from X"
final _fallbackMerchantRe = RegExp(
  r'(?:from|towards|for|debited (?:at|from))\s+'
  r'(?!(?:you|rs\.?|inr|₹|\d)\b)([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)(?=,|\.|$|:|\s+(?:of\s*(?:₹|Rs\.?|INR|\d)|upi|ref|utr|trans|txn|bal|balance|on\s+\d|on\s+[A-Za-z]|at\s+\d|via|bank|a/c|by|from|using|credited|debited|successful|is\s+successful|was\s+successful))',
  caseSensitive: false,
);

// UPI reference / UTR regexes
final _upiRefRe = RegExp(
  r'(?:upi\s*ref(?:erence)?(?:\s*no)?|\bupi\b|utr(?:\s*no)?|ref(?:erence)?\s*id|ref\s*id|ref(?:\s*no)?|trans(?:action)?\s*id|txn\s*id)\s*[:#-]?\s*([A-Za-z0-9]{8,})',
  caseSensitive: false,
);
final _upiRefBareRe = RegExp(r'\b(\d{12})\b');

final _accountMaskRe = RegExp(r'(?:a/c|acct|account)(?:\s*no\.?|\s*number)?(?:\s*ending\s*(?:in|with))?\s*(?:x|X|\*)*(\d{3,18})\b', caseSensitive: false);
final _bankNameRe = RegExp(r'\b(SBI|HDFC|ICICI|Axis|Kotak|PNB|BOB|IDFC|IndusInd|Yes Bank|Canara|Union Bank|Indian Bank|State Bank of India|Bank of Baroda|Paytm Payments Bank|Airtel Payments Bank|Jio Payments Bank|Federal Bank|South Indian Bank)\b', caseSensitive: false);

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
  if (RegExp(r'^(?:your|your a/c|your account|account|bank|upi|self|vpa|cashback|\d+|rs\.?.*|inr.*)$', caseSensitive: false).hasMatch(name)) {
    return 'Unknown';
  }
  if (name.isNotEmpty && name == name.toLowerCase()) {
    name = name[0].toUpperCase() + name.substring(1);
  }
  return name.isEmpty ? 'Unknown' : name;
}

// Explicitly reject non-transaction messages: recharge confirmations/promos, bill due alerts, OTPs,
// loan/financial spam, payment requests, and failed/declined/pending transactions.
final _nonTransactionRe = RegExp(
  r'\b(?:'
  // 1. Telecom Recharge: confirmations, promos, plans, validity, data packs
  r'recharge (?:of|for|plan|pack|offer|done|successful|processed|is|credited|with|now|soon|your|immediately)|'
  r'recharge.*(?:successful|done|processed|validity|number|mobile|prepaid)|'
  r'successful recharge|recharge successful|recharge done|'
  r'recharge ending|recharge will end|recharge expires|recharge expired|plan expires|plan expiring|'
  r'validity expires|validity expiring|validity ending|pack expires|pack expiring|pack will expire|'
  r'please recharge|plz recharge|to continue services|to enjoy unlimited|plan has expired|'
  r'data pack|daily data|talktime|unlimited 5g|prepaid account|'
  r'for your (?:jio|airtel|vi|vodafone|idea|bsnl) (?:number|mobile)|'
  r'on (?:your )?(?:jio|airtel|vi|vodafone|idea|bsnl) (?:number|mobile)|'
  r'(?:jio|airtel|vi|bsnl) prepaid|'
  r'benefits:\s*\d|'
  // 2. Bill due / Payment due reminders / Statements
  r'is due|due date|due on|bill generated|bill due|overdue|payment reminder|reminder:|'
  r'bill of (?:rs|inr|₹)|bill amount of|pay before|pay your bill|outstanding bill|'
  r'outstanding amount|payable amount|amount payable|minimum amount due|total amount due|'
  r'statement for|statement generated|e-statement|'
  // 3. OTP & Security verification codes
  r'otp\b|one time password|verification code|security code|secret code|do not share|'
  r'is your code|auth code|use code \d|pin for txn|'
  // 4. Marketing promos, Loan offers, Lottery, Referral & Investment spam
  r'pre-approved|pre approved|loan offer|apply for loan|instant loan|personal loan of|personal loan|'
  r'credit limit of|approved loan|get a loan|quick cash|instant cash|'
  r'win up to|stand a chance to win|congratulations you won|congratulations!|congratulations\b|claim your reward|'
  r'flat off|supercoins|free delivery|shop for|save extra|enjoy flat|use code|'
  r'scratch card|refer and earn|invite and earn|voucher of (?:rs|inr|₹)|'
  r'invest in|invest rs|start investing|trade now|'
  // 5. Payment requests & Collect requests & Pending/Initiated (not completed payments)
  r'requesting payment|requested payment|payment request|has requested|collect request|'
  r'approve request|autopay request|mandate request|request to pay|request of (?:rs|inr|₹)|'
  r'requested\b|standing instruction|mandate created|autopay scheduled|'
  r'\bpending\b|\binitiated\b|in progress|processing payment|\bprocessing\b|scheduled for|'
  r'will be debited|will be credited|'
  // 6. Failed & Declined transactions
  r'failed|declined|unsuccessful|cancelled|canceled|could not be processed|timed out|aborted|rejected'
  r')\b',
  caseSensitive: false,
);

/// True if [text] is a non-transaction message (recharge alert, bill due, promo, request, or failure).
bool isNonTransaction(String text) => _nonTransactionRe.hasMatch(text.trim());

/// Parses [text] into a payment, or null if it isn't a payment notification
/// (no amount, or no payment verb — e.g. a casual "send me ₹200" chat).
ParsedUpiPayment? parseUpiNotification(String text) {
  final clean = text.trim();
  if (clean.isEmpty) return null;

  // 0. Explicit rejection of non-transaction messages (recharge alerts, bill due, OTP, promos, requests, failures)
  if (_nonTransactionRe.hasMatch(clean)) return null;

  // 1. Amount extraction
  bool usedContextualAmount = false;
  final balancePrefixRe = RegExp(
    r'\b(?:bal|balance|avl\s*bal|available\s*(?:bal|balance)|limit|credit\s*limit)[\s:=-]*$',
    caseSensitive: false,
  );

  final allAmountMatches = _amountRe.allMatches(clean);
  Match? amountMatch;
  for (final m in allAmountMatches) {
    final prefix = clean.substring(0, m.start);
    if (!balancePrefixRe.hasMatch(prefix)) {
      amountMatch = m;
      break;
    }
  }
  amountMatch ??= allAmountMatches.firstOrNull;

  String? rawAmount = amountMatch?.group(1);
  if (rawAmount == null || rawAmount.isEmpty) {
    final allTrailing = _amountTrailingRe.allMatches(clean);
    for (final m in allTrailing) {
      final prefix = clean.substring(0, m.start);
      if (!balancePrefixRe.hasMatch(prefix)) {
        rawAmount = m.group(1);
        break;
      }
    }
    rawAmount ??= allTrailing.firstOrNull?.group(1);
  }
  if (rawAmount == null || rawAmount.isEmpty) {
    final ctxMatch = _contextualAmountRe.firstMatch(clean);
    rawAmount = ctxMatch?.group(1);
    if (rawAmount != null && rawAmount.isNotEmpty) {
      usedContextualAmount = true;
    }
  }
  if (rawAmount == null || rawAmount.isEmpty) return null;

  final amount = parseAmount(rawAmount.replaceAll(',', ''));
  if (amount == null || amount <= 0) return null;

  // 2. Transaction direction (income vs spend)
  final hasReceive = _receiveRe.hasMatch(clean);
  final hasSpend = _spendRe.hasMatch(clean);

  // If text mentions neither verb, it's casual chat or unrelated notification
  if (!hasReceive && !hasSpend) return null;

  // Disambiguation: determine whether money came IN to the user vs spent.
  // "debited" / "paid to" / "spent" takes priority over cashback/refund mentions unless explicitly incoming.
  final isIncome = hasReceive &&
      (!hasSpend ||
          clean.toLowerCase().contains('paid you') ||
          clean.toLowerCase().contains('sent you') ||
          RegExp(r'(?:sent|paid|transferred|given|credited).{0,20}to you', caseSensitive: false).hasMatch(clean) ||
          RegExp(r'(?:credited|deposited|added)\s+(?:to|in|into)\s+(?:your\s+)?(?:a\/c|acct|account|wallet|balance)', caseSensitive: false).hasMatch(clean) ||
          clean.toLowerCase().contains('credited with') ||
          clean.toLowerCase().contains('refund') ||
          RegExp(r'(?:payment|amount|money|\b)\s*received\s+(?:(?:(?:rs\.?|inr|₹)\s*[0-9,.]+|[0-9,.]+)\s+)?from\b', caseSensitive: false).hasMatch(clean) ||
          (clean.toLowerCase().contains('received') &&
              !RegExp(r'received\s+(?:by|for|towards|at)\b', caseSensitive: false).hasMatch(clean) &&
              !clean.toLowerCase().contains('debited') &&
              !clean.toLowerCase().contains('spent') &&
              !clean.toLowerCase().contains('paid to')));

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

  bool usedFallbackMerchant = false;
  if (merchant == null || merchant == 'Unknown') {
    final fallbackMatch = _fallbackMerchantRe.firstMatch(clean);
    if (fallbackMatch != null) {
      final cand = _cleanMerchant(fallbackMatch.group(1)!);
      if (cand != 'Unknown') {
        merchant = cand;
        usedFallbackMerchant = true;
      }
    }
  }

  if (merchant == null || merchant == 'Unknown') {
    if (isIncome) {
      final senderRe = RegExp(r'^([A-Za-z0-9][A-Za-z0-9 &.\-@]{1,60}?)\s+(?:sent|paid|transferred|given|credited)', caseSensitive: false);
      final senderMatch = senderRe.firstMatch(clean);
      if (senderMatch != null) {
        final cand = _cleanMerchant(senderMatch.group(1)!);
        if (cand.toLowerCase() != 'you' && cand.toLowerCase() != 'i') {
          merchant = cand;
        }
      }
    }
  }
  merchant ??= 'Unknown';

  // 4. UPI Ref / UTR extraction
  ref ??= _upiRefRe.firstMatch(clean)?.group(1);
  if (ref == null && (hasSpend || hasReceive)) {
    for (final m in _upiRefBareRe.allMatches(clean)) {
      final cand = m.group(1)!;
      final prefix = clean.substring(0, m.start);
      // Exclude 12-digit numbers preceded by account/card identifiers
      if (RegExp(r'(?:a/c|acct|account|card)(?:\s*no\.?|\s*number)?(?:\s*ending\s*(?:in|with))?\s*(?:x|X|\*)*\s*$', caseSensitive: false).hasMatch(prefix)) {
        continue;
      }
      ref = cand;
      break;
    }
  }
      
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

  // 6. Account mask and Bank name
  final maskMatch = _accountMaskRe.firstMatch(clean);
  final accountMask = maskMatch?.group(1);

  final bankMatch2 = _bankNameRe.firstMatch(clean);
  final bankName = bankMatch2?.group(1);

  final needsReview = usedContextualAmount || usedFallbackMerchant;

  return ParsedUpiPayment(
    amount: amount,
    merchant: merchant,
    isIncome: isIncome,
    upiRef: ref,
    balance: balance,
    accountMask: accountMask,
    bankName: bankName,
    needsReview: needsReview,
  );
}

/// Encodes a raw capture line for the inbox JSONL file.
String encodeInboxLine({required String package, required String text, required String seenAt}) {
  return jsonEncode({'package': package, 'text': text, 'seenAt': seenAt});
}


