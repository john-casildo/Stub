abstract class AccountLinkService {
  bool get isAnonymous;
  String? get linkedEmail;
  Future<void> linkEmail(String email);

  /// Emits the new `isAnonymous` value whenever the underlying auth
  /// state changes (e.g. after the user completes an email-link
  /// confirmation) — lets UI react without polling.
  Stream<bool> get linkStatusChanges;
}
