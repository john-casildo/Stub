/// Local (on-device, non-push) notifications — used for real-time budget
/// threshold alerts (see `util/budget_thresholds.dart`); the future
/// weekly-summary feature will reuse this same interface.
abstract class NotificationService {
  /// Requests the OS notification permission. Returns whether it was
  /// granted — callers should only call this once the user has opted in
  /// via a toggle, not unconditionally at app startup.
  Future<bool> requestPermission();

  Future<void> show({required String title, required String body});
}
