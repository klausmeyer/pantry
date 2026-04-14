import { provideZoneChangeDetection } from "@angular/core";
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient, withInterceptors } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { authInterceptor } from './app/core/auth/auth.interceptor';
import { UserManager, WebStorageStateStore } from 'oidc-client-ts';
import { getOIDCConfig } from './app/core/auth/oidc-config';

const silentPath = '/auth/silent';
const config = getOIDCConfig();

if (window.location.pathname === silentPath && config.enabled) {
  const manager = new UserManager({
    authority: config.issuer,
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    silent_redirect_uri: config.silentRedirectUri,
    post_logout_redirect_uri: config.postLogoutRedirectUri,
    response_type: 'code',
    scope: config.scope,
    userStore: new WebStorageStateStore({ store: window.localStorage }),
    monitorSession: false,
    automaticSilentRenew: false
  });
  manager.signinSilentCallback().catch((err: unknown) => {
    console.error('OIDC silent callback failed', err);
  });
} else {
  bootstrapApplication(AppComponent, {
    providers: [provideZoneChangeDetection(),provideHttpClient(withInterceptors([authInterceptor]))]
  }).catch((err: unknown) => {
    console.error('bootstrap failed', err);
  });
}
