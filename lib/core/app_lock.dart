import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';

/// Persists the app-lock enabled flag. Plain JSON file in app documents —
/// the flag is a UX gate, not encryption; the real protection is the OS
/// biometric prompt.
class AppLockStore {
  AppLockStore(this.file);

  final File file;

  static Future<AppLockStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    return AppLockStore(File('${dir.path}/app_lock.json'));
  }

  Future<bool> load() async {
    try {
      if (!await file.exists()) return false;
      return jsonDecode(await file.readAsString()) == true;
    } catch (_) {
      return false; // missing/corrupt → unlocked.
    }
  }

  Future<void> save(bool enabled) =>
      file.writeAsString(jsonEncode(enabled), flush: true);
}

/// Biometric/PIN gate for the app. Fallback PIN stored in memory only.
///
/// ponytail: real PIN fallback needs secure storage (flutter_secure_storage)
/// — add when the biometric-only path is deemed insufficient.
class AppLock {
  AppLock(this._auth);

  final LocalAuthentication _auth;

  /// True when the device can authenticate (biometrics OR device credential —
  /// a PIN/pattern counts, so PIN-only phones aren't locked out).
  Future<bool> canAuthenticate() => _auth.isDeviceSupported();

  /// Shows the OS auth prompt. Returns true when the user passed.
  Future<bool> authenticate({String reason = 'Kharcha is locked'}) async {
    return _auth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: false,
        useErrorDialogs: true,
        stickyAuth: true,
      ),
    );
  }
}

/// Whether app lock is enabled, plus enabling/unlocking it.
final appLockControllerProvider =
    StateNotifierProvider<AppLockController, bool>((ref) => AppLockController());

class AppLockController extends StateNotifier<bool> {
  AppLockController({AppLockStore? store, AppLock? lock})
      : _store = store,
        _lock = lock,
        super(false);

  final AppLockStore? _store;
  final AppLock? _lock;

  Future<AppLockStore> get _stores async => _store ?? await AppLockStore.create();
  AppLock get _locks => _lock ?? AppLock(LocalAuthentication());

  /// Loads the persisted flag. Safe to call once at startup.
  Future<void> load() async => state = await (await _stores).load();

  /// Turns the lock on only after the user passes the OS prompt (so enabling
  /// is never accidental); turns it off instantly. Returns false when the
  /// device has no biometrics/PIN or the user cancelled.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      if (!await _locks.canAuthenticate()) return false;
      final ok = await _locks.authenticate(reason: 'Turn on app lock');
      if (!ok) return false;
    }
    state = enabled;
    await (await _stores).save(enabled);
    return true;
  }

  /// Opens the app: prompts the user. Devices without biometrics/PIN are not
  /// trapped — no prompt, treated as unlocked.
  Future<bool> unlock() async {
    if (!await _locks.canAuthenticate()) return true;
    return _locks.authenticate();
  }
}
