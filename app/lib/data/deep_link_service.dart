/// Delivers incoming `com.stubapp.stub://...` deep links (see
/// `util/deep_link.dart` for what's actually parsed out of them) —
/// currently only the Siri Shortcuts quick-log feature uses this, but the
/// interface is generic over any incoming link, matching
/// `supabase_flutter`'s own separate internal listener for its
/// `login-callback` auth link (both listen independently; each only acts
/// on the path it recognizes).
abstract class DeepLinkService {
  /// The link that cold-launched the app, if any — checked once at
  /// startup. Null if the app wasn't launched via a link.
  Future<Uri?> getInitialLink();

  /// Links received while the app is already running (warm).
  Stream<Uri> get onLink;
}
