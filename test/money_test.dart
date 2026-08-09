import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/money.dart';

void main() {
  test('rounds to 2dp killing float drift', () {
    expect(parseAmount('0.1')!, 0.1);
    expect(parseAmount('0.2')!, 0.2);
    expect(parseAmount('2.345')!, 2.35); // round half up at the boundary
    expect(parseAmount('1.999')!, 2.0);
    expect(parseAmount('0.1')! + parseAmount('0.2')!, closeTo(0.3, 1e-12));
  });

  test('accepts whole/space-padded amounts, rejects garbage', () {
    expect(parseAmount('  ₹1200 '), null); // symbol not expected — screens strip it
    expect(parseAmount('1200')!, 1200.0);
    expect(parseAmount('0')!, 0.0);
    expect(parseAmount(''), null);
    expect(parseAmount(null), null);
    expect(parseAmount('abc'), null);
    expect(parseAmount('-5'), null);
  });
}
