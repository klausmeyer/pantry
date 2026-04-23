import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { AuthService } from './auth.service';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth = inject(AuthService);
  const token = auth.getAccessToken();
  if (!token || !isBackendRequest(req.url)) {
    return next(req);
  }

  return next(
    req.clone({
      setHeaders: {
        Authorization: `Bearer ${token}`
      }
    })
  );
};

function isBackendRequest(url: string): boolean {
  if (url.startsWith('/api')) {
    return true;
  }
  if (url.startsWith('api/')) {
    return true;
  }
  if (url.startsWith(`${window.location.origin}/api`)) {
    return true;
  }
  return false;
}
