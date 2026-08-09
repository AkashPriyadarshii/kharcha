import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/update_checker.dart';

void main() {
  group('compareVersions', () {
    test('newer minor is newer', () {
      expect(compareVersions('0.2.3', '0.2.2'), isTrue);
    });
    test('same version is not newer', () {
      expect(compareVersions('0.2.2', '0.2.2'), isFalse);
    });
    test('older is not newer', () {
      expect(compareVersions('0.2.1', '0.2.2'), isFalse);
    });
    test('10 beats 9 numerically', () {
      expect(compareVersions('0.2.10', '0.2.9'), isTrue);
    });
    test('leading v is stripped', () {
      expect(compareVersions('v0.3.0', '0.2.9'), isTrue);
    });
    test('pre-release suffix strips to core', () {
      expect(compareVersions('0.3.0-beta', '0.3.0'), isFalse);
    });
    test('empty/missing parts default to 0', () {
      expect(compareVersions('0.3', '0.2.9'), isTrue);
    });
  });
}
