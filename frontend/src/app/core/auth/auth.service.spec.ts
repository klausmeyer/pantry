import { AuthService, AuthUser } from './auth.service';

describe('AuthService', () => {
  const futureExpiry = new Date(Date.now() + 60 * 60 * 1000).toISOString();

  beforeEach(() => {
    window.__PANTRY_OIDC__ = {
      enabled: true,
      issuer: 'https://issuer.example',
      clientId: 'pantry-client'
    };

    window.localStorage.clear();
    window.sessionStorage.clear();
    spyOn(console, 'error');
    window.history.replaceState({}, '', '/');
  });

  afterEach(() => {
    delete window.__PANTRY_OIDC__;
    window.localStorage.clear();
    window.sessionStorage.clear();
    window.history.replaceState({}, '', '/');
  });

  it('initializes and exchanges auth callback through the backend', async () => {
    const accessToken = jwt('access');
    const user = token(accessToken);
    const fetchSpy = mockFetch({
      data: {
        attributes: user
      }
    });
    window.sessionStorage.setItem('pantry_oidc_state', 'xyz');
    window.sessionStorage.setItem('pantry_oidc_nonce', 'nonce-123');
    window.history.replaceState({}, '', '/?code=abc&state=xyz');

    const service = new AuthService();
    await service.initialize();

    expect(fetchSpy).toHaveBeenCalledWith('/auth/exchange', jasmine.objectContaining({
      method: 'POST',
      body: JSON.stringify({ code: 'abc', nonce: 'nonce-123' })
    }));
    expect(service.getAccessToken()).toBe(accessToken);
    expect(window.location.search).toBe('');
  });

  it('requests an authorization URL when user is missing', async () => {
    const fetchSpy = mockFetch({
      data: {
        attributes: {
          url: 'https://issuer.example/auth'
        }
      }
    });
    const service = new AuthService();
    const redirectSpy = spyOn<any>(service, 'redirectTo');
    await service.initialize();

    expect(fetchSpy).toHaveBeenCalled();
    expect(String(fetchSpy.calls.mostRecent().args[0])).toContain('/auth/authorize?state=');
    expect(redirectSpy).toHaveBeenCalledWith('https://issuer.example/auth');
  });

  it('returns JWT access token when stored user is valid', async () => {
    const jwtAccessToken = jwt('access');
    window.localStorage.setItem('pantry_oidc_user', JSON.stringify(token(jwtAccessToken)));
    const fetchSpy = spyOn(window, 'fetch');

    const service = new AuthService();
    await service.initialize();

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(service.getAccessToken()).toBe(jwtAccessToken);
  });

  it('returns ID token when access token is opaque', async () => {
    const idToken = jwt('id');
    window.localStorage.setItem('pantry_oidc_user', JSON.stringify({
      ...token('opaque-token'),
      id_token: idToken
    }));
    spyOn(window, 'fetch');

    const service = new AuthService();
    await service.initialize();

    expect(service.getAccessToken()).toBe(idToken);
  });

  it('does not return expired access token', () => {
    window.localStorage.setItem('pantry_oidc_user', JSON.stringify({
      ...token('old-token'),
      expires_at: new Date(Date.now() - 1000).toISOString()
    }));

    const service = new AuthService();

    expect(service.getAccessToken()).toBeNull();
  });

  it('redirects through provider logout endpoint', async () => {
    window.localStorage.setItem('pantry_oidc_user', JSON.stringify({
      ...token('token-123'),
      id_token: 'id-token-123'
    }));
    const fetchSpy = mockFetch({
      data: {
        attributes: {
          url: 'https://issuer.example/logout'
        }
      }
    });

    const service = new AuthService();
    const redirectSpy = spyOn<any>(service, 'redirectTo');
    await service.logout();

    expect(fetchSpy).toHaveBeenCalledWith('/auth/logout?id_token_hint=id-token-123');
    expect(window.localStorage.getItem('pantry_oidc_user')).toBeNull();
    expect(redirectSpy).toHaveBeenCalledWith('https://issuer.example/logout');
  });

  it('stores error on invalid callback state', async () => {
    let error = '';
    window.history.replaceState({}, '', '/?code=abc&state=wrong');

    const service = new AuthService();
    service.error$.subscribe((value) => {
      error = value ?? '';
    });
    await service.initialize();

    expect(error).toBe('Invalid OIDC callback state');
  });

  function token(accessToken: string): AuthUser {
    return {
      access_token: accessToken,
      refresh_token: 'refresh-token',
      id_token: 'id-token',
      token_type: 'Bearer',
      expires_at: futureExpiry
    };
  }

  function jwt(prefix: string): string {
    return `${prefix}-header.${prefix}-payload.${prefix}-signature`;
  }

  function mockFetch(payload: unknown): jasmine.Spy<typeof window.fetch> {
    return spyOn(window, 'fetch').and.returnValue(Promise.resolve(new Response(JSON.stringify(payload), {
      status: 200,
      headers: {
        'Content-Type': 'application/vnd.api+json'
      }
    })));
  }
});
