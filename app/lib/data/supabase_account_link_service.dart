import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_link_service.dart';

class SupabaseAccountLinkService implements AccountLinkService {
  SupabaseAccountLinkService(this._client);
  final SupabaseClient _client;

  @override
  bool get isAnonymous => _client.auth.currentUser?.isAnonymous ?? true;

  @override
  String? get linkedEmail {
    final email = _client.auth.currentUser?.email;
    return (email == null || email.isEmpty) ? null : email;
  }

  @override
  DateTime? get memberSince {
    final raw = _client.auth.currentUser?.createdAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> linkEmail(String email) async {
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: 'com.stubapp.stub://login-callback',
    );
  }

  @override
  Stream<bool> get linkStatusChanges =>
      _client.auth.onAuthStateChange.map((_) => isAnonymous);
}
