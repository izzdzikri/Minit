import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interface for reading/writing the backend API bearer token securely.
abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> deleteToken();
}

/// Keystore/Keychain-backed storage via `flutter_secure_storage`.
class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const String _tokenKey = 'minit_backend_api_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() async {
    final val = await _storage.read(key: _tokenKey);
    if (val == null || val.trim().isEmpty) return null;
    return val.trim();
  }

  @override
  Future<void> writeToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      await _storage.delete(key: _tokenKey);
      return;
    }
    await _storage.write(key: _tokenKey, value: trimmed);
  }

  @override
  Future<void> deleteToken() => _storage.delete(key: _tokenKey);
}
