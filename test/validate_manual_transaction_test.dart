import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/data/transaction_repository.dart';

void main() {
  const valid = (amount: 100.0, merchant: 'Zomato', paymentMethod: 'upi');

  group('validateManualTransaction', () {
    test('valid input returns null', () {
      expect(validateManualTransaction(amount: valid.amount, merchant: valid.merchant, paymentMethod: valid.paymentMethod), isNull);
    });

    test('zero and negative amounts rejected', () {
      expect(validateManualTransaction(amount: 0, merchant: valid.merchant, paymentMethod: valid.paymentMethod), isNotNull);
      expect(validateManualTransaction(amount: -5, merchant: valid.merchant, paymentMethod: valid.paymentMethod), isNotNull);
    });

    test('blank merchant rejected', () {
      expect(validateManualTransaction(amount: valid.amount, merchant: '  ', paymentMethod: valid.paymentMethod), isNotNull);
    });

    test('unknown payment method rejected', () {
      expect(validateManualTransaction(amount: valid.amount, merchant: valid.merchant, paymentMethod: 'cheque'), isNotNull);
    });

    test('all known payment methods accepted', () {
      for (final m in TransactionRepository.paymentMethods) {
        expect(validateManualTransaction(amount: valid.amount, merchant: valid.merchant, paymentMethod: m), isNull, reason: m);
      }
    });
  });
}
