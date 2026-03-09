import { CommonModule, DOCUMENT } from '@angular/common';
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
  private readonly document = inject(DOCUMENT);

  locale: Locale = 'en';

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

  private readonly translations: Record<Locale, Record<string, string>> = {
    en: {
      addItem: 'Add item',
      sortBy: 'Sort by',
      sortName: 'Name',
      sortBestBefore: 'EXP',
      sortCreatedAt: 'Created at',
      sortUpdatedAt: 'Updated at',
      order: 'Order',
      addItemTitle: 'Add Item',
      editItemTitle: 'Edit Item',
      name: 'Name',
      bestBefore: 'EXP',
      contentAmount: 'Content amount',
      contentUnit: 'Content unit',
      packaging: 'Packaging',
      pictureKey: 'Picture key',
      commentOptional: 'Comment (optional)',
      cancel: 'Cancel',
      creating: 'Creating...',
      saving: 'Saving...',
      saveChanges: 'Save changes',
      loadingItems: 'Loading items...',
      failedDelete: 'Failed to delete item.',
      failedCreate: 'Failed to create item.',
      failedUpdate: 'Failed to update item.',
      failedLoad: 'Failed to load items from the API.',
      noItemsYet: 'No items yet',
      createFirstItem: 'Create your first item through the API and refresh.',
      deleteConfirm: 'Delete this item? This will hide it from the list.',
      edit: 'Edit',
      delete: 'Delete',
      expiresToday: 'expires today',
      overdueSuffix: 'overdue',
      daysLeftSuffix: 'left',
      daySingular: 'day',
      dayPlural: 'days',
      unit_grams: 'grams',
      unit_ml: 'ml',
      unit_l: 'l',
      packaging_can: 'can',
      packaging_box: 'box',
      packaging_bag: 'bag',
      packaging_jar: 'jar',
      packaging_other: 'other'
    },
    de: {
      addItem: 'Artikel hinzufügen',
      sortBy: 'Sortieren nach',
      sortName: 'Name',
      sortBestBefore: 'MHD',
      sortCreatedAt: 'Erstellt am',
      sortUpdatedAt: 'Aktualisiert am',
      order: 'Reihenfolge',
      addItemTitle: 'Artikel hinzufügen',
      editItemTitle: 'Artikel bearbeiten',
      name: 'Name',
      bestBefore: 'MHD',
      contentAmount: 'Inhalt (Menge)',
      contentUnit: 'Einheit',
      packaging: 'Verpackung',
      pictureKey: 'Bild-Schlüssel',
      commentOptional: 'Kommentar (optional)',
      cancel: 'Abbrechen',
      creating: 'Erstelle...',
      saving: 'Speichere...',
      saveChanges: 'Änderungen speichern',
      loadingItems: 'Lade Artikel...',
      failedDelete: 'Artikel konnte nicht gelöscht werden.',
      failedCreate: 'Artikel konnte nicht erstellt werden.',
      failedUpdate: 'Artikel konnte nicht aktualisiert werden.',
      failedLoad: 'Artikel konnten nicht geladen werden.',
      noItemsYet: 'Noch keine Artikel',
      createFirstItem: 'Erstelle den ersten Artikel über die API und aktualisiere dann.',
      deleteConfirm: 'Diesen Artikel löschen? Er wird aus der Liste ausgeblendet.',
      edit: 'Bearbeiten',
      delete: 'Löschen',
      expiresToday: 'läuft heute ab',
      overdueSuffix: 'abgelaufen',
      daysLeftSuffix: 'verbleibend',
      daySingular: 'Tag',
      dayPlural: 'Tage',
      unit_grams: 'g',
      unit_ml: 'ml',
      unit_l: 'l',
      packaging_can: 'Dose',
      packaging_box: 'Packung',
      packaging_bag: 'Tüte',
      packaging_jar: 'Glas',
      packaging_other: 'Sonstiges'
    }
  };

  constructor() {
    this.locale = this.readLocaleFromCookie();
    this.applyLocaleToDocument();
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

    const confirmed = window.confirm(this.t('deleteConfirm'));
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
        this.error = this.t('failedDelete');
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
        this.createError = this.t('failedCreate');
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
        this.editError = this.t('failedUpdate');
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
          this.error = this.t('failedLoad');
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
    const dayWord = this.dayWord(Math.abs(delta));
    if (delta < 0) {
      const days = Math.abs(delta);
      return `${days} ${dayWord} ${this.t('overdueSuffix')}`;
    }
    if (delta === 0) {
      return this.t('expiresToday');
    }
    return `${delta} ${this.dayWord(delta)} ${this.t('daysLeftSuffix')}`;
  }

  t(key: string): string {
    return this.translations[this.locale][key] ?? key;
  }

  setLocale(locale: Locale): void {
    if (this.locale === locale) {
      return;
    }
    this.locale = locale;
    this.writeLocaleCookie(this.locale);
    this.applyLocaleToDocument();
  }

  localeLabel(locale: Locale): string {
    if (locale === 'en') {
      return 'Switch to English';
    }
    return 'Auf Deutsch umstellen';
  }

  contentUnitLabel(unit: 'grams' | 'ml' | 'l'): string {
    return this.t(`unit_${unit}`);
  }

  packagingLabel(packaging: 'can' | 'box' | 'bag' | 'jar' | 'other'): string {
    return this.t(`packaging_${packaging}`);
  }

  private startOfUTCDate(date: Date): Date {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  }

  private dayWord(days: number): string {
    if (days === 1) {
      return this.t('daySingular');
    }
    return this.t('dayPlural');
  }

  private readLocaleFromCookie(): Locale {
    const cookie = this.document.cookie
      .split(';')
      .map((part) => part.trim())
      .find((part) => part.startsWith('pantry_locale='));

    const fromCookie = cookie?.split('=')[1] ?? '';
    if (fromCookie === 'de' || fromCookie === 'en') {
      return fromCookie;
    }

    const browser = this.document.documentElement.lang?.toLowerCase() || navigator.language.toLowerCase();
    return browser.startsWith('de') ? 'de' : 'en';
  }

  private writeLocaleCookie(locale: Locale): void {
    const maxAge = 60 * 60 * 24 * 365;
    this.document.cookie = `pantry_locale=${locale}; path=/; max-age=${maxAge}; samesite=lax`;
  }

  private applyLocaleToDocument(): void {
    this.document.documentElement.lang = this.locale;
  }
}

type Locale = 'en' | 'de';
