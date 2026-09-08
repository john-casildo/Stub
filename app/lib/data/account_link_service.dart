abstract class AccountLinkService {
  bool get isAnonymous;
  String? get linkedEmail;
  DateTime? get memberSince;
  String? get firstName;
  String? get lastName;
  Future<void> linkEmail(String email);
  Future<void> setName({required String firstName, required String lastName});

  /// Emits the new `isAnonymous` value whenever the underlying auth
  /// state changes (e.g. after the user completes an email-link
  /// confirmation) — lets UI react without polling.
  Stream<bool> get linkStatusChanges;
}
