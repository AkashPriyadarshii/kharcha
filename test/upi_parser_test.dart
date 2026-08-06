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

    test('money received → null (no capture of income)', () {
      expect(parseUpiNotification('₹5000 received from Akash. UPI Ref 123456789012'), isNull);
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
