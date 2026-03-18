export interface OIDCConfig {
  enabled: boolean;
  issuer: string;
  clientId: string;
  redirectUri: string;
  silentRedirectUri: string;
  postLogoutRedirectUri: string;
  scope: string;
  silentRenewEnabled: boolean;
}

declare global {
  interface Window {
    __PANTRY_OIDC__?: Partial<OIDCConfig>;
  }
}

const defaultConfig: OIDCConfig = {
  enabled: true,
  issuer: 'https://example.com',
  clientId: 'pantry-client',
  redirectUri: `${window.location.origin}/auth/callback`,
  silentRedirectUri: `${window.location.origin}/auth/silent`,
  postLogoutRedirectUri: `${window.location.origin}/`,
  scope: 'openid profile email',
  silentRenewEnabled: true
};

function normalizeBool(value: unknown, fallback: boolean): boolean {
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

export function getOIDCConfig(): OIDCConfig {
  const override = window.__PANTRY_OIDC__ ?? {};
  return {
    ...defaultConfig,
    ...override,
    enabled: normalizeBool(override.enabled, defaultConfig.enabled),
    silentRenewEnabled: normalizeBool(
      override.silentRenewEnabled,
      defaultConfig.silentRenewEnabled
    )
  };
}
