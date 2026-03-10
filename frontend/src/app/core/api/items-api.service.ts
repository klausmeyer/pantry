import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { from, map, Observable, of, switchMap, throwError } from 'rxjs';
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
  private readonly baseUrl = this.resolveBaseUrl();

  list(sortBy: ItemSortBy, sortOrder: SortOrder, search?: string): Observable<Item[]> {
    const sort = sortOrder === 'desc' ? `-${sortBy}` : sortBy;
    const trimmedSearch = search?.trim() ?? '';
    const params: Record<string, string> = { sort };
    if (trimmedSearch) {
      params['q'] = trimmedSearch;
    }

    return this.http
      .get<JsonApiListResponse>(`${this.baseUrl}/items`, {
        headers: { Accept: 'application/vnd.api+json' },
        params
      })
      .pipe(map((response) => response.data.map((resource) => this.toItem(resource))));
  }

  create(input: CreateItemInput): Observable<Item> {
    const payload = this.toCreateOrUpdatePayload(input);

    return this.http
      .post<{ data: JsonApiItemResource }>(`${this.baseUrl}/items`, payload, {
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
          picture_key: input.pictureKey ?? null,
          comment: input.comment?.trim() ? input.comment : null
        }
      }
    };

    return this.http
      .patch<{ data: JsonApiItemResource }>(`${this.baseUrl}/items/${encodeURIComponent(id)}`, payload, {
        headers: {
          Accept: 'application/vnd.api+json',
          'Content-Type': 'application/vnd.api+json'
        }
      })
      .pipe(map((response) => this.toItem(response.data)));
  }

  softDelete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/items/${encodeURIComponent(id)}`, {
      headers: { Accept: 'application/vnd.api+json' }
    });
  }

  uploadPicture(file: File): Observable<string> {
    const contentType = this.resolveContentType(file);

    return this.http
      .post<UploadResponse>(
        `${this.baseUrl}/uploads`,
        { filename: file.name, content_type: contentType },
        {
          headers: {
            Accept: 'application/vnd.api+json',
            'Content-Type': 'application/json'
          }
        }
      )
      .pipe(
        switchMap((response) => {
          const { upload_url, picture_key, headers } = response.data.attributes;
          return from(
            fetch(upload_url, {
              method: 'PUT',
              headers,
              body: file
            })
          ).pipe(
            switchMap((uploadResponse) => {
              if (!uploadResponse.ok) {
                return throwError(() => new Error('Upload failed'));
              }
              return of(picture_key);
            })
          );
        })
      );
  }

  getPicturePreviewUrl(pictureKey: string): Observable<string> {
    return this.http
      .get<UploadPreviewResponse>(`${this.baseUrl}/uploads/preview`, {
        headers: { Accept: 'application/vnd.api+json' },
        params: { picture_key: pictureKey }
      })
      .pipe(map((response) => response.data.attributes.preview_url));
  }

  private resolveBaseUrl(): string {
    if (typeof window !== 'undefined' && window.location.port === '4200') {
      return 'http://localhost:4000/api';
    }
    return '/api';
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
        picture_key: string | null;
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
          picture_key: input.pictureKey ?? null,
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

  private resolveContentType(file: File): string {
    if (file.type) {
      return file.type;
    }

    const lower = file.name.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    return 'application/octet-stream';
  }
}

type UploadResponse = {
  data: {
    type: 'uploads';
    attributes: {
      picture_key: string;
      upload_url: string;
      headers: Record<string, string>;
    };
  };
};

type UploadPreviewResponse = {
  data: {
    type: 'uploads';
    attributes: {
      picture_key: string;
      preview_url: string;
    };
  };
};
