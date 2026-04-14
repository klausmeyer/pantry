import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { ItemsApiService } from './items-api.service';
import type { JsonApiListResponse } from '../models/item';

describe('ItemsApiService', () => {
  let service: ItemsApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule]
    });

    service = TestBed.inject(ItemsApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('lists items with sorting, filtering, and search', () => {
    let result: unknown;

    service.list('best_before', 'desc', '  milk ', { hasImage: true }).subscribe((items) => {
      result = items;
    });

    const req = httpMock.expectOne((request) => request.url === '/api/items');
    expect(req.request.method).toBe('GET');
    expect(req.request.headers.get('Accept')).toBe('application/vnd.api+json');
    expect(req.request.params.get('sort')).toBe('-best_before');
    expect(req.request.params.get('q')).toBe('milk');
    expect(req.request.params.get('filter[has_image]')).toBe('true');

    const payload: JsonApiListResponse = {
      data: [
        {
          type: 'items',
          id: '1',
          attributes: {
            name: 'Milk',
            best_before: '2026-01-01',
            content_amount: 1,
            content_unit: 'l',
            packaging: 'bottle',
            picture_key: 'items/milk.png',
            inventory_tag: 'ABCD',
            created_at: '2026-01-01T00:00:00Z',
            updated_at: '2026-01-01T00:00:00Z'
          }
        }
      ]
    };

    req.flush(payload);

    expect(result).toEqual([
      {
        id: '1',
        inventoryTag: 'ABCD',
        name: 'Milk',
        bestBefore: '2026-01-01',
        contentAmount: 1,
        contentUnit: 'l',
        packaging: 'bottle',
        pictureKey: 'items/milk.png',
        comment: undefined,
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z'
      }
    ]);
  });

  it('lists items with default sort only when no filters', () => {
    service.list('name', 'asc').subscribe();

    const req = httpMock.expectOne((request) => request.url === '/api/items');
    expect(req.request.params.get('sort')).toBe('name');
    expect(req.request.params.has('q')).toBeFalse();
    expect(req.request.params.has('filter[has_image]')).toBeFalse();

    req.flush({ data: [] } as JsonApiListResponse);
  });
});
