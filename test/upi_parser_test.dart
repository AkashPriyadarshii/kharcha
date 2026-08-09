import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/upi_parser.dart';

void main() {
  group('parseUpiNotification', () {
    test('Google Pay debit', () {
      final p = parseUpiNotification('₹450 paid to Swiggy using UPI UPI Ref 123456789012');
      expect(p, isNotNull);
      expect(p!.amount, 450);
      expect(p.merchant, 'Swiggy');
      expect(p.upiRef, '123456789012');
    });

    test('PhonePe debit', () {
      final p = parseUpiNotification('Rs 320.50 debited from a/c at Zomato. UTR 9876543210');
      expect(p, isNotNull);
      expect(p!.amount, 320.5);
      expect(p.merchant, 'Zomato');
      expect(p.upiRef, '9876543210');
    });

    test('money received → captured as income', () {
      final p = parseUpiNotification('₹5000 received from Akash. UPI Ref 123456789012');
      expect(p, isNotNull);
      expect(p!.amount, 5000);
      expect(p.isIncome, isTrue);
      expect(p.upiRef, '123456789012');
    });

    test('no payment keyword → null (casual chat)', () {
      expect(parseUpiNotification('Bhai ₹200 bhej de'), isNull);
    });

    test('bank debit message → captured', () {
      final p = parseUpiNotification('Rs. 2,500.00 debited from A/c XX1234 at Amazon on 09-Aug-26');
      expect(p, isNotNull);
      expect(p!.amount, 2500);
      expect(p.isIncome, isFalse);
      expect(p.merchant, 'Amazon');
    });

    test('no amount → null', () {
      expect(parseUpiNotification('You have a new message from Swiggy'), isNull);
    });

    test('unknown merchant falls back to Unknown', () {
      final p = parseUpiNotification('₹100 debited. UTR 1111111111');
      expect(p, isNotNull);
      expect(p!.merchant, 'Unknown');
      expect(p.upiRef, '1111111111');
    });

    test('GPay money-sent format → captured, merchant parsed', () {
      final p = parseUpiNotification('Money sent · ₹200 · Swiggy · UPI Ref 987654321012');
      expect(p, isNotNull);
      expect(p!.amount, 200);
      expect(p.merchant, 'Swiggy');
      expect(p.upiRef, '987654321012');
    });
  });

  group('encodeInboxLine', () {
    test('writes JSONL that jsonDecode can read back', () {
      final line = encodeInboxLine(package: 'com.phonepe.app', text: '₹450 paid', seenAt: 't');
      final map = jsonDecode(line) as Map<String, dynamic>;
      expect(map['package'], 'com.phonepe.app');
      expect(map['text'], '₹450 paid');
    });
  });
}
