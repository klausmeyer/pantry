import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { ItemsPageComponent } from './features/items/items-page.component';
import { AuthService } from './core/auth/auth.service';

@Component({
    selector: 'app-root',
    imports: [CommonModule, ItemsPageComponent],
    template: `
    <div data-theme="cupcake" class="min-h-screen">
      @if (ready) {
        @if (canRender) {
          <main class="mx-auto w-[min(1100px,calc(100%-2rem))] pt-20 pb-12">
            <app-items-page></app-items-page>
          </main>
        } @else {
        }
      } @else {
        <main class="mx-auto w-[min(1100px,calc(100%-2rem))] pt-20 pb-12">
          <div class="flex items-center gap-2 opacity-70">
            <span class="loading loading-spinner loading-sm"></span>
            <span class="text-sm">Loading session...</span>
          </div>
        </main>
      }
      @if (authError$ | async; as authError) {
        <section class="mt-4">
          <div class="alert alert-error">
            <span>Auth error: {{ authError }}</span>
          </div>
        </section>
      }
    </div>
    `
})
export class AppComponent {
  private readonly auth = inject(AuthService);
  readonly authEnabled = this.auth.enabled;
  readonly authError$ = this.auth.error$;
  ready = !this.authEnabled;
  canRender = !this.authEnabled;

  constructor() {
    void this.initAuth();
  }

  private async initAuth(): Promise<void> {
    await this.auth.initialize();
    const token = this.auth.getAccessToken();
    this.canRender = !this.authEnabled || Boolean(token);
    this.ready = true;
  }
}
