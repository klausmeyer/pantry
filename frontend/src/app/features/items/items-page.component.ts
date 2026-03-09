import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { catchError, of } from 'rxjs';
import { ItemsApiService } from '../../core/api/items-api.service';
import { Item } from '../../core/models/item';

@Component({
  selector: 'app-items-page',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './items-page.component.html',
  styleUrl: './items-page.component.css'
})
export class ItemsPageComponent {
  private readonly api = inject(ItemsApiService);

  items: Item[] = [];
  loading = true;
  error = '';

  constructor() {
    this.api
      .list()
      .pipe(
        catchError((err: unknown) => {
          this.error = 'Failed to load items from the API.';
          this.loading = false;
          return of([] as Item[]);
        })
      )
      .subscribe((items) => {
        this.items = items;
        this.loading = false;
      });
  }
}
