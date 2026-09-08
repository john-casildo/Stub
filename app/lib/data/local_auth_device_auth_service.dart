import 'package:local_auth/local_auth.dart';
import 'device_auth_service.dart';

/// Real [DeviceAuthService] via the `local_auth` package. Not unit-tested
/// (like [MlKitTextRecognitionService] — this needs a real platform
/// channel/device), exercised only by manual verification.
class LocalAuthDeviceAuthService implements DeviceAuthService {
  final _localAuth = LocalAuthentication();

  @override
  Future<bool> isSupported() => _localAuth.isDeviceSupported();

  @override
  Future<bool> authenticate() => _localAuth.authenticate(
        localizedReason: 'Unlock Stub',
        biometricOnly: false,
      );
}
