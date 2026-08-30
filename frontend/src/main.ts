import { provideZoneChangeDetection } from "@angular/core";
import { bootstrapApplication } from '@angular/platform-browser';
import { provideHttpClient, withInterceptors, withXhr } from '@angular/common/http';
import { AppComponent } from './app/app.component';
import { authInterceptor } from './app/core/auth/auth.interceptor';

bootstrapApplication(AppComponent, {
  providers: [provideZoneChangeDetection(), provideHttpClient(withXhr(), withInterceptors([authInterceptor]))]
}).catch((err: unknown) => {
  console.error('bootstrap failed', err);
});
