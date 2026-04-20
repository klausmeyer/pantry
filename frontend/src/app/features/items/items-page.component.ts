import { CommonModule } from '@angular/common';
import { Component, HostListener, inject, DOCUMENT } from '@angular/core';
import { Observable, catchError, finalize, of, switchMap, tap } from 'rxjs';
import { ItemsApiService } from '../../core/api/items-api.service';
import { CreateItemInput, Item, ItemSortBy, SortOrder } from '../../core/models/item';
import { FormsModule } from '@angular/forms';
import { AuthService } from '../../core/auth/auth.service';
import type { User } from 'oidc-client-ts';

@Component({
    selector: 'app-items-page',
    imports: [CommonModule, FormsModule],
    templateUrl: './items-page.component.html'
})
export class ItemsPageComponent {
  private readonly api = inject(ItemsApiService);
  private readonly document = inject(DOCUMENT);
  private readonly auth = inject(AuthService);

  readonly user$: Observable<User | null> = this.auth.user$;

  locale: Locale = 'en';
  readonly expiringSoonDays = 14;

  items: Item[] = [];
  loading = true;
  error = '';
  sortBy: ItemSortBy = 'best_before';
  sortOrder: SortOrder = 'asc';
  searchTerm = '';
  activeFilter: FilterValue = 'all';
  viewMode: ViewMode = 'list';
  deletingIds = new Set<string>();
  duplicatingIds = new Set<string>();
  createLoading = false;
  createError = '';
  showCreateModal = false;
  showEditModal = false;
  showPreviewModal = false;
  showDetailsModal = false;
  editLoading = false;
  editError = '';
  editingItemId = '';
  addMoreOnCreate = false;
  newItemPictureFile: File | null = null;
  editItemPictureFile: File | null = null;
  newItemPreviewUrl: string | null = null;
  editItemPreviewUrl: string | null = null;
  previewUrl: string | null = null;
  previewLoading = false;
  previewError = '';
  previewItemName = '';
  detailsItem: Item | null = null;
  newItem: CreateItemInput = {
    name: '',
    bestBefore: '',
    contentAmount: 1,
    contentUnit: 'grams',
    packaging: 'other',
    pictureKey: null,
    comment: ''
  };
  editItem: CreateItemInput = {
    name: '',
    bestBefore: '',
    contentAmount: 1,
    contentUnit: 'grams',
    packaging: 'other',
    pictureKey: null,
    comment: ''
  };

  private readonly translations: Record<Locale, Record<string, string>> = {
    en: {
      addItem: 'Add item',
      sortBy: 'Sort by',
      search: 'Search',
      searchPlaceholder: 'Search items',
      filter: 'Filter',
      filterAll: 'All items',
      filterHasImage: 'With image',
      filterNoImage: 'No image',
      overviewTitle: 'Pantry overview',
      overviewSubtitle: 'Track freshness, restocks, and what needs attention.',
      totalItems: 'Total items',
      totalItemsDesc: 'Synced',
      expiringSoon: 'Expiring soon',
      expiringSoonDesc: 'Within {days} days',
      overdue: 'Overdue',
      overdueDesc: 'Expired',
      clearSearch: 'Clear',
      view: 'View',
      viewList: 'List',
      viewGrid: 'Grid',
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
      pictureKey: 'Picture',
      commentOptional: 'Comment (optional)',
      cancel: 'Cancel',
      creating: 'Creating...',
      saving: 'Saving...',
      saveChanges: 'Save changes',
      loadingItems: 'Loading items...',
      failedDelete: 'Failed to delete item.',
      failedDuplicate: 'Failed to duplicate item.',
      duplicateConfirm: 'Duplicate this item?',
      duplicateConfirmName: 'Duplicate "{name}"?',
      failedCreate: 'Failed to create item.',
      failedUpdate: 'Failed to update item.',
      failedLoad: 'Failed to load items from the API.',
      noItemsYet: 'No items yet',
      createFirstItem: 'Create your first item through the API and refresh.',
      deleteConfirm: 'Delete this item? This will hide it from the list.',
      preview: 'Preview',
      previewTitle: 'Picture preview',
      previewLoading: 'Loading preview...',
      previewMissing: 'No picture uploaded yet.',
      previewFailed: 'Failed to load preview.',
      details: 'Details',
      detailsTitle: 'Item details',
      inventoryTag: 'Inventory tag',
      createdAt: 'Created at',
      updatedAt: 'Updated at',
      removePicture: 'Remove picture',
      duplicate: 'Duplicate',
      edit: 'Edit',
      delete: 'Delete',
      addMore: 'Add more',
      logout: 'Logout',
      expiresToday: 'expires today',
      overdueSuffix: 'overdue',
      daysLeftSuffix: 'left',
      daySingular: 'day',
      dayPlural: 'days',
      unit_grams: 'grams',
      unit_ml: 'ml',
      unit_l: 'l',
      packaging_bottle: 'bottle',
      packaging_can: 'can',
      packaging_box: 'box',
      packaging_bag: 'bag',
      packaging_jar: 'jar',
      packaging_package: 'package',
      packaging_other: 'other'
    },
    de: {
      addItem: 'Artikel hinzufügen',
      sortBy: 'Sortierung',
      search: 'Suche',
      searchPlaceholder: 'Artikel suchen',
      filter: 'Filter',
      filterAll: 'Alle Artikel',
      filterHasImage: 'Mit Bild',
      filterNoImage: 'Ohne Bild',
      overviewTitle: 'Pantry-Übersicht',
      overviewSubtitle: 'Frische, Nachschub und fällige Artikel im Blick behalten.',
      totalItems: 'Artikel',
      totalItemsDesc: 'Gesamt',
      expiringSoon: 'Bald fällig',
      expiringSoonDesc: 'In {days} Tagen',
      overdue: 'Abgelaufen',
      overdueDesc: 'MHD überschritten',
      clearSearch: 'Leeren',
      view: 'Ansicht',
      viewList: 'Liste',
      viewGrid: 'Kacheln',
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
      pictureKey: 'Bild',
      commentOptional: 'Kommentar (optional)',
      cancel: 'Abbrechen',
      creating: 'Erstelle...',
      saving: 'Speichere...',
      saveChanges: 'Änderungen speichern',
      loadingItems: 'Lade Artikel...',
      failedDelete: 'Artikel konnte nicht gelöscht werden.',
      failedDuplicate: 'Artikel konnte nicht dupliziert werden.',
      duplicateConfirm: 'Diesen Artikel duplizieren?',
      duplicateConfirmName: 'Artikel "{name}" duplizieren?',
      failedCreate: 'Artikel konnte nicht erstellt werden.',
      failedUpdate: 'Artikel konnte nicht aktualisiert werden.',
      failedLoad: 'Artikel konnten nicht geladen werden.',
      noItemsYet: 'Noch keine Artikel',
      createFirstItem: 'Erstelle den ersten Artikel über die API und aktualisiere dann.',
      deleteConfirm: 'Diesen Artikel löschen? Er wird aus der Liste ausgeblendet.',
      preview: 'Vorschau',
      previewTitle: 'Bildvorschau',
      previewLoading: 'Vorschau wird geladen...',
      previewMissing: 'Noch kein Bild hochgeladen.',
      previewFailed: 'Vorschau konnte nicht geladen werden.',
      details: 'Details',
      detailsTitle: 'Artikeldetails',
      inventoryTag: 'Inventar-Tag',
      createdAt: 'Erstellt am',
      updatedAt: 'Aktualisiert am',
      removePicture: 'Bild entfernen',
      duplicate: 'Duplizieren',
      edit: 'Bearbeiten',
      delete: 'Löschen',
      addMore: 'Mehr hinzufügen',
      logout: 'Abmelden',
      expiresToday: 'läuft heute ab',
      overdueSuffix: 'abgelaufen',
      daysLeftSuffix: 'verbleibend',
      daySingular: 'Tag',
      dayPlural: 'Tage',
      unit_grams: 'g',
      unit_ml: 'ml',
      unit_l: 'l',
      packaging_bottle: 'Flasche',
      packaging_can: 'Dose',
      packaging_box: 'Packung',
      packaging_bag: 'Tüte',
      packaging_jar: 'Glas',
      packaging_package: 'Packung',
      packaging_other: 'Sonstiges'
    }
  };

  constructor() {
    this.locale = this.readLocaleFromCookie();
    this.viewMode = this.readViewModeFromCookie();
    this.applyLocaleToDocument();
    this.loadItems();
  }

  onSortByChange(sortBy: string): void {
    this.sortBy = sortBy as ItemSortBy;
    this.loadItems();
  }

  onSearchChange(term: string): void {
    this.searchTerm = term;
    this.loadItems();
  }

  onFilterChange(filter: string): void {
    this.activeFilter = filter as FilterValue;
    this.loadItems();
  }

  setViewMode(mode: ViewMode): void {
    this.viewMode = mode;
    this.writeViewModeCookie(mode);
  }

  clearSearch(): void {
    if (!this.searchTerm) {
      return;
    }
    this.searchTerm = '';
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

  duplicateItem(item: Item): void {
    if (!item?.id || this.duplicatingIds.has(item.id)) {
      return;
    }

    const label = item.name?.trim() ? this.t('duplicateConfirmName').replace('{name}', item.name.trim()) : this.t('duplicateConfirm');
    const confirmed = window.confirm(label);
    if (!confirmed) {
      return;
    }

    this.duplicatingIds.add(item.id);
    const clone$: Observable<string | null> = item.pictureKey ? this.api.clonePicture(item.pictureKey) : of(null);

    clone$
      .pipe(
        switchMap((pictureKey) => {
          const payload: CreateItemInput = {
            name: item.name,
            bestBefore: item.bestBefore,
            contentAmount: item.contentAmount,
            contentUnit: item.contentUnit,
            packaging: item.packaging,
            pictureKey,
            comment: item.comment ?? ''
          };
          return this.api.create(payload);
        })
      )
      .subscribe({
        next: () => {
          this.duplicatingIds.delete(item.id);
          this.loadItems();
        },
        error: () => {
          this.duplicatingIds.delete(item.id);
          this.error = this.t('failedDuplicate');
        }
      });
  }

  openPreviewModal(item: Item): void {
    if (this.showDetailsModal) {
      this.showDetailsModal = false;
      this.detailsItem = null;
    }
    this.previewError = '';
    this.previewItemName = item.name;
    this.previewUrl = null;
    this.previewLoading = true;
    this.showPreviewModal = true;
    this.updateModalScrollLock();

    if (!item.pictureKey) {
      this.previewLoading = false;
      this.previewError = this.t('previewMissing');
      return;
    }

    this.api.getPicturePreviewUrl(item.pictureKey).subscribe({
      next: (url) => {
        this.previewLoading = false;
        this.previewUrl = url;
      },
      error: () => {
        this.previewLoading = false;
        this.previewError = this.t('previewFailed');
      }
    });
  }

  openDetailsModal(item: Item): void {
    this.detailsItem = item;
    this.showDetailsModal = true;
    this.updateModalScrollLock();
  }

  @HostListener('document:keydown.escape', ['$event'])
  onEscapeKey(event: KeyboardEvent): void {
    if (!this.showCreateModal && !this.showEditModal && !this.showPreviewModal && !this.showDetailsModal) {
      return;
    }

    event.preventDefault();

    if (this.showPreviewModal) {
      this.closePreviewModal();
      return;
    }

    if (this.showDetailsModal) {
      this.closeDetailsModal();
      return;
    }

    if (this.showEditModal) {
      this.closeEditModal();
      return;
    }

    if (this.showCreateModal) {
      this.closeCreateModal();
    }
  }

  closePreviewModal(): void {
    if (this.previewLoading) {
      return;
    }
    this.showPreviewModal = false;
    this.updateModalScrollLock();
    this.previewUrl = null;
    this.previewItemName = '';
    this.previewError = '';
  }

  closeDetailsModal(): void {
    this.showDetailsModal = false;
    this.detailsItem = null;
    this.updateModalScrollLock();
  }

  createItem(): void {
    if (this.createLoading) {
      return;
    }

    this.createLoading = true;
    this.createError = '';

    this.uploadPictureIfNeeded(this.newItemPictureFile)
      .pipe(
        switchMap((pictureKey) => {
          const payload: CreateItemInput = {
            ...this.newItem,
            pictureKey: pictureKey ?? this.newItem.pictureKey
          };
          return this.api.create(payload);
        }),
        finalize(() => {
          this.createLoading = false;
        })
      )
      .subscribe({
        next: () => {
          if (!this.addMoreOnCreate) {
            this.showCreateModal = false;
            this.updateModalScrollLock();
            this.newItemPictureFile = null;
            this.clearNewPreview();
            this.newItem = {
              name: '',
              bestBefore: '',
              contentAmount: 1,
              contentUnit: this.newItem.contentUnit,
              packaging: this.newItem.packaging,
              pictureKey: null,
              comment: ''
            };
            this.addMoreOnCreate = false;
          }
          this.loadItems();
        },
        error: () => {
          this.createError = this.t('failedCreate');
        }
      });
  }

  openEditModal(item: Item): void {
    this.editError = '';
    this.editingItemId = item.id;
    this.editItemPictureFile = null;
    this.clearEditPreview();
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
    this.updateModalScrollLock();
    this.loadEditPreview();
  }

  closeEditModal(): void {
    if (this.editLoading) {
      return;
    }
    this.editItemPictureFile = null;
    this.clearEditPreview();
    this.showEditModal = false;
    this.updateModalScrollLock();
  }

  updateItem(): void {
    if (this.editLoading || !this.editingItemId) {
      return;
    }

    this.editLoading = true;
    this.editError = '';
    this.uploadPictureIfNeeded(this.editItemPictureFile)
      .pipe(
        switchMap((pictureKey) => {
          const payload: CreateItemInput = {
            ...this.editItem,
            pictureKey: pictureKey ?? this.editItem.pictureKey
          };
          return this.api.update(this.editingItemId, payload);
        }),
        finalize(() => {
          this.editLoading = false;
        })
      )
      .subscribe({
        next: () => {
          this.showEditModal = false;
          this.updateModalScrollLock();
          this.editItemPictureFile = null;
          this.clearEditPreview();
          this.loadItems();
        },
        error: () => {
          this.editError = this.t('failedUpdate');
        }
      });
  }

  openCreateModal(): void {
    this.createError = '';
    this.showCreateModal = true;
    this.updateModalScrollLock();
  }

  closeCreateModal(): void {
    if (this.createLoading) {
      return;
    }
    this.newItemPictureFile = null;
    this.clearNewPreview();
    this.showCreateModal = false;
    this.updateModalScrollLock();
    this.addMoreOnCreate = false;
  }

  onNewPictureSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.newItemPictureFile = input.files?.[0] ?? null;
    this.setNewPreview(this.newItemPictureFile);
  }

  onEditPictureSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.editItemPictureFile = input.files?.[0] ?? null;
    this.setEditPreview(this.editItemPictureFile);
  }

  clearEditPicture(input?: HTMLInputElement): void {
    this.editItem.pictureKey = null;
    this.editItemPictureFile = null;
    this.clearEditPreview();
    if (input) {
      input.value = '';
    }
  }

  private loadItems(): void {
    this.loading = true;
    this.error = '';

    this.api
      .list(this.sortBy, this.sortOrder, this.searchTerm, this.buildFilters())
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

  private uploadPictureIfNeeded(file: File | null): Observable<string | null> {
    if (!file) {
      return of(null);
    }
    return this.api.uploadPicture(file);
  }

  private setNewPreview(file: File | null): void {
    this.clearNewPreview();
    if (!file) {
      return;
    }
    this.newItemPreviewUrl = URL.createObjectURL(file);
  }

  private setEditPreview(file: File | null): void {
    this.clearEditPreview();
    if (!file) {
      return;
    }
    this.editItemPreviewUrl = URL.createObjectURL(file);
  }

  private clearNewPreview(): void {
    if (this.newItemPreviewUrl) {
      URL.revokeObjectURL(this.newItemPreviewUrl);
    }
    this.newItemPreviewUrl = null;
  }

  private clearEditPreview(): void {
    if (this.editItemPreviewUrl) {
      URL.revokeObjectURL(this.editItemPreviewUrl);
    }
    this.editItemPreviewUrl = null;
  }

  private loadEditPreview(): void {
    if (!this.editItem.pictureKey) {
      return;
    }
    this.api
      .getPicturePreviewUrl(this.editItem.pictureKey)
      .pipe(
        tap((url) => {
          this.clearEditPreview();
          this.editItemPreviewUrl = url;
        })
      )
      .subscribe({
        error: () => {
          this.clearEditPreview();
        }
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
    if (delta <= 0) {
      return 'badge-error';
    }
    if (delta >= 30) {
      return 'badge-success';
    }
    if (delta >= 14) {
      return 'badge-warning';
    }
    return 'badge-orange';
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

  expiringSoonDesc(): string {
    return this.t('expiringSoonDesc').replace('{days}', String(this.expiringSoonDays));
  }

  get totalCount(): number {
    return this.items.length;
  }

  get overdueCount(): number {
    return this.items.filter((item) => this.bestBeforeDeltaDays(item.bestBefore) < 0).length;
  }

  get expiringSoonCount(): number {
    return this.items.filter((item) => {
      const delta = this.bestBeforeDeltaDays(item.bestBefore);
      return delta >= 0 && delta <= this.expiringSoonDays;
    }).length;
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

  packagingLabel(packaging: 'bottle' | 'can' | 'box' | 'bag' | 'jar' | 'package' | 'other'): string {
    return this.t(`packaging_${packaging}`);
  }

  jwtUsername(user: User | null): string {
    const token = user?.access_token;
    if (!token) {
      return '';
    }
    const parts = token.split('.');
    if (parts.length < 2) {
      return '';
    }
    try {
      const payload = JSON.parse(this.decodeBase64Url(parts[1])) as Record<string, unknown>;
      const name = payload['name'];
      const givenName = payload['given_name'];
      const familyName = payload['family_name'];
      const fullName =
        typeof name === 'string'
          ? name
          : typeof givenName === 'string' || typeof familyName === 'string'
            ? [givenName, familyName].filter((value) => typeof value === 'string' && value.length > 0).join(' ')
            : payload['preferred_username'] ?? payload['username'] ?? payload['sub'];
      return typeof fullName === 'string' ? fullName : '';
    } catch {
      return '';
    }
  }

  logout(): void {
    this.auth.logout();
  }

  private decodeBase64Url(input: string): string {
    const padded = input.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(input.length / 4) * 4, '=');
    return decodeURIComponent(
      Array.from(atob(padded))
        .map((char) => `%${char.charCodeAt(0).toString(16).padStart(2, '0')}`)
        .join('')
    );
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

  private buildFilters(): { hasImage?: boolean } {
    if (this.activeFilter === 'has_image:true') {
      return { hasImage: true };
    }
    if (this.activeFilter === 'has_image:false') {
      return { hasImage: false };
    }
    return {};
  }


  private updateModalScrollLock(): void {
    const anyOpen = this.showCreateModal || this.showEditModal || this.showPreviewModal || this.showDetailsModal;
    const body = this.document.body;
    const html = this.document.documentElement;

    if (anyOpen) {
      body.classList.add('modal-open', 'overflow-hidden');
      html.classList.add('overflow-hidden');
      return;
    }

    body.classList.remove('modal-open', 'overflow-hidden');
    html.classList.remove('overflow-hidden');
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

  private readViewModeFromCookie(): ViewMode {
    const cookie = this.document.cookie
      .split(';')
      .map((part) => part.trim())
      .find((part) => part.startsWith('pantry_view='));

    const fromCookie = cookie?.split('=')[1] ?? '';
    if (fromCookie === 'list' || fromCookie === 'grid') {
      return fromCookie;
    }
    return 'list';
  }

  private writeLocaleCookie(locale: Locale): void {
    const maxAge = 60 * 60 * 24 * 365;
    this.document.cookie = `pantry_locale=${locale}; path=/; max-age=${maxAge}; samesite=lax`;
  }

  private writeViewModeCookie(mode: ViewMode): void {
    const maxAge = 60 * 60 * 24 * 365;
    this.document.cookie = `pantry_view=${mode}; path=/; max-age=${maxAge}; samesite=lax`;
  }

  private applyLocaleToDocument(): void {
    this.document.documentElement.lang = this.locale;
  }
}

type Locale = 'en' | 'de';
type FilterValue = 'all' | 'has_image:true' | 'has_image:false';
type ViewMode = 'list' | 'grid';
