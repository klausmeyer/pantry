import { Component } from '@angular/core';
import { ItemsPageComponent } from './features/items/items-page.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ItemsPageComponent],
  template: `
    <div data-theme="cupcake" class="min-h-screen">
      <main class="mx-auto w-[min(1100px,calc(100%-2rem))] py-12">
        <app-items-page></app-items-page>
      </main>
    </div>
  `
})
export class AppComponent {}
