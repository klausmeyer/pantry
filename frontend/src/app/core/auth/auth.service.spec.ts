import { AuthService } from './auth.service';
import type { User } from 'oidc-client-ts';

interface EventHandlers {
  userLoaded?: (user: User) => void;
  accessTokenExpired?: () => void;
  silentRenewError?: (err: unknown) => void;
  userSignedOut?: () => void;
  userUnloaded?: () => void;
}

describe('AuthService', () => {
  let handlers: EventHandlers;
  let manager: {
    events: {
      addUserLoaded: (cb: (user: User) => void) => void;
      addAccessTokenExpired: (cb: () => void) => void;
      addSilentRenewError: (cb: (err: unknown) => void) => void;
      addUserSignedOut: (cb: () => void) => void;
      addUserUnloaded: (cb: () => void) => void;
    };
    getUser: jasmine.Spy;
    signinRedirect: jasmine.Spy;
    signinRedirectCallback: jasmine.Spy;
    signoutRedirect: jasmine.Spy;
  };
  let userManagerFactory: new (...args: any[]) => any;

  beforeEach(() => {
    handlers = {};
    manager = {
      events: {
        addUserLoaded: (cb) => {
          handlers.userLoaded = cb;
        },
        addAccessTokenExpired: (cb) => {
          handlers.accessTokenExpired = cb;
        },
        addSilentRenewError: (cb) => {
          handlers.silentRenewError = cb;
        },
        addUserSignedOut: (cb) => {
          handlers.userSignedOut = cb;
        },
        addUserUnloaded: (cb) => {
          handlers.userUnloaded = cb;
        }
      },
      getUser: jasmine.createSpy('getUser'),
      signinRedirect: jasmine.createSpy('signinRedirect').and.returnValue(Promise.resolve()),
      signinRedirectCallback: jasmine.createSpy('signinRedirectCallback').and.returnValue(Promise.resolve()),
      signoutRedirect: jasmine.createSpy('signoutRedirect').and.returnValue(Promise.resolve())
    };

    const UserManagerMock = function () {
      return manager as any;
    } as any;
    userManagerFactory = UserManagerMock;

    window.__PANTRY_OIDC__ = {
      enabled: true,
      issuer: 'https://issuer.example',
      clientId: 'pantry-client'
    };

    spyOn(console, 'log');
    spyOn(console, 'error');
    window.history.replaceState({}, '', '/');
  });

  afterEach(() => {
    delete window.__PANTRY_OIDC__;
    window.history.replaceState({}, '', '/');
  });

  it('initializes and handles auth callback', async () => {
    const user = { access_token: 'token', expired: false } as User;
    manager.getUser.and.returnValue(Promise.resolve(user));

    window.history.replaceState({}, '', '/?code=abc&state=xyz');

    const service = new AuthService(userManagerFactory);
    await service.initialize();

    expect(manager.signinRedirectCallback).toHaveBeenCalled();
    expect(service.getAccessToken()).toBe('token');
    expect(window.location.search).toBe('');
  });

  it('requests login when user is missing', async () => {
    manager.getUser.and.returnValue(Promise.resolve(null));

    const service = new AuthService(userManagerFactory);
    await service.initialize();

    expect(manager.signinRedirect).toHaveBeenCalled();
    expect(service.getAccessToken()).toBeNull();
  });

  it('returns access token when user is valid', async () => {
    const user = { access_token: 'token-123', expired: false } as User;
    manager.getUser.and.returnValue(Promise.resolve(user));

    const service = new AuthService(userManagerFactory);
    await service.initialize();

    expect(manager.signinRedirect).not.toHaveBeenCalled();
    expect(service.getAccessToken()).toBe('token-123');
  });

  it('triggers login on access token expiration', async () => {
    manager.getUser.and.returnValue(Promise.resolve(null));

    const service = new AuthService(userManagerFactory);
    await service.initialize();

    handlers.accessTokenExpired?.();

    expect(manager.signinRedirect).toHaveBeenCalled();
  });

  it('stores error on silent renew error', () => {
    const service = new AuthService(userManagerFactory);
    let error = '';
    service.error$.subscribe((value) => {
      error = value ?? '';
    });

    handlers.silentRenewError?.(new Error('renew failed'));

    expect(error).toBe('renew failed');
  });
});
