import { CommonModule } from '@angular/common';
import { Component, inject } from '@angular/core';
import { catchError, of } from 'rxjs';
import { ItemsApiService } from '../../core/api/items-api.service';
import { CreateItemInput, Item, ItemSortBy, SortOrder } from '../../core/models/item';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-items-page',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './items-page.component.html'
})
export class ItemsPageComponent {
  private readonly api = inject(ItemsApiService);

  items: Item[] = [];
  loading = true;
  error = '';
  sortBy: ItemSortBy = 'best_before';
  sortOrder: SortOrder = 'asc';
  deletingIds = new Set<string>();
  createLoading = false;
  createError = '';
  showCreateModal = false;
  showEditModal = false;
  editLoading = false;
  editError = '';
  editingItemId = '';
  newItem: CreateItemInput = {
    name: '',
    bestBefore: '',
    contentAmount: 1,
    contentUnit: 'grams',
    packaging: 'other',
    pictureKey: '',
    comment: ''
  };
  editItem: CreateItemInput = {
    name: '',
    bestBefore: '',
    contentAmount: 1,
    contentUnit: 'grams',
    packaging: 'other',
    pictureKey: '',
    comment: ''
  };

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

  deleteItem(id: string): void {
    if (!id || this.deletingIds.has(id)) {
      return;
    }

    const confirmed = window.confirm('Delete this item? This will hide it from the list.');
    if (!confirmed) {
      return;
    }

    this.deletingIds.add(id);
    this.api.softDelete(id).subscribe({
      next: () => {
        this.deletingIds.delete(id);
        this.items = this.items.filter((item) => item.id !== id);
      },
      error: () => {
        this.deletingIds.delete(id);
        this.error = 'Failed to delete item.';
      }
    });
  }

  createItem(): void {
    if (this.createLoading) {
      return;
    }

    this.createLoading = true;
    this.createError = '';

    this.api.create(this.newItem).subscribe({
      next: () => {
        this.createLoading = false;
        this.showCreateModal = false;
        this.newItem = {
          name: '',
          bestBefore: '',
          contentAmount: 1,
          contentUnit: this.newItem.contentUnit,
          packaging: this.newItem.packaging,
          pictureKey: '',
          comment: ''
        };
        this.loadItems();
      },
      error: () => {
        this.createLoading = false;
        this.createError = 'Failed to create item.';
      }
    });
  }

  openEditModal(item: Item): void {
    this.editError = '';
    this.editingItemId = item.id;
    this.editItem = {
      name: item.name,
      bestBefore: item.bestBefore,
      contentAmount: item.contentAmount,
      contentUnit: item.contentUnit,
      packaging: item.packaging,
      pictureKey: item.pictureKey,
      comment: item.comment ?? ''
    };
    this.showEditModal = true;
  }

  closeEditModal(): void {
    if (this.editLoading) {
      return;
    }
    this.showEditModal = false;
  }

  updateItem(): void {
    if (this.editLoading || !this.editingItemId) {
      return;
    }

    this.editLoading = true;
    this.editError = '';
    this.api.update(this.editingItemId, this.editItem).subscribe({
      next: () => {
        this.editLoading = false;
        this.showEditModal = false;
        this.loadItems();
      },
      error: () => {
        this.editLoading = false;
        this.editError = 'Failed to update item.';
      }
    });
  }

  openCreateModal(): void {
    this.createError = '';
    this.showCreateModal = true;
  }

  closeCreateModal(): void {
    if (this.createLoading) {
      return;
    }
    this.showCreateModal = false;
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
