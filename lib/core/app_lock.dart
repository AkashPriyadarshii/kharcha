import 'package:local_auth/local_auth.dart';

/// Biometric/PIN gate for the app. Fallback PIN stored in memory only.
///
/// ponytail: real PIN fallback needs secure storage (flutter_secure_storage)
/// — add when the biometric-only path is deemed insufficient.
class AppLock {
  AppLock(this._auth);

  final LocalAuthentication _auth;

  /// True when the device can authenticate (has enrolled biometrics / PIN).
  Future<bool> canAuthenticate() => _auth.canCheckBiometrics;

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
