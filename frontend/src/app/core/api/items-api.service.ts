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

  list(
    sortBy: ItemSortBy,
    sortOrder: SortOrder,
    search?: string,
    filters?: { hasImage?: boolean }
  ): Observable<Item[]> {
    const sort = sortOrder === 'desc' ? `-${sortBy}` : sortBy;
    const trimmedSearch = search?.trim() ?? '';
    const params: Record<string, string> = { sort };
    if (trimmedSearch) {
      params['q'] = trimmedSearch;
    }
    if (filters?.hasImage !== undefined) {
      params['filter[has_image]'] = filters.hasImage ? 'true' : 'false';
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
    return from(this.prepareUploadFile(file)).pipe(
      switchMap((preparedFile) => {
        const contentType = this.resolveContentType(preparedFile);
        return this.http
          .post<UploadResponse>(
            `${this.baseUrl}/uploads`,
            { filename: preparedFile.name, content_type: contentType },
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
                  body: preparedFile
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
      })
    );
  }

  clonePicture(pictureKey: string): Observable<string> {
    return this.http
      .post<UploadCloneResponse>(
        `${this.baseUrl}/uploads/clone`,
        { picture_key: pictureKey },
        {
          headers: {
            Accept: 'application/vnd.api+json',
            'Content-Type': 'application/json'
          }
        }
      )
      .pipe(map((response) => response.data.attributes.picture_key));
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

  private async prepareUploadFile(file: File): Promise<File> {
    const contentType = this.resolveContentType(file);
    if (!this.shouldResize(contentType)) {
      return file;
    }

    const image = await this.loadImage(file);
    const { width, height } = image;
    const maxDimension = 1600;
    const scale = Math.min(1, maxDimension / Math.max(width, height));

    if (scale >= 1) {
      return file;
    }

    const targetWidth = Math.max(1, Math.round(width * scale));
    const targetHeight = Math.max(1, Math.round(height * scale));
    const canvas = document.createElement('canvas');
    canvas.width = targetWidth;
    canvas.height = targetHeight;

    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return file;
    }

    ctx.drawImage(image, 0, 0, targetWidth, targetHeight);

    const blob = await new Promise<Blob | null>((resolve) => {
      if (contentType === 'image/png') {
        canvas.toBlob(resolve, contentType);
        return;
      }
      const quality = 0.85;
      canvas.toBlob(resolve, contentType, quality);
    });

    if (!blob) {
      return file;
    }

    return new File([blob], file.name, {
      type: contentType,
      lastModified: file.lastModified
    });
  }

  private shouldResize(contentType: string): boolean {
    return contentType === 'image/jpeg' || contentType === 'image/jpg' || contentType === 'image/png' || contentType === 'image/webp';
  }

  private loadImage(file: File): Promise<HTMLImageElement> {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        URL.revokeObjectURL(url);
        resolve(img);
      };
      img.onerror = () => {
        URL.revokeObjectURL(url);
        reject(new Error('Image load failed'));
      };
      img.src = url;
    });
  }
}

interface UploadCloneResponse {
  data: {
    type: 'uploads';
    attributes: {
      picture_key: string;
    };
  };
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
