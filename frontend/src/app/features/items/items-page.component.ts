import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { catchError, of } from 'rxjs';
import { ItemsApiService } from '../../core/api/items-api.service';
import { Item, ItemSortBy, SortOrder } from '../../core/models/item';

@Component({
  selector: 'app-items-page',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './items-page.component.html'
})
export class ItemsPageComponent {
  private readonly api = inject(ItemsApiService);

  items: Item[] = [];
  loading = true;
  error = '';
  sortBy: ItemSortBy = 'best_before';
  sortOrder: SortOrder = 'asc';

  constructor() {
    this.loadItems();
  }

  onSortByChange(sortBy: string): void {
    this.sortBy = sortBy as ItemSortBy;
    this.loadItems();
  }

  toggleSortOrder(): void {
    this.sortOrder = this.sortOrder === 'asc' ? 'desc' : 'asc';
    this.loadItems();
  }

  private loadItems(): void {
    this.loading = true;
    this.error = '';

    this.api
      .list(this.sortBy, this.sortOrder)
      .pipe(
        catchError((_err: unknown) => {
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
