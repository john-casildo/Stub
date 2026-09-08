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
  String? get firstName => _client.auth.currentUser?.userMetadata?['first_name'] as String?;

  @override
  String? get lastName => _client.auth.currentUser?.userMetadata?['last_name'] as String?;

  @override
  Future<void> linkEmail(String email) async {
    await _client.auth.updateUser(
      UserAttributes(email: email),
      emailRedirectTo: 'com.stubapp.stub://login-callback',
    );
  }

  // `UserAttributes.data` replaces the whole user_metadata map rather than
  // merging into it — fine today since name is the only metadata this app
  // sets, but revisit (merge with the existing map first) if that changes.
  @override
  Future<void> setName({required String firstName, required String lastName}) async {
    await _client.auth.updateUser(
      UserAttributes(data: {'first_name': firstName, 'last_name': lastName}),
    );
  }

  @override
  Stream<bool> get linkStatusChanges =>
      _client.auth.onAuthStateChange.map((_) => isAnonymous);
}
