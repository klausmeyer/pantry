import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';
import { getOIDCConfig } from './oidc-config';

export interface AuthUser {
  access_token: string;
  refresh_token?: string;
  id_token?: string;
  token_type: string;
  expires_at: string;
  profile?: Record<string, unknown>;
}

interface AuthTokenResponse {
  data?: {
    attributes?: AuthUser;
  };
}

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly config = getOIDCConfig();
  private readonly userSubject = new BehaviorSubject<AuthUser | null>(null);
  private readonly errorSubject = new BehaviorSubject<string | null>(null);
  private refreshTimer: number | null = null;

  readonly user$ = this.userSubject.asObservable();
  readonly error$ = this.errorSubject.asObservable();
  readonly enabled = this.config.enabled;

  async initialize(): Promise<void> {
    if (!this.enabled) {
      return;
    }

    try {
      if (this.isAuthCallback()) {
        try {
          await this.handleCallback();
        } finally {
          this.clearAuthCallbackUrl();
        }
      }

      const user = this.loadUser();
      if (!user || this.isExpired(user)) {
        this.userSubject.next(null);
        this.clearUser();
        await this.requireLogin();
        return;
      }

      this.userSubject.next(user);
      this.scheduleRefresh(user);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OIDC initialization failed';
      this.errorSubject.next(message);
      console.error('OIDC init error', err);
    }
  }

  login(): void {
    if (!this.enabled) {
      return;
    }
    void this.requireLogin();
  }

  logout(): Promise<void> {
    const user = this.userSubject.value ?? this.loadUser();
    this.clearRefreshTimer();
    this.clearUser();
    this.userSubject.next(null);
    if (!this.enabled) {
      return Promise.resolve();
    }
    return this.redirectToLogout(user?.id_token);
  }

  getAuthHeaderToken(): string | null {
    const user = this.userSubject.value;
    if (!user || this.isExpired(user)) {
      return null;
    }
    return this.jwtToken(user);
  }

  getAccessToken(): string | null {
    return this.getAuthHeaderToken();
  }

  private async requireLogin(): Promise<void> {
    if (!this.enabled || this.isAuthCallback()) {
      return;
    }

    try {
      const state = this.randomString();
      const nonce = this.randomString();
      window.sessionStorage.setItem('pantry_oidc_state', state);
      window.sessionStorage.setItem('pantry_oidc_nonce', nonce);

      const response = await fetch(`/auth/authorize?state=${encodeURIComponent(state)}&nonce=${encodeURIComponent(nonce)}`);
      if (!response.ok) {
        throw new Error('OIDC authorization URL request failed');
      }
      const payload = (await response.json()) as { data?: { attributes?: { url?: string } } };
      const url = payload.data?.attributes?.url;
      if (!url) {
        throw new Error('OIDC authorization URL missing');
      }
      this.redirectTo(url);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OIDC login failed';
      this.errorSubject.next(message);
      console.error('OIDC login error', err);
    }
  }

  private async handleCallback(): Promise<void> {
    const params = new URLSearchParams(window.location.search);
    const code = params.get('code') ?? '';
    const state = params.get('state') ?? '';
    const expectedState = window.sessionStorage.getItem('pantry_oidc_state') ?? '';
    const nonce = window.sessionStorage.getItem('pantry_oidc_nonce') ?? '';
    window.sessionStorage.removeItem('pantry_oidc_state');
    window.sessionStorage.removeItem('pantry_oidc_nonce');

    if (!code || !state || !expectedState || state !== expectedState || !nonce) {
      throw new Error('Invalid OIDC callback state');
    }

    const user = await this.postToken('/auth/exchange', { code, nonce });
    this.storeUser(user);
    this.userSubject.next(user);
    this.scheduleRefresh(user);
  }

  private async refresh(user: AuthUser): Promise<void> {
    if (!user.refresh_token) {
      await this.requireLogin();
      return;
    }

    try {
      const refreshed = await this.postToken('/auth/refresh', { refresh_token: user.refresh_token });
      if (!refreshed.refresh_token) {
        refreshed.refresh_token = user.refresh_token;
      }
      this.storeUser(refreshed);
      this.userSubject.next(refreshed);
      this.scheduleRefresh(refreshed);
    } catch (err) {
      this.clearUser();
      this.userSubject.next(null);
      const message = err instanceof Error ? err.message : 'OIDC refresh failed';
      this.errorSubject.next(message);
      await this.requireLogin();
    }
  }

  private async postToken(url: string, body: Record<string, string>): Promise<AuthUser> {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(body)
    });
    if (!response.ok) {
      throw new Error('OIDC token request failed');
    }

    const payload = (await response.json()) as AuthTokenResponse;
    const user = payload.data?.attributes;
    if (!user?.access_token || !user.expires_at) {
      throw new Error('OIDC token response missing credentials');
    }
    return user;
  }

  private async redirectToLogout(idTokenHint?: string): Promise<void> {
    try {
      const query = idTokenHint ? `?id_token_hint=${encodeURIComponent(idTokenHint)}` : '';
      const response = await fetch(`/auth/logout${query}`);
      if (!response.ok) {
        throw new Error('OIDC logout URL request failed');
      }
      const payload = (await response.json()) as { data?: { attributes?: { url?: string } } };
      this.redirectTo(payload.data?.attributes?.url ?? this.config.postLogoutRedirectUri);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'OIDC logout failed';
      this.errorSubject.next(message);
      console.error('OIDC logout error', err);
      this.redirectTo(this.config.postLogoutRedirectUri);
    }
  }

  private loadUser(): AuthUser | null {
    const raw = window.localStorage.getItem('pantry_oidc_user');
    if (!raw) {
      return null;
    }
    try {
      return JSON.parse(raw) as AuthUser;
    } catch {
      return null;
    }
  }

  private storeUser(user: AuthUser): void {
    window.localStorage.setItem('pantry_oidc_user', JSON.stringify(user));
  }

  private clearUser(): void {
    window.localStorage.removeItem('pantry_oidc_user');
  }

  private isExpired(user: AuthUser): boolean {
    return new Date(user.expires_at).getTime() <= Date.now() + 5000;
  }

  private jwtToken(user: AuthUser): string | null {
    if (this.isJWT(user.access_token)) {
      return user.access_token;
    }
    if (user.id_token && this.isJWT(user.id_token)) {
      return user.id_token;
    }
    return null;
  }

  private isJWT(token: string): boolean {
    return token.split('.').length === 3;
  }

  private scheduleRefresh(user: AuthUser): void {
    this.clearRefreshTimer();
    if (!user.refresh_token) {
      return;
    }
    const refreshIn = Math.max(new Date(user.expires_at).getTime() - Date.now() - 60000, 5000);
    this.refreshTimer = window.setTimeout(() => {
      void this.refresh(user);
    }, refreshIn);
  }

  private clearRefreshTimer(): void {
    if (this.refreshTimer != null) {
      window.clearTimeout(this.refreshTimer);
      this.refreshTimer = null;
    }
  }

  private randomString(): string {
    const bytes = new Uint8Array(32);
    window.crypto.getRandomValues(bytes);
    return btoa(String.fromCharCode(...bytes))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  private redirectTo(url: string): void {
    window.location.assign(url);
  }

  private isAuthCallback(): boolean {
    const params = new URLSearchParams(window.location.search);
    return params.has('code') && params.has('state');
  }

  private clearAuthCallbackUrl(): void {
    window.history.replaceState({}, document.title, '/');
  }
}
