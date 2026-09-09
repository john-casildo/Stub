import 'package:app_links/app_links.dart';

import 'deep_link_service.dart';

/// Real `DeepLinkService` via the `app_links` package (v7.2.1). No
/// automated test — needs a real platform channel, same story as
/// `MlKitTextRecognitionService`/`LocalAuthDeviceAuthService`/
/// `LocalNotificationsService` elsewhere in this app; verify manually.
class AppLinksDeepLinkService implements DeepLinkService {
  final _appLinks = AppLinks();

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get onLink => _appLinks.uriLinkStream;
}
