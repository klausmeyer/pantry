(function () {
  const raw = {
    enabled: '${OIDC_ENABLED}',
    issuer: '${OIDC_ISSUER}',
    clientId: '${OIDC_CLIENT_ID}',
    redirectUri: '${OIDC_REDIRECT_URI}',
    silentRedirectUri: '${OIDC_SILENT_REDIRECT_URI}',
    postLogoutRedirectUri: '${OIDC_POST_LOGOUT_REDIRECT_URI}',
    scope: '${OIDC_SCOPE}',
    silentRenewEnabled: '${OIDC_SILENT_RENEW_ENABLED}'
  };

  const defaults = {
    enabled: true,
    issuer: 'https://example.com',
    clientId: 'pantry-client',
    redirectUri: window.location.origin + '/auth/callback',
    silentRedirectUri: window.location.origin + '/auth/silent',
    postLogoutRedirectUri: window.location.origin + '/',
    scope: 'openid profile email',
    silentRenewEnabled: true
  };

  function isPlaceholder(value) {
    if (typeof value !== 'string') {
      return false;
    }
    return value.startsWith('${' + 'OIDC_') || value.startsWith('$' + 'OIDC_');
  }

  function normalizeBoolean(value, fallback) {
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'string') {
      const normalized = value.trim().toLowerCase();
      if (normalized === 'true') {
        return true;
      }
      if (normalized === 'false') {
        return false;
      }
    }
    return fallback;
  }

  function normalizeString(value, fallback) {
    if (value == null) {
      return fallback;
    }
    if (typeof value !== 'string') {
      return fallback;
    }
    if (value.trim() === '' || isPlaceholder(value)) {
      return fallback;
    }
    return value;
  }

  const config = {
    enabled: normalizeBoolean(raw.enabled, defaults.enabled),
    issuer: normalizeString(raw.issuer, defaults.issuer),
    clientId: normalizeString(raw.clientId, defaults.clientId),
    redirectUri: normalizeString(raw.redirectUri, defaults.redirectUri),
    silentRedirectUri: normalizeString(raw.silentRedirectUri, defaults.silentRedirectUri),
    postLogoutRedirectUri: normalizeString(raw.postLogoutRedirectUri, defaults.postLogoutRedirectUri),
    scope: normalizeString(raw.scope, defaults.scope),
    silentRenewEnabled: normalizeBoolean(raw.silentRenewEnabled, defaults.silentRenewEnabled)
  };

  window.__PANTRY_OIDC__ = Object.assign({}, defaults, config, window.__PANTRY_OIDC__ || {});
  window.__PANTRY_OIDC_LOADED__ = true;
})();
