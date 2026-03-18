import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';
import '../models/auth.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const _appAuth = FlutterAppAuth();

  static const _accessTokenKey = 'pantry.access_token';
  static const _idTokenKey = 'pantry.id_token';
  static const _refreshTokenKey = 'pantry.refresh_token';
  static const _expiresAtKey = 'pantry.expires_at';

  Future<AuthState?> load() async {
    final values = await Future.wait<String?>([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _idTokenKey),
      _storage.read(key: _refreshTokenKey),
      _storage.read(key: _expiresAtKey),
    ]);

    final accessToken = values[0];
    final idToken = values[1];
    final refreshToken = values[2];
    final expiresAtRaw = values[3];
    final expiresAt =
        expiresAtRaw != null ? DateTime.tryParse(expiresAtRaw) : null;

    if (accessToken == null && refreshToken == null) {
      return null;
    }

    var state = AuthState(
      accessToken: accessToken,
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      profile: idToken != null ? UserProfile.fromIdToken(idToken) : null,
    );

    if (state.isExpired && refreshToken != null) {
      try {
        state = await refresh(refreshToken);
      } catch (_) {
        await clear();
        return null;
      }
    }

    return state;
  }

  Future<AuthState> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        oidcClientId,
        oidcRedirectUri,
        discoveryUrl: '$oidcIssuer/.well-known/openid-configuration',
        scopes: oidcScopes,
      ),
    );

    final state = AuthState(
      accessToken: result?.accessToken,
      idToken: result?.idToken,
      refreshToken: result?.refreshToken,
      expiresAt: result?.accessTokenExpirationDateTime,
      profile:
          result?.idToken != null ? UserProfile.fromIdToken(result!.idToken!) : null,
    );

    await _persist(state);
    return state;
  }

  Future<AuthState> refresh(String refreshToken) async {
    final response = await _appAuth.token(
      TokenRequest(
        oidcClientId,
        oidcRedirectUri,
        discoveryUrl: '$oidcIssuer/.well-known/openid-configuration',
        refreshToken: refreshToken,
        scopes: oidcScopes,
      ),
    );

    final state = AuthState(
      accessToken: response?.accessToken,
      idToken: response?.idToken,
      refreshToken: response?.refreshToken ?? refreshToken,
      expiresAt: response?.accessTokenExpirationDateTime,
      profile: response?.idToken != null
          ? UserProfile.fromIdToken(response!.idToken!)
          : null,
    );

    await _persist(state);
    return state;
  }

  Future<void> clear() async {
    await Future.wait<void>([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _idTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _expiresAtKey),
    ]);
  }

  Future<void> _persist(AuthState state) async {
    await Future.wait<void>([
      if (state.accessToken != null)
        _storage.write(key: _accessTokenKey, value: state.accessToken),
      if (state.idToken != null)
        _storage.write(key: _idTokenKey, value: state.idToken),
      if (state.refreshToken != null)
        _storage.write(key: _refreshTokenKey, value: state.refreshToken),
      if (state.expiresAt != null)
        _storage.write(
          key: _expiresAtKey,
          value: state.expiresAt!.toIso8601String(),
        ),
    ]);
  }

  Future<String?> getValidAccessToken() async {
    try {
      final state = await load();
      return state?.accessToken;
    } catch (_) {
      await clear();
      return null;
    }
  }
}
