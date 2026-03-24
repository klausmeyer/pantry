import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { User, UserManager, WebStorageStateStore } from 'oidc-client-ts';
import { getOIDCConfig } from './oidc-config';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly config = getOIDCConfig();
  private readonly manager: UserManager | null;
  private readonly userSubject = new BehaviorSubject<User | null>(null);
  private readonly errorSubject = new BehaviorSubject<string | null>(null);

  readonly user$ = this.userSubject.asObservable();
  readonly error$ = this.errorSubject.asObservable();
  readonly enabled = this.config.enabled;

  constructor() {
    if (!this.config.enabled) {
      this.manager = null;
      return;
    }

    this.manager = new UserManager({
      authority: this.config.issuer,
      client_id: this.config.clientId,
      redirect_uri: this.config.redirectUri,
      silent_redirect_uri: this.config.silentRedirectUri,
      post_logout_redirect_uri: this.config.postLogoutRedirectUri,
      response_type: 'code',
      scope: this.config.scope,
      userStore: new WebStorageStateStore({ store: window.localStorage }),
      monitorSession: false,
      automaticSilentRenew: this.config.silentRenewEnabled
    });

    this.manager.events.addUserLoaded((user: User) => {
      this.userSubject.next(user);
    });
    this.manager.events.addAccessTokenExpired(() => {
      void this.requireLogin();
    });
    this.manager.events.addSilentRenewError((err: unknown) => {
      const message = err instanceof Error ? err.message : 'silent renew error';
      this.errorSubject.next(message);
      console.error('OIDC silent renew error', err);
    });
    this.manager.events.addUserSignedOut(() => {
      this.userSubject.next(null);
    });
    this.manager.events.addUserUnloaded(() => {
      this.userSubject.next(null);
    });
  }

  async initialize(): Promise<void> {
    if (!this.manager) {
      return;
    }

    try {
      console.log('OIDC config', this.config);
      if (this.isAuthCallback()) {
        try {
          await this.manager.signinRedirectCallback();
        } finally {
          this.clearAuthCallbackUrl();
        }
      }

      const user = await this.manager.getUser();
      if (!user || user.expired) {
        this.userSubject.next(null);
        await this.requireLogin();
        return;
      }

      this.userSubject.next(user);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OIDC initialization failed';
      this.errorSubject.next(message);
      console.error('OIDC init error', err);
    }
  }

  login(): void {
    if (!this.manager) {
      return;
    }
    void this.manager.signinRedirect();
  }

  logout(): void {
    if (!this.manager) {
      return;
    }
    void this.manager.signoutRedirect();
  }

  getAccessToken(): string | null {
    const user = this.userSubject.value;
    if (!user || user.expired) {
      return null;
    }
    return user.access_token ?? null;
  }

  private async requireLogin(): Promise<void> {
    if (!this.manager) {
      return;
    }
    if (this.isAuthCallback()) {
      return;
    }
    try {
      await this.manager.signinRedirect();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OIDC login failed';
      this.errorSubject.next(message);
      console.error('OIDC login error', err);
    }
  }

  private isAuthCallback(): boolean {
    const params = new URLSearchParams(window.location.search);
    return params.has('code') && params.has('state');
  }

  private clearAuthCallbackUrl(): void {
    window.history.replaceState({}, document.title, '/');
  }
}
