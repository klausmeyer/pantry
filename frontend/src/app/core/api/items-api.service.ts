import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { map, Observable } from 'rxjs';
import {
  CreateItemInput,
  Item,
  ItemSortBy,
  JsonApiItemResource,
  JsonApiListResponse,
  SortOrder
} from '../models/item';

@Injectable({ providedIn: 'root' })
export class ItemsApiService {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = 'http://localhost:4000';

  list(sortBy: ItemSortBy, sortOrder: SortOrder): Observable<Item[]> {
    const sort = sortOrder === 'desc' ? `-${sortBy}` : sortBy;

    return this.http
      .get<JsonApiListResponse>(`${this.baseUrl}/api/items`, {
        headers: { Accept: 'application/vnd.api+json' },
        params: {
          sort
        }
      })
      .pipe(map((response) => response.data.map((resource) => this.toItem(resource))));
  }

  create(input: CreateItemInput): Observable<Item> {
    const payload = this.toCreateOrUpdatePayload(input);

    return this.http
      .post<{ data: JsonApiItemResource }>(`${this.baseUrl}/api/items`, payload, {
        headers: {
          Accept: 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json'
        }
      })
      .pipe(map((response) => this.toItem(response.data)));
  }

  update(id: string, input: CreateItemInput): Observable<Item> {
    const payload = {
      data: {
        type: 'items',
        id,
        attributes: {
          name: input.name,
          best_before: input.bestBefore,
          content_amount: input.contentAmount,
          content_unit: input.contentUnit,
          packaging: input.packaging,
          picture_key: input.pictureKey,
          comment: input.comment?.trim() ? input.comment : null
        }
      }
    };

    return this.http
      .patch<{ data: JsonApiItemResource }>(`${this.baseUrl}/api/items/${encodeURIComponent(id)}`, payload, {
        headers: {
          Accept: 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json'
        }
      })
      .pipe(map((response) => this.toItem(response.data)));
  }

  softDelete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/api/items/${encodeURIComponent(id)}`, {
      headers: { Accept: 'application/vnd.api+json' }
    });
  }

  private toCreateOrUpdatePayload(input: CreateItemInput): {
    data: {
      type: 'items';
      attributes: {
        name: string;
        best_before: string;
        content_amount: number;
        content_unit: CreateItemInput['contentUnit'];
        packaging: CreateItemInput['packaging'];
        picture_key: string;
        comment: string | null;
      };
    };
  } {
    return {
      data: {
        type: 'items',
        attributes: {
          name: input.name,
          best_before: input.bestBefore,
          content_amount: input.contentAmount,
          content_unit: input.contentUnit,
          packaging: input.packaging,
          picture_key: input.pictureKey,
          comment: input.comment?.trim() ? input.comment : null
        }
      }
    };
  }

  private toItem(resource: JsonApiItemResource): Item {
    return {
      id: resource.id,
      name: resource.attributes.name,
      bestBefore: resource.attributes.best_before,
      contentAmount: resource.attributes.content_amount,
      contentUnit: resource.attributes.content_unit,
      packaging: resource.attributes.packaging,
      pictureKey: resource.attributes.picture_key,
      comment: resource.attributes.comment,
      createdAt: resource.attributes.created_at,
      updatedAt: resource.attributes.updated_at
    };
  }
}
