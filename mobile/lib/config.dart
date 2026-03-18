const String apiBaseUrl = String.fromEnvironment(
  'PANTRY_API_BASE_URL',
  defaultValue: 'http://localhost:4000',
);
const String oidcIssuer = String.fromEnvironment(
  'PANTRY_OIDC_ISSUER',
  defaultValue: 'http://localhost:8081/realms/test',
);
const String oidcClientId = String.fromEnvironment(
  'PANTRY_OIDC_CLIENT_ID',
  defaultValue: 'pantry',
);
const String oidcRedirectUri = String.fromEnvironment(
  'PANTRY_OIDC_REDIRECT_URI',
  defaultValue: 'com.pantry.app:/oauthredirect',
);
const List<String> oidcScopes = ['openid', 'profile', 'email'];
