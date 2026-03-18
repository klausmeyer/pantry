import 'dart:convert';

class AuthState {
  AuthState({
    required this.accessToken,
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.profile,
  });

  final String? accessToken;
  final String? idToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final UserProfile? profile;

  bool get isExpired {
    if (expiresAt == null) {
      return false;
    }
    return DateTime.now().isAfter(expiresAt!);
  }
}

class UserProfile {
  UserProfile({required this.displayName, required this.email});

  final String? displayName;
  final String? email;

  factory UserProfile.fromIdToken(String idToken) {
    final parts = idToken.split('.');
    if (parts.length < 2) {
      return UserProfile(displayName: null, email: null);
    }
    final payload = _decodeBase64Url(parts[1]);
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final name =
        data['name']?.toString() ?? data['preferred_username']?.toString();
    final email = data['email']?.toString();
    return UserProfile(displayName: name, email: email);
  }
}

String _decodeBase64Url(String input) {
  var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
  while (normalized.length % 4 != 0) {
    normalized += '=';
  }
  return utf8.decode(base64Decode(normalized));
}
