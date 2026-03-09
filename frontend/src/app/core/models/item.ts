export type ContentUnit = 'grams' | 'ml' | 'l';

export interface Item {
  id: string;
  name: string;
  bestBefore: string;
  contentAmount: number;
  contentUnit: ContentUnit;
  pictureKey: string;
  comment?: string;
  createdAt: string;
  updatedAt: string;
}

export interface JsonApiItemAttributes {
  name: string;
  best_before: string;
  content_amount: number;
  content_unit: ContentUnit;
  picture_key: string;
  comment?: string;
  created_at: string;
  updated_at: string;
}

export interface JsonApiItemResource {
  type: 'items';
  id: string;
  attributes: JsonApiItemAttributes;
}

export interface JsonApiListResponse {
  data: JsonApiItemResource[];
}

export type ItemSortBy = 'id' | 'name' | 'best_before' | 'created_at' | 'updated_at';
export type SortOrder = 'asc' | 'desc';
