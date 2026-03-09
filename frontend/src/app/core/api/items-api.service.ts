import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { map, Observable } from 'rxjs';
import {
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
