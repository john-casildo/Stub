import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

/// Real `NotificationService` via `flutter_local_notifications`. No
/// automated test — needs a real platform channel, same story as
/// `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`; verify
/// manually on a real device.
class LocalNotificationsService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  int _nextId = 0;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  @override
  Future<bool> requestPermission() async {
    await _ensureInitialized();
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      return await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      return await androidImpl.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  @override
  Future<void> show({required String title, required String body}) async {
    await _ensureInitialized();
    const androidDetails = AndroidNotificationDetails(
      'budget_alerts',
      'Budget alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _plugin.show(
      id: _nextId++,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
