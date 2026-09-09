import 'package:shared_preferences/shared_preferences.dart';

/// Persists the device's JWT for the custom Node backend — the equivalent
/// role Supabase's own session persistence plays for `SupabaseAccountLinkService`.
class LocalAuthTokenStore {
  static const _key = 'custom_backend_jwt';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  /// Drops a token the server has rejected (401), so the next call falls
  /// back to a fresh anonymous sign-in instead of retrying a dead JWT
  /// forever.
  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
