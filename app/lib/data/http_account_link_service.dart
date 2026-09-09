import 'dart:async';
import 'account_link_service.dart';
import 'api_client.dart';

class HttpAccountLinkService implements AccountLinkService {
  HttpAccountLinkService(this._client) {
    _refresh();
  }

  final ApiClient _client;
  final _statusController = StreamController<bool>.broadcast();

  bool _isAnonymous = true;
  String? _linkedEmail;
  DateTime? _memberSince;
  String? _firstName;
  String? _lastName;

  Future<void> _refresh() async {
    final row = await _client.getMap('/account');
    _isAnonymous = row['isAnonymous'] as bool;
    _linkedEmail = row['linkedEmail'] as String?;
    _memberSince = row['memberSince'] == null ? null : DateTime.parse(row['memberSince'] as String);
    _firstName = row['firstName'] as String?;
    _lastName = row['lastName'] as String?;
    _statusController.add(_isAnonymous);
  }

  @override
  bool get isAnonymous => _isAnonymous;

  @override
  String? get linkedEmail => _linkedEmail;

  @override
  DateTime? get memberSince => _memberSince;

  @override
  String? get firstName => _firstName;

  @override
  String? get lastName => _lastName;

  @override
  Future<void> linkEmail(String email) async {
    await _client.post('/auth/link-email', {'email': email});
    await _refresh();
  }

  @override
  Future<void> setName({required String firstName, required String lastName}) async {
    await _client.patch('/account/name', {'firstName': firstName, 'lastName': lastName});
    _firstName = firstName;
    _lastName = lastName;
  }

  @override
  Stream<bool> get linkStatusChanges => _statusController.stream;
}
