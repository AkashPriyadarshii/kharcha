import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/screens/onboarding_screen.dart';

void main() {
  group('OnboardingStore', () {
    late Directory dir;
    late OnboardingStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('onboarding_test');
      store = OnboardingStore(File('${dir.path}/onboarding.json'));
    });

    tearDown(() async {
      await dir.delete(recursive: true);
    });

    test('missing file → not done', () async {
      expect(await store.isDone(), isFalse);
    });

    test('markDone → done', () async {
      await store.markDone();
      expect(await store.isDone(), isTrue);
    });

    test('false content → not done', () async {
      await store.file.writeAsString('false');
      expect(await store.isDone(), isFalse);
    });

    test('corrupt file → not done (no crash)', () async {
      await store.file.writeAsString('not json');
      expect(await store.isDone(), isFalse);
    });
  });
}
