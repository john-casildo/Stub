enum BackendMode { supabase, customServer }

/// Single switch point between the two backend implementations — see
/// `docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`.
/// Flip `mode` back to `BackendMode.supabase` to fully revert to the
/// original Supabase-backed app; nothing else needs to change.
class BackendConfig {
  /// Defaults to `localhost`, which works for the iOS Simulator (it shares
  /// the host Mac's network) but NOT for a physical device — a phone can't
  /// reach your Mac's `localhost`. For a physical device, pass your
  /// machine's LAN IP at build/run time instead of editing this file:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.23:3000
  ///
  /// Find your LAN IP with `ipconfig getifaddr en0` (Wi-Fi) on macOS. This
  /// keeps the committed default portable across machines/networks.
  static const String baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');

  static const BackendMode mode = BackendMode.customServer;
}
