import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/bill_splitter.dart';

void main() {
  test('splits evenly', () {
    expect(splitBillPaisa(3000, 3), [1000, 1000, 1000]);
  });

  test('remainder spread one paisa to first people', () {
    expect(splitBillPaisa(100, 3), [34, 33, 33]); // sums to 100
    expect(splitBillPaisa(1, 2), [1, 0]);
  });

  test('parts always sum exactly to total', () {
    for (final (total, count) in [(12345, 7), (999, 2), (5000, 1), (1, 20)]) {
      expect(splitBillPaisa(total, count).reduce((a, b) => a + b), total);
    }
  });
}
