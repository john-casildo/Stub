import 'dart:convert';
import 'package:http/http.dart' as http;
import 'local_auth_token_store.dart';

/// Thrown for any non-2xx response from the custom backend. `code` mirrors
/// the server's `error.code` field (see `server/src/app.ts`'s error shape),
/// letting callers branch the same way they already do on
/// `PostgrestException.code` for the Supabase backend.
class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}

/// Thin HTTP client shared by every `Http*Repository`/`HttpAccountLinkService`.
/// Ensures a device has an anonymous session before the first authenticated
/// call, matching `main.dart`'s `_ensureSession()` behavior for Supabase.
class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenStore, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final LocalAuthTokenStore tokenStore;
  final http.Client _http;

  /// In-flight anonymous sign-in, shared by every concurrent caller. Without
  /// this, two calls racing at cold start (e.g. `HttpAccountLinkService`'s
  /// constructor and `RootShell._load()`) would both find no stored token and
  /// both `POST /auth/anonymous`, creating two `users` rows — whichever
  /// `writeToken` landed last silently winning and orphaning the other.
  Future<String>? _tokenFuture;

  Future<String> _ensureToken() async {
    final existing = await tokenStore.readToken();
    if (existing != null) return existing;
    // Await the store read *before* checking `_tokenFuture`, so the
    // check-then-fetch sequence is uninterrupted by the async gap above.
    final inFlight = _tokenFuture;
    if (inFlight != null) return inFlight;
    final future = _fetchAndStoreToken();
    _tokenFuture = future;
    try {
      return await future;
    } finally {
      // Cleared on success *and* failure, so a failed sign-in doesn't wedge
      // every later caller onto the same dead future.
      _tokenFuture = null;
    }
  }

  Future<String> _fetchAndStoreToken() async {
    final response = await _http.post(Uri.parse('$baseUrl/auth/anonymous'));
    if (response.statusCode != 201) {
      throw ApiException(response.statusCode, 'anonymous_sign_in_failed', 'Could not start a session');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final token = body['token'] as String;
    await tokenStore.writeToken(token);
    return token;
  }

  Future<http.Response> _issue(String method, Uri uri, String token, String? encoded) async {
    final headers = {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
    switch (method) {
      case 'GET':
        return _http.get(uri, headers: headers);
      case 'POST':
        return _http.post(uri, headers: headers, body: encoded);
      case 'PATCH':
        return _http.patch(uri, headers: headers, body: encoded);
      case 'DELETE':
        return _http.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported method $method');
    }
  }

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = body == null ? null : jsonEncode(body);
    var response = await _issue(method, uri, await _ensureToken(), encoded);
    if (response.statusCode == 401) {
      // The stored JWT is invalid (expired, or its user row is gone). Drop it
      // and retry the whole request once with a fresh anonymous session.
      // Exactly one retry — a second 401 falls through to the throw below, so
      // a genuinely misconfigured server can't spin this forever.
      await tokenStore.deleteToken();
      response = await _issue(method, uri, await _ensureToken(), encoded);
    }
    if (response.statusCode >= 400) {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body) as Map<String, dynamic>?;
      final error = decoded?['error'] as Map<String, dynamic>?;
      throw ApiException(
        response.statusCode,
        error?['code'] as String? ?? 'unknown_error',
        error?['message'] as String? ?? 'Request failed',
      );
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }

  Future<List<dynamic>> getList(String path) async => (await _send('GET', path)) as List<dynamic>;
  Future<Map<String, dynamic>> getMap(String path) async => (await _send('GET', path)) as Map<String, dynamic>;
  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async =>
      (await _send('POST', path, body: body)) as Map<String, dynamic>;
  Future<void> patch(String path, Map<String, dynamic> body) => _send('PATCH', path, body: body);
  Future<void> delete(String path) => _send('DELETE', path);
}
