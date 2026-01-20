import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Returns true if the device supports biometrics and at least one biometric is enrolled.
  Future<bool> canCheckBiometricsAndEnrolled() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Attempts authentication using biometrics. Returns true on success.
  Future<bool> authenticate({String reason = 'Authenticate to unlock'}) async {
    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
        ),
      );
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }
}
