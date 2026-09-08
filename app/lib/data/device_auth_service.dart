/// Gates access to the app behind the device's own biometric/passcode
/// lock, via the `local_auth` package. Kept as an interface (like
/// [AccountLinkService]/[TextRecognitionService]) so [LockScreen] and the
/// app's lock/re-lock lifecycle stay unit-testable without a real device.
abstract class DeviceAuthService {
  /// Whether this device has any biometric or passcode/PIN enrolled at
  /// all. When false, there's nothing to authenticate against — the app
  /// should not gate on it.
  Future<bool> isSupported();

  /// Prompts the OS's own biometric-or-passcode UI. Returns whether the
  /// user successfully authenticated.
  Future<bool> authenticate();
}
