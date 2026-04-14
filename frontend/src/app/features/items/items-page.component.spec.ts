
import { TestBed } from '@angular/core/testing';
import { of } from 'rxjs';
import { ItemsApiService } from '../../core/api/items-api.service';
import { AuthService } from '../../core/auth/auth.service';
import type { Item } from '../../core/models/item';
import type { User } from 'oidc-client-ts';
import type { Observable } from 'rxjs';
import { ItemsPageComponent } from './items-page.component';

describe('ItemsPageComponent', () => {
  let api: jasmine.SpyObj<ItemsApiService>;
  let auth: { user$: Observable<User | null>; logout: jasmine.Spy };

  const makeItem = (overrides: Partial<Item> = {}): Item => ({
    id: '1',
    name: 'Milk',
    bestBefore: '2026-01-20',
    contentAmount: 1,
    contentUnit: 'l',
    packaging: 'bottle',
    pictureKey: 'items/milk.png',
    comment: undefined,
    inventoryTag: 'ABCD',
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
    ...overrides
  });

  beforeEach(() => {
    api = jasmine.createSpyObj<ItemsApiService>('ItemsApiService', [
      'list',
      'softDelete',
      'clonePicture',
      'create',
      'getPicturePreviewUrl'
    ]);
    api.list.and.returnValue(of([]));
    api.softDelete.and.returnValue(of(void 0));
    api.clonePicture.and.returnValue(of('items/clone.png'));
    api.create.and.returnValue(of(makeItem({ id: '2' })));
    api.getPicturePreviewUrl.and.returnValue(of('https://cdn.example/preview.png'));

    auth = {
      user$: of(null),
      logout: jasmine.createSpy('logout')
    };

    TestBed.configureTestingModule({
      imports: [ItemsPageComponent],
      providers: [
        { provide: ItemsApiService, useValue: api },
        { provide: AuthService, useValue: auth },
        { provide: Document, useValue: document }
      ]
    });
  });

  it('loads items on init with default params', () => {
    const fixture = TestBed.createComponent(ItemsPageComponent);
    fixture.detectChanges();

    expect(api.list).toHaveBeenCalledWith('best_before', 'asc', '', {});
    const component = fixture.componentInstance;
    expect(component.items).toEqual([]);
    expect(component.loading).toBeFalse();
  });

  it('clears search and reloads', () => {
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    component.searchTerm = 'milk';
    api.list.calls.reset();

    component.clearSearch();

    expect(component.searchTerm).toBe('');
    expect(api.list).toHaveBeenCalledWith(component.sortBy, component.sortOrder, '', {});
  });

  it('deletes item when confirmed', () => {
    spyOn(window, 'confirm').and.returnValue(true);
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    component.items = [makeItem({ id: '1' }), makeItem({ id: '2' })];

    component.deleteItem('1');

    expect(api.softDelete).toHaveBeenCalledWith('1');
    expect(component.items.map((item) => item.id)).toEqual(['2']);
  });

  it('skips delete when confirmation is rejected', () => {
    spyOn(window, 'confirm').and.returnValue(false);
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    component.items = [makeItem({ id: '1' })];

    component.deleteItem('1');

    expect(api.softDelete).not.toHaveBeenCalled();
    expect(component.items.length).toBe(1);
  });

  it('duplicates item and reloads list', () => {
    spyOn(window, 'confirm').and.returnValue(true);
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    const reloadSpy = spyOn(component as any, 'loadItems').and.callThrough();
    const item = makeItem({ id: '10', pictureKey: 'items/original.png' });

    component.duplicateItem(item);

    expect(api.clonePicture).toHaveBeenCalledWith('items/original.png');
    expect(api.create).toHaveBeenCalled();
    expect(reloadSpy).toHaveBeenCalled();
  });

  it('opens preview modal and shows missing message when no picture', () => {
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    const item = makeItem({ pictureKey: null });

    component.openPreviewModal(item);

    expect(component.showPreviewModal).toBeTrue();
    expect(component.previewLoading).toBeFalse();
    expect(component.previewError).toBe(component.t('previewMissing'));
  });

  it('loads preview url when picture exists', () => {
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    const item = makeItem({ pictureKey: 'items/pic.png' });

    component.openPreviewModal(item);

    expect(api.getPicturePreviewUrl).toHaveBeenCalledWith('items/pic.png');
    expect(component.previewLoading).toBeFalse();
    expect(component.previewUrl).toBe('https://cdn.example/preview.png');
  });

  it('returns correct badge class and label for overdue item', () => {
    jasmine.clock().install();
    jasmine.clock().mockDate(new Date('2026-01-10T12:00:00Z'));

    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    component.locale = 'en';

    expect(component.bestBeforeBadgeClass('2026-01-09')).toBe('badge-error');
    expect(component.bestBeforeLabel('2026-01-09')).toContain('overdue');

    jasmine.clock().uninstall();
  });

  it('parses username from JWT payload', () => {
    const fixture = TestBed.createComponent(ItemsPageComponent);
    const component = fixture.componentInstance;
    const payload = { given_name: 'Avery', family_name: 'Ng' };
    const token = ['header', toBase64Url(JSON.stringify(payload)), 'sig'].join('.');

    const name = component.jwtUsername({ access_token: token } as any);

    expect(name).toBe('Avery Ng');
  });
});

const toBase64Url = (input: string): string =>
  btoa(input).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
