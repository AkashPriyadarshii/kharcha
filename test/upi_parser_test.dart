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

    test('"paid you" / "sent you" → income, not spend', () {
      final paid = parseUpiNotification('Akash paid you ₹500 via UPI');
      expect(paid, isNotNull);
      expect(paid!.amount, 500);
      expect(paid.isIncome, isTrue);

      final sent = parseUpiNotification('Priya sent you ₹250');
      expect(sent, isNotNull);
      expect(sent!.amount, 250);
      expect(sent.isIncome, isTrue);
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

    test('PhonePe payment to merchant with trans ID', () {
      final p = parseUpiNotification('Payment to Swiggy of ₹350.00 was successful. Trans ID: T240823123456');
      expect(p, isNotNull);
      expect(p!.amount, 350);
      expect(p.merchant, 'Swiggy');
      expect(p.upiRef, 'T240823123456');
    });

    test('Bank narration UPI/DR format', () {
      final p = parseUpiNotification('A/c *5678 debited for Rs. 1,450.00 on 23-08-2026. Info: UPI/DR/423523523523/AMAZON/Axis Bank');
      expect(p, isNotNull);
      expect(p!.amount, 1450);
      expect(p.merchant, 'AMAZON');
      expect(p.upiRef, '423523523523');
    });

    test('CRED payment at merchant', () {
      final p = parseUpiNotification('Paid ₹1,200 at Starbucks using CRED UPI. Ref 123456789012');
      expect(p, isNotNull);
      expect(p!.amount, 1200);
      expect(p.merchant, 'Starbucks');
      expect(p.upiRef, '123456789012');
    });

    test('Cashback credited as income', () {
      final p = parseUpiNotification('Cashback of ₹50 credited to your account. Ref 999988887777');
      expect(p, isNotNull);
      expect(p!.amount, 50);
      expect(p.isIncome, isTrue);
    });

    test('Cleans raw Paytm QR and VPA handles to friendly merchant name', () {
      final p = parseUpiNotification('Paid ₹150 to paytmqr281001@paytm using UPI. Ref 111122223333');
      expect(p, isNotNull);
      expect(p!.amount, 150);
      expect(p.merchant, 'Paytm Merchant');

      final p2 = parseUpiNotification('Paid ₹500 to swiggy.orders@icici. Ref 222233334444');
      expect(p2, isNotNull);
      expect(p2!.merchant, 'Swiggy');
    });

    test('Lakh Indian numbering format amount', () {
      final p = parseUpiNotification('INR 1,25,000.00 debited for Rent to Landlord');
      expect(p, isNotNull);
      expect(p!.amount, 125000);
      expect(p.merchant, 'Landlord');
    });

    test('HDFC Bank SMS format with balance', () {
      final p = parseUpiNotification('Dear Customer, INR 340.00 debited from A/C **1234 on 23-AUG-26 to ZOMATO UPI:623829102812. Bal: INR 12,400.00');
      expect(p, isNotNull);
      expect(p!.amount, 340);
      expect(p.merchant, 'ZOMATO');
      expect(p.isIncome, isFalse);
    });

    test('SBI Bank SMS transfer format', () {
      final p = parseUpiNotification('Your A/C ending 4321 debited by Rs 150.00 on 23Aug26 transfer to Chai Point Ref No 892019283019');
      expect(p, isNotNull);
      expect(p!.amount, 150);
      expect(p.merchant, 'Chai Point');
      expect(p.upiRef, '892019283019');
    });

    test('Axis Bank credit card spend SMS', () {
      final p = parseUpiNotification('Axis Bank: INR 750.00 spent on your Credit Card XX9900 at PVR CINEMAS on 23-Aug-26');
      expect(p, isNotNull);
      expect(p!.amount, 750);
      expect(p.merchant, 'PVR CINEMAS');
      expect(p.isIncome, isFalse);
    });

    test('BHIM UPI with BharatPe VPA handle', () {
      final p = parseUpiNotification('Paid Rs. 85.00 to bharatpe9102912@icici via BHIM. Ref No: 910291029102');
      expect(p, isNotNull);
      expect(p!.amount, 85);
      expect(p.merchant, 'BharatPe Merchant');
      expect(p.upiRef, '910291029102');
    });

    test('Refund credited from merchant', () {
      final p = parseUpiNotification('INR 899.00 refunded to your A/c XX1234 from Amazon. UPI Ref: 102938475610');
      expect(p, isNotNull);
      expect(p!.amount, 899);
      expect(p.isIncome, isTrue);
      expect(p.merchant, 'Amazon');
      expect(p.upiRef, '102938475610');
    });

    test('Rejects recharge expiry and validity ending prompts', () {
      expect(parseUpiNotification('Ur recharge is ending or will end plz recharge with 196rs'), isNull);
      expect(parseUpiNotification('Dear Customer, your Jio pack of Rs 239 will expire on 25-Aug. Recharge now with Rs 239 to continue services.'), isNull);
      expect(parseUpiNotification('Your Airtel plan expires tomorrow. Please recharge with Rs 199 to enjoy unlimited calls.'), isNull);
      expect(parseUpiNotification('Your Vi pack validity ending today. Plz recharge with 299 immediately.'), isNull);
    });

    test('Rejects bill due reminders and overdue alerts', () {
      expect(parseUpiNotification('Reminder: Electricity bill of Rs 1,450 is due on 30-Aug. Pay now to avoid disconnection.'), isNull);
      expect(parseUpiNotification('Your Credit Card bill of INR 12,500.00 is generated. Due date: 15-SEP-26.'), isNull);
      expect(parseUpiNotification('Payment reminder: Rs 599 is due for your broadband account.'), isNull);
    });

    test('Rejects OTP and security verification codes', () {
      expect(parseUpiNotification('OTP for transaction of INR 450.00 at Zomato is 928301. Do not share OTP with anyone.'), isNull);
      expect(parseUpiNotification('Your verification code for payment of Rs 1,000 is 445566.'), isNull);
    });

    test('Rejects pre-approved loan promos and marketing offers', () {
      expect(parseUpiNotification('Congratulations! You are eligible for pre-approved loan of Rs 5,00,000. Apply now.'), isNull);
      expect(parseUpiNotification('Avail instant personal loan of Rs. 1,00,000 in 2 minutes.'), isNull);
    });

    test('Rejects payment requests and collect requests', () {
      expect(parseUpiNotification('Swiggy is requesting payment of Rs 350 via UPI. Approve in GPay.'), isNull);
      expect(parseUpiNotification('Collect request of Rs 500 received from rahul@upi.'), isNull);
    });

    test('Rejects failed and declined transactions', () {
      expect(parseUpiNotification('Payment of Rs 500 to Uber failed due to bank server issue.'), isNull);
      expect(parseUpiNotification('Transaction of Rs 1,200 at Swiggy was declined due to insufficient funds.'), isNull);
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
  test('Parses generic incoming transfer message', () {
    final parsed = parseUpiNotification('papa sent Rs 2400 to you');
    expect(parsed, isNotNull);
    expect(parsed!.amount, 2400.0);
    expect(parsed.isIncome, true);
    expect(parsed.merchant, 'Papa');
  });

  test('Parses generic incoming paid to message', () {
    final parsed = parseUpiNotification('friend paid 500 to you');
    expect(parsed, isNotNull);
    expect(parsed!.amount, 500.0);
    expect(parsed.isIncome, true);
  });
}
