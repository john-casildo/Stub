enum BackendMode { supabase, customServer }

/// Single switch point between the two backend implementations — see
/// `docs/superpowers/specs/2026-09-09-custom-backend-migration-design.md`.
/// Flip `mode` back to `BackendMode.supabase` to fully revert to the
/// original Supabase-backed app; nothing else needs to change.
class BackendConfig {
  /// Update this to your machine's LAN IP (not `localhost`) when testing
  /// on a physical device — the phone can't reach your Mac's `localhost`.
  /// Find it with `ipconfig getifaddr en0` (Wi-Fi) on macOS.
  static const String baseUrl = 'http://localhost:3000';

  static const BackendMode mode = BackendMode.customServer;
}
