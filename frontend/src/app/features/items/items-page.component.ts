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

  bestBeforeDeltaDays(bestBefore: string): number {
    const today = this.startOfUTCDate(new Date());
    const target = this.startOfUTCDate(new Date(`${bestBefore}T00:00:00Z`));
    const msPerDay = 24 * 60 * 60 * 1000;
    return Math.round((target.getTime() - today.getTime()) / msPerDay);
  }

  bestBeforeBadgeClass(bestBefore: string): string {
    const delta = this.bestBeforeDeltaDays(bestBefore);
    if (delta < 0) {
      return 'badge-error';
    }
    if (delta <= 14) {
      return 'badge-warning';
    }
    return 'badge-success';
  }

  bestBeforeLabel(bestBefore: string): string {
    const delta = this.bestBeforeDeltaDays(bestBefore);
    if (delta < 0) {
      const days = Math.abs(delta);
      return `${days} day${days === 1 ? '' : 's'} overdue`;
    }
    if (delta === 0) {
      return 'expires today';
    }
    return `${delta} day${delta === 1 ? '' : 's'} left`;
  }

  private startOfUTCDate(date: Date): Date {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  }
}
