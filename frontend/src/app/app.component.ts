import { Component } from '@angular/core';
import { ItemsPageComponent } from './features/items/items-page.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [ItemsPageComponent],
  template: `
    <main class="layout">
      <app-items-page></app-items-page>
    </main>
  `,
  styleUrl: './app.component.css'
})
export class AppComponent {}
