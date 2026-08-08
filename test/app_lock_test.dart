import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kharcha/core/app_lock.dart';
import 'package:local_auth/local_auth.dart';

class _FakeAuth extends LocalAuthentication {}

class _FakeLock extends AppLock {
  _FakeLock({this.can = true, this.pass = true}) : super(_FakeAuth());

  final bool can;
  final bool pass;
  int prompts = 0;

  @override
  Future<bool> canAuthenticate() async => can;

  @override
  Future<bool> authenticate({String reason = 'Kharcha is locked'}) async {
    prompts++;
    return pass;
  }
}

void main() {
  late Directory dir;
  late File storeFile;
  late AppLockStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('app_lock_test');
    storeFile = File('${dir.path}/app_lock.json');
    store = AppLockStore(storeFile);
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('starts unlocked when no file exists', () async {
    final controller = AppLockController(store: store, lock: _FakeLock());
    await controller.load();
    expect(controller.state, isFalse);
  });

  test('setEnabled(false) stores and unlocks', () async {
    final controller = AppLockController(store: store, lock: _FakeLock());
    await controller.setEnabled(false);
    expect(controller.state, isFalse);
    expect(store.load(), completion(isFalse));
  });

  test('enabling prompts once then persists', () async {
    final lock = _FakeLock();
    final controller = AppLockController(store: store, lock: lock);
    await controller.load();

    final ok = await controller.setEnabled(true);

    expect(ok, isTrue);
    expect(controller.state, isTrue);
    expect(lock.prompts, 1);
    expect(store.load(), completion(isTrue));

    // A fresh controller reads the persisted flag.
    final fresh = AppLockController(store: store, lock: lock);
    await fresh.load();
    expect(fresh.state, isTrue);
  });

  test('enabling does not turn on when user cancels prompt', () async {
    final lock = _FakeLock(pass: false);
    final controller = AppLockController(store: store, lock: lock);

    final ok = await controller.setEnabled(true);

    expect(ok, isFalse);
    expect(controller.state, isFalse);
    expect(store.load(), completion(isFalse));
  });

  test('enabling requires device capability', () async {
    final lock = _FakeLock(can: false);
    final controller = AppLockController(store: store, lock: lock);

    final ok = await controller.setEnabled(true);

    expect(ok, isFalse);
    expect(lock.prompts, 0);
    expect(controller.state, isFalse);
  });

  test('unlock prompts when enabled and device supports it', () async {
    final lock = _FakeLock();
    final controller = AppLockController(store: store, lock: lock);
    await controller.setEnabled(true);

    final before = lock.prompts; // one prompt already fired to enable.
    expect(await controller.unlock(), isTrue);
    expect(lock.prompts, before + 1);
  });

  test('unlock does not trap devices without capability', () async {
    final lock = _FakeLock(can: false);
    final controller = AppLockController(store: store, lock: lock);

    expect(await controller.unlock(), isTrue);
    expect(lock.prompts, 0);
  });
}
